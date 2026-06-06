import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_user.dart';
import 'token_storage.dart';

class AuthResult {
  AuthResult({required this.accessToken, required this.user});

  final String accessToken;
  final AuthUser user;
}

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = AppConfig.apiBaseUrl});

  Future<String?> _getIdToken() async {
    return TokenStorage.readAccessToken();
  }

  Future<Map<String, String>> _getHeaders({bool authenticated = true}) async {
    final token = await _getIdToken();
    if (authenticated && token == null) {
      throw Exception('Authentication required');
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<AuthResult> signup({
    required String email,
    required String password,
    required String role,
    required String name,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: await _getHeaders(authenticated: false),
      body: jsonEncode({
        'email': email,
        'password': password,
        'role': role,
        'name': name,
      }),
    );
    return _parseAuthResponse(response);
  }

  Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _getHeaders(authenticated: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseAuthResponse(response);
  }

  Future<void> logout() async {
    final token = await _getIdToken();
    if (token == null) return;
    await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: await _getHeaders(),
    );
  }

  Future<AuthUser> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _getHeaders(),
    );
    final data = _decodeObject(response);
    return AuthUser.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getBatches() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/batches'), headers: headers);
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> addBatch(Map<String, dynamic> batchData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/batches'),
      headers: headers,
      body: jsonEncode(batchData),
    );
    return _decodeObject(response);
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/projects'), headers: headers);
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> addProject(Map<String, dynamic> projectData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/projects'),
      headers: headers,
      body: jsonEncode(projectData),
    );
    return _decodeObject(response);
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/orders'), headers: headers);
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> addOrder(Map<String, dynamic> orderData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: headers,
      body: jsonEncode(orderData),
    );
    return _decodeObject(response);
  }

  AuthResult _parseAuthResponse(http.Response response) {
    final data = _decodeObject(response);
    return AuthResult(
      accessToken: data['access_token'] as String,
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = _decodeResponse(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Unexpected response format');
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    final decoded = _decodeResponse(response);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw Exception('Unexpected response format');
  }

  Object? _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
      final detail = decoded['detail'];

      if (detail is String) {
        throw Exception(detail);
      }

      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;

        if (first is Map<String, dynamic> &&
            first.containsKey('msg')) {
          throw Exception(first['msg']);
        }

        throw Exception(detail.toString());
      }
    }
    throw Exception('Request failed with status ${response.statusCode}');
  }
}
