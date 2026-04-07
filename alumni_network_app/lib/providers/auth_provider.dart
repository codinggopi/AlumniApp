import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  /// Login — sends FCM token as 3rd credential if available.
  Future<bool> login(String email, String password, String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'email': email,
        'password': password,
        'role': role,
      };

      // Include FCM token if already generated (permission granted during splash)
      if (FcmService.cachedToken != null) {
        body['fcm_token'] = FcmService.cachedToken!;
      }

      final response = await _apiService.post('/auth/login', body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _apiService.saveToken(data['access_token']);
        // Fetch full profile (includes profile_picture_url and all fields)
        await checkAuth();
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
        await checkAuth();
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

  /// checkAuth — called on app start if already logged in.
  /// Refreshes user data AND resends FCM token using stored JWT.
  Future<void> checkAuth() async {
    final token = await _apiService.getToken();
    if (token == null) return;

    try {
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200) {
        _user = User.fromJson(jsonDecode(response.body));
        notifyListeners();

        // Resend FCM token with stored JWT for already-logged-in users
        if (_user != null && FcmService.cachedToken != null) {
          FcmService.refreshTokenForLoggedInUser(_user!.userId);
        }
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint('CheckAuth error: $e');
      await logout();
    }
  }
}
