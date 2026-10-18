import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

// Dio client: attaches JWT, handles 401 + offline-friendly errors.
class ApiClient {
  final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  ApiClient()
      : dio = Dio(BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'})) {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      final t = await _storage.read(key: 'jwt');
      if (t != null) o.headers['Authorization'] = 'Bearer $t';
      return h.next(o);
    }));
  }
  Future<void> saveToken(String t) => _storage.write(key: 'jwt', value: t);
  Future<void> clearToken() => _storage.delete(key: 'jwt');
  Future<String?> readToken() => _storage.read(key: 'jwt');
}

String friendlyError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['detail'] != null) return d['detail'].toString();
    if (e.type == DioExceptionType.connectionTimeout) return 'Connection timed out. Check network.';
    return 'Network error: ${e.message}';
  }
  return e.toString();
}
