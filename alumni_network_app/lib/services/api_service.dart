import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://10.101.214.10:8000'; // Change to IP for physical device
  final _storage = const FlutterSecureStorage();

  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'access_token');
  }

  Map<String, String> _headers(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String endpoint) async {
    final token = await getToken();
    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(token),
    );
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    return await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
  }
}
