import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://alumniapp-qths.onrender.com';
  // static const String baseUrl = 'https://callum-unstigmatic-yappingly.ngrok-free.dev'; // auto-set by run.bat

  //final _storage = const FlutterSecureStorage();
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
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String endpoint) async {
    final token = await getToken();
    return await http
        .get(Uri.parse('$baseUrl$endpoint'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> post(String endpoint, dynamic body) async {
    final token = await getToken();
    return await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> delete(String endpoint) async {
    final token = await getToken();
    return await http
        .delete(Uri.parse('$baseUrl$endpoint'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> patch(String endpoint, dynamic body) async {
    final token = await getToken();
    return await http
        .patch(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  // Upload using bytes (works on web + mobile)
  Future<http.StreamedResponse> uploadBytes(
    String endpoint,
    List<int> bytes,
    String filename,
  ) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$endpoint'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    return await request.send().timeout(const Duration(seconds: 30));
  }

  Future<http.StreamedResponse> upload(String endpoint, String filePath) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$endpoint'),
    );
    // Include auth + ngrok headers
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    return await request.send().timeout(const Duration(seconds: 30));
  }
}
