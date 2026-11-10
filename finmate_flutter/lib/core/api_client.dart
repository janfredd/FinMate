import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

const String kNetworkErrorMessage =
    'Koneksi internet terputus. Silakan periksa jaringan Anda.';
const String kServerErrorMessage =
    'Terjadi kesalahan pada server. Silakan coba beberapa saat lagi.';
const String kInvalidCredentialsMessage =
    'Email atau password salah. Silakan coba lagi.';

// Global navigator key so an expired session can pop back to the root gate.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class FriendlyException implements Exception {
  final String message;
  const FriendlyException(this.message);
  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();
  @override
  String toString() => '';
}

// Dio client: attaches JWT, maps low-level errors to friendly messages,
// and clears the session + redirects to Login on HTTP 401.
class ApiClient {
  final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<void> Function()? onUnauthorized;

  ApiClient()
      : dio = Dio(BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
            headers: {'Content-Type': 'application/json'})) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await _storage.read(key: 'jwt');
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        return h.next(o);
      },
      onError: (e, h) async {
        final status = e.response?.statusCode;
        final path = e.requestOptions.path;
        final isCredentialRequest = path.contains('/auth/login') ||
            path.contains('/auth/register');

        if (status == 401) {
          if (isCredentialRequest) {
            return h.reject(e.copyWith(
                error: const FriendlyException(kInvalidCredentialsMessage),
                message: kInvalidCredentialsMessage));
          }
          await clearToken();
          try {
            await onUnauthorized?.call();
          } catch (_) {
            // Ignore redirect failures; token is already removed.
          }
          return h.reject(
              e.copyWith(error: const UnauthorizedException(), message: ''));
        }

        final message = _messageFor(e);
        return h.reject(
            e.copyWith(error: FriendlyException(message), message: message));
      },
    ));
  }

  String _messageFor(DioException e) {
    if (_isNetworkError(e)) return kNetworkErrorMessage;
    final status = e.response?.statusCode;
    if (status != null && status >= 500) return kServerErrorMessage;
    if (status == 403) return 'Anda tidak memiliki akses untuk tindakan ini.';
    if (status == 404) return 'Data yang diminta tidak ditemukan.';
    final detail = _detailFrom(e.response?.data);
    if (detail != null && detail.isNotEmpty) return detail;
    if (status == 400) {
      return 'Permintaan tidak valid. Periksa kembali data Anda.';
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.error is SocketException;

  String? _detailFrom(Object? data) {
    if (data is! Map || data['detail'] == null) return null;
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
      return first.toString();
    }
    return detail.toString();
  }

  Future<void> saveToken(String t) => _storage.write(key: 'jwt', value: t);
  Future<void> clearToken() => _storage.delete(key: 'jwt');
  Future<String?> readToken() => _storage.read(key: 'jwt');
}

String friendlyError(Object e) {
  if (e is FriendlyException) return e.message;
  if (e is UnauthorizedException) return '';
  if (e is DioException) {
    final inner = e.error;
    if (inner is UnauthorizedException) return '';
    if (inner is FriendlyException) return inner.message;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        inner is SocketException) {
      return kNetworkErrorMessage;
    }
    final status = e.response?.statusCode;
    if (status == 401) return '';
    if (status != null && status >= 500) return kServerErrorMessage;
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}

void showFriendlyError(BuildContext context, Object e) {
  final message = friendlyError(e);
  if (message.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)));
}
