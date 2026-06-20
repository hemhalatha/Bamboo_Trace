import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/app_notification.dart';
import '../models/auth_user.dart';
import '../models/custom_order_request.dart';
import '../models/order.dart';
import '../models/order_request.dart';
import 'token_storage.dart';

class AuthResult {
  AuthResult({
    required this.accessToken,
    required this.user,
    required this.profileComplete,
  });

  final String accessToken;
  final AuthUser user;
  final bool profileComplete;
}

class ProfileRequiredException implements Exception {
  ProfileRequiredException(this.message, {this.missingFields = const []});

  final String message;
  final List<String> missingFields;

  @override
  String toString() => message;
}

class ApiConfigurationException implements Exception {
  ApiConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiException implements Exception {
  ApiException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final String baseUrl;

  Uri _uri(String path) {
    try {
      AppConfig.validateApiBaseUrl(baseUrl);
    } catch (error) {
      throw ApiConfigurationException(error.toString().replaceFirst('Bad state: ', ''));
    }
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBaseUrl$normalizedPath');
  }

  String? resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    final path = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
    return '$baseUrl$path';
  }

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
      _uri('/auth/signup'),
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
      _uri('/auth/login'),
      headers: await _getHeaders(authenticated: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseAuthResponse(response);
  }

  Future<void> logout() async {
    final token = await _getIdToken();
    if (token == null) return;
    await http.post(
      _uri('/auth/logout'),
      headers: await _getHeaders(),
    );
  }

  Future<AuthUser> getCurrentUser() async {
    final response = await http.get(
      _uri('/auth/me'),
      headers: await _getHeaders(),
    );
    final data = _decodeObject(response);
    return AuthUser.fromJson(data);
  }

  Future<AuthUser> updateProfile(Map<String, dynamic> profileData) async {
    final response = await http.patch(
      _uri('/users/me/profile'),
      headers: await _getHeaders(),
      body: jsonEncode(profileData),
    );
    return AuthUser.fromJson(_decodeObject(response));
  }

  Future<List<Map<String, dynamic>>> getBatches() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/batches'),
      headers: headers,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> addBatch(Map<String, dynamic> batchData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/batches'),
      headers: headers,
      body: jsonEncode(batchData),
    );
    return _decodeObject(response);
  }

  Future<String> uploadImage(XFile image) async {
    final headers = await _getHeaders();
    final request = http.MultipartRequest(
      'POST',
      _uri('/uploads/images'),
    );
    final authorization = headers['Authorization'];
    if (authorization != null) {
      request.headers['Authorization'] = authorization;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await image.readAsBytes(),
        filename: image.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeObject(response);
    return data['imageUrl']?.toString() ?? data['image_url']?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/projects'),
      headers: headers,
    );
    return _decodeList(response);
  }

  Future<List<Map<String, dynamic>>> getMyArtisanProducts() => getProjects();

  Future<List<Map<String, dynamic>>> getProjectCatalog() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/projects/catalog'),
      headers: headers,
    );
    return _decodeList(response);
  }

  Future<List<Map<String, dynamic>>> getArtisans() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/users/artisans'),
      headers: headers,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> addProject(
    Map<String, dynamic> projectData,
  ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/projects'),
      headers: headers,
      body: jsonEncode(projectData),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> createArtisanProduct(
    Map<String, dynamic> productData,
  ) => addProject(productData);

  Future<Map<String, dynamic>> updateProject(
    String projectId,
    Map<String, dynamic> projectData,
  ) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      _uri('/projects/$projectId'),
      headers: headers,
      body: jsonEncode(projectData),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> updateArtisanProduct(
    String productId,
    Map<String, dynamic> productData,
  ) => updateProject(productId, productData);

  Future<Map<String, dynamic>> updateArtisanProductStatus(
    String productId,
    String status,
  ) => updateProject(productId, {'status': status});

  Future<List<Map<String, dynamic>>> getOrders() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/orders'),
      headers: headers,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/dashboard/stats'),
      headers: headers,
    );
    return _decodeObject(response);
  }

  Future<List<Order>> getOrderModels() async {
    final orders = await getOrders();
    return orders.map(Order.fromJson).toList();
  }

  Future<Order> getOrderById(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/orders/$orderId'),
      headers: headers,
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Map<String, dynamic>> addOrder(Map<String, dynamic> orderData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/orders'),
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
      _uri('/orders/product'),
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
      _uri('/orders/material'),
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
      _uri('/orders/$orderId/status'),
      headers: headers,
      body: jsonEncode({'status': status}),
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Map<String, dynamic>> generateHandoverOtp(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/orders/$orderId/generate-handover-otp'),
      headers: headers,
    );
    return _decodeObject(response);
  }

  Future<Order> verifyHandoverOtp(String orderId, String otp) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/orders/$orderId/verify-handover-otp'),
      headers: headers,
      body: jsonEncode({'otp': otp}),
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Order> confirmOrderReceived(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/orders/$orderId/confirm-received'),
      headers: headers,
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<Order> reportOrderDispute(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/orders/$orderId/report-dispute'),
      headers: headers,
    );
    return Order.fromJson(_decodeObject(response));
  }

  Future<List<Map<String, dynamic>>> getBatchCatalog() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/batches/catalog'),
      headers: headers,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> getBatchById(String batchId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/batches/$batchId'),
      headers: headers,
    );
    return _decodeObject(response);
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
      _uri('/order-requests'),
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
    final response = await http.get(
      _uri('/order-requests/active'),
      headers: headers,
    );
    return _decodeList(response).map(OrderRequest.fromJson).toList();
  }

  Future<List<OrderRequest>> getRequestHistory() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/order-requests/history'),
      headers: headers,
    );
    return _decodeList(response).map(OrderRequest.fromJson).toList();
  }

  Future<OrderRequest> getOrderRequestById(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/order-requests/$requestId'),
      headers: headers,
    );
    return OrderRequest.fromJson(_decodeObject(response));
  }

  Future<OrderRequest> acceptOrderRequest(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/order-requests/$requestId/accept'),
      headers: headers,
    );
    return OrderRequest.fromJson(_decodeObject(response));
  }

  Future<OrderRequest> rejectOrderRequest(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/order-requests/$requestId/reject'),
      headers: headers,
    );
    return OrderRequest.fromJson(_decodeObject(response));
  }

  Future<List<AppNotification>> getNotifications() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/notifications'),
      headers: headers,
    );
    return _decodeList(response).map(AppNotification.fromJson).toList();
  }

  Future<int> getUnreadNotificationCount() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/notifications/unread-count'),
      headers: headers,
    );
    return (_decodeObject(response)['count'] ?? 0) as int;
  }

  Future<AppNotification> markNotificationRead(String notificationId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/notifications/$notificationId/read'),
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
    String? imageUrl,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/custom-order-requests'),
      headers: headers,
      body: jsonEncode({
        'targetType': targetType,
        if (targetArtisanId != null) 'targetArtisanId': targetArtisanId,
        'title': title,
        'description': description,
        'quantity': quantity,
        if (budget != null) 'budget': budget,
        if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      }),
    );
    return CustomOrderRequest.fromJson(_decodeObject(response));
  }

  Future<List<CustomOrderRequest>> getActiveCustomOrderRequests() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/custom-order-requests/active'),
      headers: headers,
    );
    return _decodeList(response).map(CustomOrderRequest.fromJson).toList();
  }

  Future<List<CustomOrderRequest>> getCustomOrderRequestHistory() async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/custom-order-requests/history'),
      headers: headers,
    );
    return _decodeList(response).map(CustomOrderRequest.fromJson).toList();
  }

  Future<CustomOrderRequest> getCustomOrderRequestById(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      _uri('/custom-order-requests/$requestId'),
      headers: headers,
    );
    return CustomOrderRequest.fromJson(_decodeObject(response));
  }

  Future<CustomOrderRequest> acceptCustomOrderRequest(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/custom-order-requests/$requestId/accept'),
      headers: headers,
    );
    return CustomOrderRequest.fromJson(_decodeObject(response));
  }

  Future<CustomOrderRequest> rejectCustomOrderRequest(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      _uri('/custom-order-requests/$requestId/reject'),
      headers: headers,
    );
    return CustomOrderRequest.fromJson(_decodeObject(response));
  }

  AuthResult _parseAuthResponse(http.Response response) {
    final data = _decodeObject(response);
    return AuthResult(
      accessToken: data['access_token'] as String,
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      profileComplete: data['profileComplete'] == true,
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
    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          'The server returned an invalid response. Please try again later.',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map<String, dynamic>) {
          final field = first['field']?.toString().split('.').last;
          final message = first['message']?.toString();
          if (message != null && message.isNotEmpty) {
            final label = field == null || field.isEmpty
                ? ''
                : '${field[0].toUpperCase()}${field.substring(1)}: ';
            throw ApiException(
              '$label$message',
              statusCode: response.statusCode,
            );
          }
        }
      }

      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) {
        throw ApiException(detail, statusCode: response.statusCode);
      }

      if (detail is Map<String, dynamic>) {
        final message = detail['message'];
        if (detail['profileRequired'] == true) {
          final missingFields = detail['missingFields'];
          throw ProfileRequiredException(
            message is String && message.isNotEmpty
                ? message
                : 'Please complete your profile before continuing.',
            missingFields: missingFields is List
                ? missingFields.map((field) => field.toString()).toList()
                : const [],
          );
        }
        if (message is String && message.isNotEmpty) {
          throw ApiException(message, statusCode: response.statusCode);
        }
      }

      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic> && first['msg'] != null) {
          throw ApiException(
            first['msg'].toString(),
            statusCode: response.statusCode,
          );
        }
      }
    }

    final message = response.statusCode >= 500
        ? 'The server had a problem. Please try again later.'
        : 'Request failed. Please try again.';
    throw ApiException(message, statusCode: response.statusCode);
  }
}

