import 'package:flutter/foundation.dart';

class AppConfig {
  static const String supportedBarangay = 'Barangay Muñoz';
  static const List<String> supportedBarangays = <String>[supportedBarangay];

  /// Live website used by release builds (the APK residents install).
  static const String liveBaseUrl = 'https://gabaybatas.com';

  /// Laptop (XAMPP) used by debug builds during development.
  static const String devBaseUrl =
      'http://10.0.10.163/gabaybatas_barangay/gabaybatas';

  // Override via: flutter run --dart-define=API_BASE_URL=https://your-domain.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? liveBaseUrl : devBaseUrl,
  );

  static const Duration requestTimeout = Duration(seconds: 20);

  /// AI answers can take longer (Gemini may be busy; the server retries once).
  static const Duration aiRequestTimeout = Duration(seconds: 120);
}
