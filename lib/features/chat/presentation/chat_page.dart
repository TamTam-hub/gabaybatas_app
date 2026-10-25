// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../core/widgets/gb_blue_header.dart';
import '../../../core/widgets/gb_dialog.dart';
import '../../../core/network/api_exception.dart';
import '../../../services/gemini_service.dart';
import '../data/chat_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static final TextEditingController _messageController = TextEditingController();
  static final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final GeminiService _geminiService = GeminiService();
  static final List<_ChatMessage> _messages = <_ChatMessage>[];
  static bool _isSending = false;
  static bool _isTypingReply = false;
  static bool _isLoadingHistory = true;
  static bool _shouldFollowTyping = true;
  static List<AiConversation> _recentConversations = <AiConversation>[];
  static int? _conversationId;
  static bool _isFirstLoad = true;
  static const int _historyLimit = 12;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _geminiService.preloadLegalInformation();
    if (_isFirstLoad) {
      _loadConversation();
      _isFirstLoad = false;
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    _shouldFollowTyping = distanceFromBottom < 96;
  }

  Future<void> _loadConversation({int? conversationId}) async {
    try {
      final conversations = await _chatService.listAiConversations();
      final selectedId = conversationId;
      final history = selectedId == null
          ? <AiMessage>[]
          : await _chatService.loadAiConversation(selectedId);
      if (!mounted) return;
      setState(() {
        _recentConversations = conversations;
        _conversationId = selectedId;
        _messages
          ..clear()
          ..addAll(
            history.map(
              (message) => _ChatMessage(
                fromUser: message.fromUser,
                content: message.content,
              ),
            ),
          );
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _shouldFollowTyping) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _startNewChat() async {
    if (_isSending) return;
    setState(() {
      _conversationId = null;
      _messages.clear();
    });
    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _openRecents() async {
    final selected = await showModalBottomSheet<AiConversation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecentsSheet(
        conversations: _recentConversations,
        onDelete: (conversation) async {
          await _chatService.deleteAiConversation(conversation.id);
          if (mounted) {
            setState(() {
              _recentConversations.removeWhere(
                (item) => item.id == conversation.id,
              );
            });
          }
        },
        onRename: (conversation, title) async {
          await _chatService.renameAiConversation(
            conversationId: conversation.id,
            title: title,
          );
          if (mounted) {
            setState(() {
              final index = _recentConversations.indexWhere(
                (item) => item.id == conversation.id,
              );
              if (index >= 0) {
                _recentConversations[index] = AiConversation(
                  id: conversation.id,
                  title: title,
                  updatedAt: conversation.updatedAt,
                );
              }
            });
          }
        },
      ),
    );
    final selectedConversation = selected;
    if (selectedConversation != null && mounted) {
      setState(() => _isLoadingHistory = true);
      await _loadConversation(conversationId: selectedConversation.id);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    _messageController.clear();
    final conversationId = _conversationId ??=
        (await _chatService.createAiConversation(
          title: _conversationTitle(message),
        )).id;
    // Earlier turns only (the new message is sent separately), limited to the
    // most recent ones so long chats stay fast.
    final earlier = _messages.where((item) => item.content.trim().isNotEmpty);
    final history = earlier
        .skip(earlier.length > _historyLimit ? earlier.length - _historyLimit : 0)
        .map(
          (item) =>
              GeminiChatMessage(fromUser: item.fromUser, content: item.content),
        )
        .toList();
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, content: message));
      _isSending = true;
    });

    try {
      final reply = await _geminiService.generateReply(
        message: message,
        history: history,
      );
      await _chatService.saveAiConversationExchange(
        conversationId: conversationId,
        userMessage: message,
        assistantMessage: reply,
      );
      if (!mounted) return;
      _recentConversations = await _chatService.listAiConversations();
      await _typeAssistantReply(reply);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI assistant error: $error')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _conversationTitle(String message) {
    final normalized = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 48
        ? normalized
        : '${normalized.substring(0, 48).trimRight()}...';
  }

  Future<void> _typeAssistantReply(String reply) async {
    if (!mounted) return;
    setState(() {
      _isTypingReply = true;
      _messages.add(const _ChatMessage(fromUser: false, content: ''));
    });

    final buffer = StringBuffer();
    final characterCount = reply.runes.length;
    final typingDelay = characterCount > 900
        ? 1
        : characterCount > 500
        ? 3
        : 6;
    final runes = reply.runes.toList();
    const updateBatchSize = 3;
    for (var index = 0; index < runes.length; index += updateBatchSize) {
      if (!mounted) return;
      final end = index + updateBatchSize < runes.length
          ? index + updateBatchSize
          : runes.length;
      for (final rune in runes.sublist(index, end)) {
        buffer.write(String.fromCharCode(rune));
      }
      setState(() {
        _messages[_messages.length - 1] = _ChatMessage(
          fromUser: false,
          content: buffer.toString(),
        );
      });
      await Future<void>.delayed(
        Duration(milliseconds: typingDelay * (end - index)),
      );
    }
    if (mounted) {
      setState(() => _isTypingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: GbBlueHeader(
                  title: 'AI Chatbot',
                  showBack: false,
                  description:
                      'Ask for general legal information and practical next steps. GabayBatas AI is not a lawyer.',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 106),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_isLoadingHistory)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!_isLoadingHistory && _messages.isEmpty)
                      const _MessageBubble(
                        message: _ChatMessage(
                          fromUser: false,
                          content:
                              'Hello! I can provide general legal information and explain possible next steps for residents of Barangay Muñoz. How can I help?',
                        ),
                      ),
                    ..._messages.map(
                      (message) => _MessageBubble(message: message),
                    ),
                    if (_isSending && !_isTypingReply)
                      const _MessageBubble(
                        message: _ChatMessage(
                          fromUser: false,
                          content: 'Thinking...',
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ChatActionButton(
                        icon: Icons.add_rounded,
                        label: 'New chat',
                        onPressed: _isSending ? null : _startNewChat,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChatActionButton(
                        icon: Icons.history_rounded,
                        label: 'Recents',
                        onPressed: _isSending ? null : _openRecents,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDDE6F9)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x120E1A33),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _messageController,
                          enabled: !_isSending,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'Ask a question',
                            hintStyle: TextStyle(color: Color(0xFF8DA2C7)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2F6EFF), Color(0xFF1F49D8)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: IconButton(
                        onPressed: _isSending ? null : _sendMessage,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Send message',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.fromUser
        ? const Color(0xFF1F49D8)
        : Colors.white;
    final textColor = message.fromUser ? Colors.white : const Color(0xFF22324F);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: message.fromUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.fromUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.support_agent_rounded,
                color: Color(0xFF2F6EFF),
                size: 17,
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
                border: message.fromUser
                    ? null
                    : Border.all(color: const Color(0xFFE2EAF9)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x110E1A33),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      height: 1.35,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF3159C9),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        side: const BorderSide(color: Color(0xFFD8E5FF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }
}

class _RecentsSheet extends StatelessWidget {
  const _RecentsSheet({
    required this.conversations,
    required this.onDelete,
    required this.onRename,
  });

  final List<AiConversation> conversations;
  final Future<void> Function(AiConversation conversation) onDelete;
  final Future<void> Function(AiConversation conversation, String title)
  onRename;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 560),
        margin: const EdgeInsets.only(top: 70),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8D5F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7EEFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Color(0xFF3159C9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent chats',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2C45),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Continue a previous conversation',
                          style: TextStyle(color: Color(0xFF7183A5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: conversations.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 44,
                              color: Color(0xFFAFC0E3),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No recent chats yet',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF445779),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Your conversations will appear here.',
                              style: TextStyle(color: Color(0xFF8292B0)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.pop(context, conversation),
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: Color(0xFF5A78D5),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        conversation.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF263858),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Rename conversation',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Color(0xFF5A78D5),
                                      ),
                                      onPressed: () => _renameConversation(
                                        context,
                                        conversation,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete conversation',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFB16B78),
                                      ),
                                      onPressed: () =>
                                          _confirmDelete(context, conversation),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameConversation(
    BuildContext context,
    AiConversation conversation,
  ) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameConversationDialog(initialTitle: conversation.title),
    );
    if (title != null && title.trim().isNotEmpty) {
      await onRename(conversation, title.trim());
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AiConversation conversation,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => GbDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Delete conversation?',
        content: const Text('This conversation will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await onDelete(conversation);
    }
  }
}

class _RenameConversationDialog extends StatefulWidget {
  const _RenameConversationDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<_RenameConversationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) {
      Navigator.of(context).pop(title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GbDialog(
      icon: Icons.edit_outlined,
      title: 'Rename conversation',
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        minLines: 1,
        maxLines: 4,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          labelText: 'Conversation name',
          hintText: 'Enter a name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.fromUser, required this.content});

  final bool fromUser;
  final String content;
}
