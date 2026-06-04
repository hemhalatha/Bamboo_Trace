import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<String?> _getIdToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response?> getBatches() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/batches'), headers: headers);
    return response;
  }

  Future<http.Response?> addBatch(Map<String, dynamic> batchData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/batches'),
      headers: headers,
      body: jsonEncode(batchData),
    );
    return response;
  }

  // Similarly for projects and orders...

  Future<http.Response?> getProjects() async {
    final headers = await _getHeaders();
    return await http.get(Uri.parse('$baseUrl/projects'), headers: headers);
  }

  Future<http.Response?> addProject(Map<String, dynamic> projectData) async {
    final headers = await _getHeaders();
    return await http.post(Uri.parse('$baseUrl/projects'), headers: headers, body: jsonEncode(projectData));
  }

  Future<http.Response?> getOrders() async {
    final headers = await _getHeaders();
    return await http.get(Uri.parse('$baseUrl/orders'), headers: headers);
  }

  Future<http.Response?> addOrder(Map<String, dynamic> orderData) async {
    final headers = await _getHeaders();
    return await http.post(Uri.parse('$baseUrl/orders'), headers: headers, body: jsonEncode(orderData));
  }
}
