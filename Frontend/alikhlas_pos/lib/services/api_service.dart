import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class ApiService {
  // Base URL - change this to match your backend
  static const String baseUrl = 'http://localhost:5290/api';
  static String? _token;

  static final http.Client _client = http.Client();

  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> get _headers {
    final h = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  // GET request
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  // GET list request
  static Future<List<dynamic>> getList(String endpoint) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    if (data.containsKey('data')) return data['data'] as List<dynamic>;
    return [];
  }

  // POST request
  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // PUT request
  static Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // PATCH request
  static Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // DELETE request
  static Future<dynamic> delete(String endpoint) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) return {'data': decoded};
      return decoded as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      // Token expired or invalid
      try {
        Get.find<AuthController>().logout();
      } catch (_) {}
      throw ApiException(
        statusCode: 401,
        message: 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
      );
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: _parseErrorMessage(response.body),
    );
  }

  static String _parseErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded['message'] ?? decoded['title'] ?? 'حدث خطأ غير متوقع';
      }
    } catch (_) {}
    return body.isNotEmpty ? body : 'حدث خطأ في الاتصال بالخادم';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
