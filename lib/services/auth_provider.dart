import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => ApiService.isLoggedIn && _user != null;

  Future<void> init() async {
    await ApiService.init();
    if (ApiService.isLoggedIn) {
      await fetchUser();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.login(username: username, password: password);
      if (res['error'] == false) {
        await ApiService.setToken(res['results']['token']);
        _user = res['results']['user'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Connection error. Check your network.';
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
      );
      if (res['error'] == false) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Connection error. Check your network.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.logout();
    } catch (_) {}
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }

  Future<void> fetchUser() async {
    try {
      final res = await ApiService.getAccountInfo();
      if (res['error'] == false) {
        _user = res['results'];
        notifyListeners();
      }
    } catch (_) {}
  }
}