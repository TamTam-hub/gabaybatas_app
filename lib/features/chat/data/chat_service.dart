import '../../../core/network/api_client.dart';

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

class ChatService {
  ChatService({ApiClient? apiClient}) : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String threadsPath = '/api/v1/chat_threads.php';
  static const String messagesPath = '/api/v1/chat_thread_messages.php';
  static const String sendPath = '/api/v1/chat_thread_send.php';

  Future<List<ChatThread>> listThreads({int limit = 10, int offset = 0}) async {
    final response = await _apiClient.get(
      '$threadsPath?limit=$limit&offset=$offset',
      authenticated: true,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final list = data['threads'] is List ? data['threads'] as List : <dynamic>[];
    return list.whereType<Map<String, dynamic>>().map(ChatThread.fromJson).toList();
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
    final list = data['messages'] is List ? data['messages'] as List : <dynamic>[];
    return list.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  Future<void> sendMessage({required int threadId, required String content}) async {
    await _apiClient.post(
      '$sendPath?thread_id=$threadId',
      authenticated: true,
      body: <String, dynamic>{
        'content': content,
      },
    );
  }
}