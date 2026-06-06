import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import 'api_service.dart';
import 'token_storage.dart';

class AuthService with ChangeNotifier {
  AuthService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  AuthUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthUser? get currentUser => _currentUser;
  String? get userRole => _currentUser?.role;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    final token = await TokenStorage.readAccessToken();
    if (token == null) return;

    _setLoading(true);
    try {
      _currentUser = await _apiService.getCurrentUser();
    } catch (e) {
      debugPrint('Stored session is invalid: $e');
      await TokenStorage.clearAccessToken();
      _currentUser = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn(String email, String password) async {
    return _authenticate(() => _apiService.login(email, password));
  }

  Future<bool> signUp(
    String email,
    String password,
    String role,
    String name,
  ) async {
    return _authenticate(() => _apiService.signup(
          email: email,
          password: password,
          role: role,
          name: name,
        ));
  }

  Future<void> signOut() async {
    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint('Logout request failed: $e');
    } finally {
      await TokenStorage.clearAccessToken();
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<bool> _authenticate(
    Future<AuthResult> Function() request,
  ) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await request();
      await TokenStorage.writeAccessToken(result.accessToken);
      _currentUser = result.user;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

}
