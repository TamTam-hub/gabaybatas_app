import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class ChatThread {
  ChatThread({
    required this.threadId,
    required this.caseId,
    required this.caseReference,
    required this.participantName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final int threadId;
  final int caseId;
  final String caseReference;
  final String participantName;
  final String lastMessage;
  final String lastMessageAt;
  final int unreadCount;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      threadId: int.tryParse((json['thread_id'] ?? '').toString()) ?? 0,
      caseId: int.tryParse((json['case_id'] ?? '').toString()) ?? 0,
      caseReference: (json['case_reference'] ?? '').toString(),
      participantName: (json['participant_name'] ?? '').toString(),
      lastMessage: (json['last_message'] ?? '').toString(),
      lastMessageAt: (json['last_message_at'] ?? '').toString(),
      unreadCount: int.tryParse((json['unread_count'] ?? 0).toString()) ?? 0,
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  final int messageId;
  final int senderId;
  final String senderName;
  final String senderRole;
  final String content;
  final String createdAt;

  bool get fromResident => senderRole.toLowerCase() == 'resident';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: int.tryParse((json['message_id'] ?? '').toString()) ?? 0,
      senderId: int.tryParse((json['sender_id'] ?? '').toString()) ?? 0,
      senderName: (json['sender_name'] ?? '').toString(),
      senderRole: (json['sender_role'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class AiMessage {
  const AiMessage({required this.fromUser, required this.content});

  final bool fromUser;
  final String content;

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      fromUser: (json['role'] ?? '').toString().toLowerCase() == 'user',
      content: (json['content'] ?? '').toString(),
    );
  }
}

class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String updatedAt;

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    return AiConversation(
      id: int.tryParse((json['conversation_id'] ?? '').toString()) ?? 0,
      title: (json['title'] ?? 'New chat').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

class ChatService {
  ChatService({ApiClient? apiClient})
    : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String threadsPath = '/api/v1/chat_threads.php';
  static const String messagesPath = '/api/v1/chat_thread_messages.php';
  static const String sendPath = '/api/v1/chat_thread_send.php';
  static const String aiPath = '/api/v1/ai_chat.php';
  static const String aiHistoryPath = '/api/v1/ai_history.php';
  static const String aiSavePath = '/api/v1/ai_message_save.php';
  static const String aiConversationsPath = '/api/v1/ai_conversations.php';
  static const String aiConversationMessagesPath =
      '/api/v1/ai_conversation_messages.php';

  Future<List<AiConversation>> listAiConversations() async {
    final response = await _apiClient.get(
      aiConversationsPath,
      authenticated: true,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final list = data['conversations'] is List
        ? data['conversations'] as List
        : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AiConversation.fromJson)
        .toList();
  }

  Future<AiConversation> createAiConversation({
    String title = 'New chat',
  }) async {
    final response = await _apiClient.post(
      aiConversationsPath,
      authenticated: true,
      body: <String, dynamic>{'title': title},
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AiConversation(
      id: int.tryParse((data['conversation_id'] ?? '').toString()) ?? 0,
      title: (data['title'] ?? title).toString(),
      updatedAt: '',
    );
  }

  Future<List<AiMessage>> loadAiConversation(int conversationId) async {
    final response = await _apiClient.get(
      '$aiConversationMessagesPath?conversation_id=$conversationId',
      authenticated: true,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final list = data['messages'] is List
        ? data['messages'] as List
        : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AiMessage.fromJson)
        .toList();
  }

  Future<void> saveAiConversationExchange({
    required int conversationId,
    required String userMessage,
    required String assistantMessage,
  }) async {
    await _apiClient.post(
      aiConversationMessagesPath,
      authenticated: true,
      body: <String, dynamic>{
        'conversation_id': conversationId,
        'user_message': userMessage,
        'assistant_message': assistantMessage,
      },
    );
  }

  Future<void> deleteAiConversation(int conversationId) async {
    await _apiClient.delete(
      '$aiConversationsPath?conversation_id=$conversationId',
      authenticated: true,
    );
  }

  Future<void> renameAiConversation({
    required int conversationId,
    required String title,
  }) async {
    await _apiClient.patch(
      '$aiConversationsPath?conversation_id=$conversationId',
      authenticated: true,
      body: <String, dynamic>{'title': title},
    );
  }

  Future<List<AiMessage>> loadAiHistory() async {
    final response = await _apiClient.get(
      '$aiHistoryPath?limit=50',
      authenticated: true,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final list = data['messages'] is List
        ? data['messages'] as List
        : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AiMessage.fromJson)
        .toList();
  }

  Future<String> askAssistant(String message) async {
    final response = await _apiClient.post(
      aiPath,
      authenticated: true,
      body: <String, dynamic>{'message': message},
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
    final reply = data['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) {
      throw ApiException('The AI assistant returned an empty response.');
    }

    return reply;
  }

  Future<void> saveAiExchange({
    required String userMessage,
    required String assistantMessage,
  }) async {
    await _apiClient.post(
      aiSavePath,
      authenticated: true,
      body: <String, dynamic>{
        'user_message': userMessage,
        'assistant_message': assistantMessage,
      },
    );
  }

  Future<List<ChatThread>> listThreads({int limit = 10, int offset = 0}) async {
    final response = await _apiClient.get(
      '$threadsPath?limit=$limit&offset=$offset',
      authenticated: true,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final list = data['threads'] is List
        ? data['threads'] as List
        : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ChatThread.fromJson)
        .toList();
  }

  Future<List<ChatMessage>> listMessages({
    required int threadId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      '$messagesPath?thread_id=$threadId&limit=$limit&offset=$offset',
      authenticated: true,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final list = data['messages'] is List
        ? data['messages'] as List
        : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  Future<void> sendMessage({
    required int threadId,
    required String content,
  }) async {
    await _apiClient.post(
      '$sendPath?thread_id=$threadId',
      authenticated: true,
      body: <String, dynamic>{'content': content},
    );
  }
}
