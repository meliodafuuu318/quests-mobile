import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    await ApiService.init();
    if (ApiService.isLoggedIn) {
      try {
        final res = await ApiService.getAccountInfo()
            .timeout(const Duration(seconds: 6));
        if (res['error'] == false) {
          _user = res['results'];
        } else {
          await ApiService.clearToken();
        }
      } catch (_) {
        // Server unreachable — log out
        await ApiService.clearToken();
      }
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.login(username: username, password: password)
          .timeout(const Duration(seconds: 10));

      _isLoading = false;
      if (res['error'] == false) {
        await ApiService.setToken(res['results']['token']);
        _user = res['results']['user'];
        notifyListeners();
        return true;
      } else {
        _error = res['message'] ?? 'Login failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Cannot connect. Is your server running?';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      ).timeout(const Duration(seconds: 10));

      _isLoading = false;
      if (res['error'] == false) {
        notifyListeners();
        return true;
      } else {
        _error = res['message'] ?? 'Registration failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Cannot connect. Is your server running?';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.logout().timeout(const Duration(seconds: 5));
    } catch (_) {}
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }
}