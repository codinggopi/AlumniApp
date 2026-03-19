import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password, String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
        'role': role,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _apiService.saveToken(data['access_token']);
        _user = User.fromJson(data);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> sendOtp(String email) async {
    try {
      final response = await _apiService.post('/send-otp', {'email': email});
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Send OTP error: $e');
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String otp, String fullName, String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/verify-otp', {
        'email': email,
        'otp': otp,
        'full_name': fullName,
        'role': role,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _apiService.saveToken(data['access_token']);
        await checkAuth(); // Fetch full profile
        return true;
      }
    } catch (e) {
      debugPrint('Verify OTP error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _apiService.deleteToken();
    _user = null;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final token = await _apiService.getToken();
    if (token == null) return;

    try {
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200) {
        _user = User.fromJson(jsonDecode(response.body));
        notifyListeners();
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint('CheckAuth error: $e');
      await logout();
    }
  }
}
