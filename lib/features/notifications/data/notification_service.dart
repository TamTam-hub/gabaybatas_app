import '../../../core/network/api_client.dart';

class AppNotification {
  AppNotification({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.createdAt,
  });

  final int notificationId;
  final String title;
  final String message;
  final String type;
  final bool read;
  final String createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      notificationId: int.tryParse((json['notification_id'] ?? '').toString()) ?? 0,
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      read: json['read'] == true || json['read']?.toString() == '1',
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class NotificationResult {
  NotificationResult({
    required this.total,
    required this.unreadCount,
    required this.notifications,
  });

  final int total;
  final int unreadCount;
  final List<AppNotification> notifications;
}

class NotificationService {
  NotificationService({ApiClient? apiClient}) : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String notificationsPath = '/api/v1/notifications.php';

  Future<NotificationResult> listNotifications({
    int limit = 10,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'unread_only': unreadOnly ? 'true' : 'false',
    };
    final query = params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&');

    final response = await _apiClient.get('$notificationsPath?$query', authenticated: true);
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final list = data['notifications'] is List ? data['notifications'] as List : <dynamic>[];

    return NotificationResult(
      total: int.tryParse((data['total'] ?? list.length).toString()) ?? list.length,
      unreadCount: int.tryParse((data['unread_count'] ?? 0).toString()) ?? 0,
      notifications: list
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(),
    );
  }

  Future<void> markAsRead(int notificationId) async {
    await _apiClient.patch(
      notificationsPath,
      authenticated: true,
      body: <String, dynamic>{
        'notification_id': notificationId,
      },
    );
  }
}
