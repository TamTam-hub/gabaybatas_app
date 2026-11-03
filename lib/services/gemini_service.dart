// The Dart SDK currently deprecates RegExp construction without providing a
// replacement for runtime regular-expression patterns.
// ignore_for_file: deprecated_member_use

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import 'legal_context_builder.dart';

class GeminiChatMessage {
  const GeminiChatMessage({required this.fromUser, required this.content});

  final bool fromUser;
  final String content;
}

/// Answers residents' questions with Gemini through the GabayBatas website
/// (api/v1/ai_chat.php). The website keeps the Gemini key and the assistant's
/// instructions; the app adds the matching Legal Information articles.
class GeminiService {
  GeminiService({LegalContextBuilder? legalContext, ApiClient? apiClient})
    : _legalContext = legalContext ?? LegalContextBuilder(),
      _apiClient = apiClient ?? const ApiClient();

  static const String aiPath = '/api/v1/ai_chat.php';

  final LegalContextBuilder _legalContext;
  final ApiClient _apiClient;

  /// Loads the Legal Information articles before the first question.
  void preloadLegalInformation() => _legalContext.preload();

  /// [history] holds the earlier turns only, not [message] itself.
  Future<String> generateReply({
    required String message,
    List<GeminiChatMessage> history = const <GeminiChatMessage>[],
  }) async {
    final previousQuestion = history
        .lastWhere(
          (item) => item.fromUser,
          orElse: () => const GeminiChatMessage(fromUser: true, content: ''),
        )
        .content;
    final context = await _legalContext.buildContext(
      message,
      previousQuestion: previousQuestion,
    );
    final response = await _apiClient.post(
      aiPath,
      authenticated: true,
      timeout: AppConfig.aiRequestTimeout,
      body: <String, dynamic>{
        'message': message,
        'context': context,
        // This app shows the Submit a Case button the assistant may suggest.
        'submit_button': true,
        'history': [
          for (final item in history)
            {'role': item.fromUser ? 'user' : 'model', 'text': item.content},
        ],
      },
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final reply = _cleanResponse((data['reply'] ?? '').toString());
    if (reply.isEmpty) {
      throw ApiException('The AI assistant returned an empty response.');
    }
    return reply;
  }

  String _cleanResponse(String response) {
    final lines = response.trim().split('\n').map((line) {
      var cleaned = line.trimRight();
      cleaned = cleaned.replaceAll('```', '');
      cleaned = cleaned.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
      cleaned = cleaned.replaceAll('**', '');
      cleaned = cleaned.replaceAll('__', '');
      cleaned = cleaned.replaceAllMapped(RegExp(r'^\s*[*+-]\s+'), (_) => '• ');
      cleaned = cleaned.replaceAll('*', '');
      cleaned = cleaned.replaceAll('---', '');
      return cleaned;
    }).toList();

    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
