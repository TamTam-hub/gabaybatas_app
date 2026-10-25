class AppConfig {
  static const String supportedBarangay = 'Barangay Muñoz';
  static const List<String> supportedBarangays = <String>[supportedBarangay];

  // Override via: flutter run --dart-define=API_BASE_URL=https://your-domain.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.10.163/gabaybatas_barangay/gabaybatas',
  );

  static const Duration requestTimeout = Duration(seconds: 20);
}
