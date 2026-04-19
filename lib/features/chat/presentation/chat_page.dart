import 'package:flutter/material.dart';

import '../../../core/widgets/gb_blue_header.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();

  static const List<_SampleMessage> _sampleMessages = <_SampleMessage>[
    _SampleMessage(
      fromUser: false,
      content:
          'This AI preview is a sample interface while full AI services are being integrated.',
      time: '9:41 AM',
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GbBlueHeader(
          title: 'AI Assistant',
          subtitle: 'Preview Experience',
          showBack: false,
          description:
              'Premium sample UI for the upcoming AI legal guidance assistant.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 106),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF7FAFF), Color(0xFFEAF1FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD8E5FF)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Color(0xFF2F6EFF), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'AI Guidance Center',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2C45)),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Soon you can ask legal questions, get document checklists, and receive guided next steps based on your case details.',
                      style: TextStyle(height: 1.4, color: Color(0xFF4E6489)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._sampleMessages.map((message) => _MessageBubble(message: message)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Row(
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
                      readOnly: true,
                      decoration: const InputDecoration(
                        hintText: 'AI service preview mode',
                        hintStyle: TextStyle(color: Color(0xFF8DA2C7)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  child: const Icon(Icons.send_rounded, color: Colors.white),
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

  final _SampleMessage message;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.fromUser ? const Color(0xFF1F49D8) : Colors.white;
    final textColor = message.fromUser ? Colors.white : const Color(0xFF22324F);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: message.fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF2F6EFF), size: 17),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
                border: message.fromUser ? null : Border.all(color: const Color(0xFFE2EAF9)),
                boxShadow: const [BoxShadow(color: Color(0x110E1A33), blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(height: 1.35, color: textColor, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message.time,
                    style: TextStyle(
                      fontSize: 11,
                      color: message.fromUser ? const Color(0xD4FFFFFF) : const Color(0xFF8A9DBC),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleMessage {
  const _SampleMessage({required this.fromUser, required this.content, required this.time});

  final bool fromUser;
  final String content;
  final String time;
}
