import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_store.dart';

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String loginPath = '/api/v1/auth_login.php';
  static const String registerPath = '/api/v1/auth_register.php';

  Future<void> login({required String email, required String password}) async {
    final response = await _apiClient.post(
      loginPath,
      body: <String, dynamic>{
        'email': email,
        'password': password,
      },
    );

    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;

    final token = data['token']?.toString() ?? data['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Login succeeded but token was not returned by API.');
    }

    await SessionStore.saveToken(token);
  }

  Future<void> register({
    required String fullName,
    required String age,
    required String barangay,
    required String contactNumber,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _apiClient.post(
      registerPath,
      body: <String, dynamic>{
        'name': fullName,
        'age': age,
        'barangay': barangay,
        'contact_number': contactNumber,
        'email': email,
        'password': password,
        'password_confirmation': confirmPassword,
      },
    );

    if (response['success'] == false) {
      throw ApiException(response['message']?.toString() ?? 'Registration failed.');
    }
  }
}