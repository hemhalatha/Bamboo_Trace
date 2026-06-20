import 'package:flutter/foundation.dart';

class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    final configuredValue = _configuredApiBaseUrl.trim();
    if (configuredValue.isNotEmpty) return configuredValue;
    if (kReleaseMode) return '';
    return 'http://localhost:8000';
  }

  static void validateApiBaseUrl(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      throw StateError(
        'API_BASE_URL is not configured. Build with --dart-define=API_BASE_URL=https://your-api.example.com',
      );
    }

    final uri = Uri.tryParse(trimmedValue);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL must be a full API URL.');
    }
    if (!{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty) {
      throw StateError('API_BASE_URL must use a valid HTTP(S) URL.');
    }

    if (kReleaseMode && uri.scheme.toLowerCase() != 'https') {
      throw StateError('Production builds require an HTTPS API_BASE_URL.');
    }
    if (kReleaseMode &&
        {'localhost', '127.0.0.1', '0.0.0.0'}.contains(uri.host)) {
      throw StateError('Production builds cannot use a local API_BASE_URL.');
    }
  }
}
