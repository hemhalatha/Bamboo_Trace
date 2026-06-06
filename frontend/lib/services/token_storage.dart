import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _tokenKey = 'access_token';
  static const _storage = FlutterSecureStorage();

  static Future<String?> readAccessToken() {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> writeAccessToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> clearAccessToken() {
    return _storage.delete(key: _tokenKey);
  }
}
