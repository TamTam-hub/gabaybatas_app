class AppConfig {
  // Override via: flutter run --dart-define=API_BASE_URL=https://your-domain.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2/gabaybatas_barangay/gabaybatas',
  );

  static const Duration requestTimeout = Duration(seconds: 20);
}