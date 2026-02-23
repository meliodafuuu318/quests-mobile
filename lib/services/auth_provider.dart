import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;
  bool _tokenLoaded = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _tokenLoaded && ApiService.isLoggedIn && _user != null;

  Future<void> init() async {
    try {
      await ApiService.init();
      _tokenLoaded = true;
      // Don't fetch user on init — avoids hanging if server is unreachable
      // Just check if token exists; user will be fetched lazily
      if (ApiService.isLoggedIn) {
        // Try fetching user but don't block if it fails
        await fetchUser().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Token exists but server unreachable — clear token
            ApiService.clearToken();
          },
        );
      }
    } catch (e) {
      _tokenLoaded = true;
      // If init fails, just proceed as logged out
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.login(username: username, password: password)
          .timeout(const Duration(seconds: 10));

      if (res['error'] == false) {
        await ApiService.setToken(res['results']['token']);
        _user = res['results']['user'];
        _tokenLoaded = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Cannot connect to server. Check your network.';
      _isLoading = false;
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

      if (res['error'] == false) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Cannot connect to server. Check your network.';
      _isLoading = false;
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

  Future<void> fetchUser() async {
    try {
      final res = await ApiService.getAccountInfo()
          .timeout(const Duration(seconds: 8));
      if (res['error'] == false) {
        _user = res['results'];
        notifyListeners();
      } else {
        // Invalid token
        await ApiService.clearToken();
        _user = null;
        notifyListeners();
      }
    } catch (_) {
      await ApiService.clearToken();
      _user = null;
    }
  }
}