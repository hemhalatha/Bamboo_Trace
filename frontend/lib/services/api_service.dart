import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/app_notification.dart';
import '../models/auth_user.dart';
import '../models/custom_order_request.dart';
import '../models/order.dart';
import '../models/order_request.dart';
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

  Future<List<Map<String, dynamic>>> getProjectCatalog() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/projects/catalog'), headers: headers);
    return _decodeList(response);
  }

  Future<List<Map<String, dynamic>>> getArtisans() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/users/artisans'), headers: headers);
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

  Future<List<Order>> getOrderModels() async {
    final orders = await getOrders();
    return orders.map(Order.fromJson).toList();
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

  Future<Order> placeProductOrder({
    required String productId,
    required int quantity,
    required String quantityUnit,
    required String fulfillmentType,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/product'),
      headers: headers,
      body: jsonEncode({
        'productId': productId,
        'quantity': quantity,
        'quantityUnit': quantityUnit,
        'fulfillmentType': fulfillmentType,
      }),
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Order> placeMaterialOrder({
    required String batchId,
    required int quantity,
    required String quantityUnit,
    required String fulfillmentType,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/material'),
      headers: headers,
      body: jsonEncode({
        'batchId': batchId,
        'quantity': quantity,
        'quantityUnit': quantityUnit,
        'fulfillmentType': fulfillmentType,
      }),
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Order> updateOrderStatus(String orderId, String status) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/orders/$orderId/status'),
      headers: headers,
      body: jsonEncode({'status': status}),
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Map<String, dynamic>> generateHandoverOtp(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/generate-handover-otp'),
      headers: headers,
    );
    return _decodeObject(response);
  }

  Future<Order> verifyHandoverOtp(String orderId, String otp) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/verify-handover-otp'),
      headers: headers,
      body: jsonEncode({'otp': otp}),
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Order> confirmOrderReceived(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/confirm-received'),
      headers: headers,
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Order> reportOrderDispute(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/report-dispute'),
      headers: headers,
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<List<Map<String, dynamic>>> getBatchCatalog() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/batches/catalog'), headers: headers);
    return _decodeList(response);
  }

  Future<OrderRequest> createOrderRequest({
    required String requestType,
    required String receiverId,
    String? orderId,
    String? productId,
    String? batchId,
    required int quantity,
    required String quantityUnit,
    String? notes,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/order-requests'),
      headers: headers,
      body: jsonEncode({
        'requestType': requestType,
        'receiverId': receiverId,
        if (orderId != null) 'orderId': orderId,
        if (productId != null) 'productId': productId,
        if (batchId != null) 'batchId': batchId,
        'quantity': quantity,
        'quantityUnit': quantityUnit,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    return OrderRequest.fromJson(_decodeObject(response));
  }

  Future<List<OrderRequest>> getActiveRequests() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/order-requests/active'), headers: headers);
    return _decodeList(response).map(OrderRequest.fromJson).toList();
  }

  Future<List<OrderRequest>> getRequestHistory() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/order-requests/history'), headers: headers);
    return _decodeList(response).map(OrderRequest.fromJson).toList();
  }

  Future<OrderRequest> acceptOrderRequest(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/order-requests/$requestId/accept'),
      headers: headers,
    );
    return OrderRequest.fromJson(_decodeObject(response));
  }

  Future<OrderRequest> rejectOrderRequest(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/order-requests/$requestId/reject'),
      headers: headers,
    );
    return OrderRequest.fromJson(_decodeObject(response));
  }

  Future<List<AppNotification>> getNotifications() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/notifications'), headers: headers);
    return _decodeList(response).map(AppNotification.fromJson).toList();
  }

  Future<int> getUnreadNotificationCount() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/notifications/unread-count'), headers: headers);
    return (_decodeObject(response)['count'] ?? 0) as int;
  }

  Future<AppNotification> markNotificationRead(String notificationId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: headers,
    );
    return AppNotification.fromJson(_decodeObject(response));
  }

  Future<CustomOrderRequest> createCustomOrderRequest({
    required String targetType,
    String? targetArtisanId,
    required String title,
    required String description,
    required int quantity,
    double? budget,
    String? deadline,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/custom-order-requests'),
      headers: headers,
      body: jsonEncode({
        'targetType': targetType,
        if (targetArtisanId != null) 'targetArtisanId': targetArtisanId,
        'title': title,
        'description': description,
        'quantity': quantity,
        if (budget != null) 'budget': budget,
        if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
      }),
    );
    return CustomOrderRequest.fromJson(_decodeObject(response));
  }

  Future<List<CustomOrderRequest>> getActiveCustomOrderRequests() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/custom-order-requests/active'), headers: headers);
    return _decodeList(response).map(CustomOrderRequest.fromJson).toList();
  }

  Future<List<CustomOrderRequest>> getCustomOrderRequestHistory() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/custom-order-requests/history'), headers: headers);
    return _decodeList(response).map(CustomOrderRequest.fromJson).toList();
  }

  Future<CustomOrderRequest> acceptCustomOrderRequest(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/custom-order-requests/$requestId/accept'),
      headers: headers,
    );
    return CustomOrderRequest.fromJson(_decodeObject(response));
  }

  Future<CustomOrderRequest> rejectCustomOrderRequest(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/custom-order-requests/$requestId/reject'),
      headers: headers,
    );
    return CustomOrderRequest.fromJson(_decodeObject(response));
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
