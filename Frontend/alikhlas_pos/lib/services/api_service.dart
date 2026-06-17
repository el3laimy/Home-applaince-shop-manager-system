import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import '../controllers/auth_controller.dart';

class ApiService {
  static late final Dio _dio;
  

  static void initialize() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:5291/api';
    if (!baseUrl.endsWith('/')) {
      baseUrl += '/';
    }
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = (await SharedPreferences.getInstance()).getString('auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401) {
          final isRefreshed = await _attemptTokenRefresh();
          if (isRefreshed) {
            // Retry the original request with new token
            final token = (await SharedPreferences.getInstance()).getString('auth_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(retryError as DioException);
            }
          } else {
            // Logout if refresh fails
            try {
              Get.find<AuthController>().logout();
            } catch (_) {}
          }
        }
        return handler.next(error);
      },
    ));
  }

  static Future<bool> _attemptTokenRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final refreshToken = prefs.getString('refresh_token');
      
      if (token == null || refreshToken == null) return false;

      // Use a separate Dio instance to avoid interceptor loops
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await refreshDio.post('/auth/refresh', data: {
        'token': token,
        'refreshToken': refreshToken
      });

      if (response.statusCode == 200) {
        final newToken = response.data['token'];
        final newRefreshToken = response.data['refreshToken'];

        await prefs.setString('auth_token', newToken);
        await prefs.setString('refresh_token', newRefreshToken);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<List<dynamic>> getList(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParameters);
      if (response.data is List) return response.data as List<dynamic>;
      if (response.data is Map && response.data.containsKey('data')) return response.data['data'] as List<dynamic>;
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<dynamic> post(String endpoint, dynamic data) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<dynamic> put(String endpoint, dynamic data) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<dynamic> patch(String endpoint, dynamic data) async {
    try {
      final response = await _dio.patch(endpoint, data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<dynamic> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<dynamic> uploadFile(String endpoint, String filePath, {String fileKey = 'file'}) async {
    try {
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        fileKey: await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post(endpoint, data: formData);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static dynamic _handleResponse(Response response) {
    if (response.data == null || response.data == '') return {};
    return response.data;
  }

  static ApiException _handleDioError(DioException e) {
    String message = 'حدث خطأ غير متوقع في الاتصال بالخادم';
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map) {
        message = data['message'] ?? data['title'] ?? data['detail'] ?? message;
      } else {
        message = data.toString();
      }
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      message = 'انتهت مهلة الاتصال بالخادم، يرجى المحاولة لاحقاً.';
    }
    
    return ApiException(
      statusCode: e.response?.statusCode ?? 500,
      message: message,
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
