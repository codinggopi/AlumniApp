import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://alumni-app-virid.vercel.app';
  // static const String baseUrl = 'https://callum-unstigmatic-yappingly.ngrok-free.dev';

  static const String _tokenKey = 'access_token';

  // 🔥 ADD THIS (cache)
  static SharedPreferences? _prefs;
  static String? _cachedToken;

  // 🔥 ADD THIS (init once)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cachedToken = _prefs?.getString(_tokenKey);
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    _prefs ??= await SharedPreferences.getInstance();
    _cachedToken = _prefs?.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_tokenKey, token);
  }

  Future<void> deleteToken() async {
    _cachedToken = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_tokenKey);
  }

  /// Set token in memory only — not persisted to SharedPreferences.
  /// Used when "Remember Me" is unchecked.
  void setSessionToken(String token) {
    _cachedToken = token;
  }

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<http.Response> get(String endpoint) async {
    final token = await getToken();
    final request = http.get(Uri.parse('$baseUrl$endpoint'), headers: _headers(token));
    // No timeout for auth/me — called right after login
    if (endpoint.contains('auth/me') || endpoint.contains('auth')) {
      return request;
    }
    return request.timeout(const Duration(seconds: 20));
  }

  Future<http.Response> post(String endpoint, dynamic body) async {
    final token = await getToken();

    final request = http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    // No timeout for auth/login — server may be cold starting
    if (endpoint.contains('login') || endpoint.contains('auth')) {
      return request;
    }

    final timeout = (endpoint.contains('otp') || endpoint.contains('email-change'))
        ? const Duration(seconds: 30)
        : const Duration(seconds: 15);

    return request.timeout(timeout);
  }

  Future<http.Response> delete(String endpoint) async {
    final token = await getToken();
    return http
        .delete(Uri.parse('$baseUrl$endpoint'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> patch(String endpoint, dynamic body) async {
    final token = await getToken();
    return http
        .patch(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<http.StreamedResponse> uploadBytes(
    String endpoint,
    List<int> bytes,
    String filename,
  ) async {
    final token = await getToken();
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));

    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    return request.send().timeout(const Duration(seconds: 30));
  }

  Future<http.StreamedResponse> upload(
      String endpoint, String filePath) async {
    final token = await getToken();
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));

    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    return request.send().timeout(const Duration(seconds: 30));
  }
}