import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_store.dart';

class AuthService {
  AuthService({ApiClient? apiClient})
    : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String loginPath = '/api/v1/auth_login.php';
  static const String registerPath = '/api/v1/auth_register.php';
  static const String forgotPasswordPath = '/api/v1/auth_forgot_password.php';
  static const String googleLoginPath = '/api/v1/auth_google_login.php';

  Future<void> login({required String email, required String password}) async {
    final response = await _apiClient.post(
      loginPath,
      body: <String, dynamic>{'email': email, 'password': password},
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
      throw ApiException(
        response['message']?.toString() ?? 'Registration failed.',
      );
    }
  }

  Future<String> requestPasswordReset(String email) async {
    final response = await _apiClient.post(
      forgotPasswordPath,
      body: <String, dynamic>{'email': email.trim()},
    );
    return response['message']?.toString() ??
        'If an account uses that email, a password reset link has been sent.';
  }

  Future<void> loginWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: '863706178690-965pvkn8tjopv1lnmvul4js0bb0cqbga.apps.googleusercontent.com',
      scopes: <String>['email'],
    );

    // Sign out first to always show account picker
    await googleSignIn.signOut();

    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      throw ApiException('Google sign-in was cancelled.');
    }

    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw ApiException('Unable to get Google credentials. Please try again.');
    }

    final response = await _apiClient.post(
      googleLoginPath,
      body: <String, dynamic>{
        'id_token': idToken,
        'name': account.displayName ?? '',
        'email': account.email,
      },
    );

    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;

    final token =
        data['token']?.toString() ?? data['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Google login succeeded but token was not returned by API.',
      );
    }

    await SessionStore.saveToken(token);
  }
}
