import "dart:async";
import "dart:developer" as developer;
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/services.dart" show rootBundle;
import "package:injectable/injectable.dart";
import "package:iptv_core/iptv_core.dart";

const String _kLog = "iptv.http";

/// Scheme for bundled (in-app asset) playlists, e.g. the demo source. The
/// suffix is a Flutter asset key resolved through [rootBundle].
const String _kAssetScheme = "asset:";

/// Dio-backed [HttpService]. The only place the HTTP engine is imported.
///
/// Maps Dio failures to the exceptions `catchError` understands
/// ([HttpStatusException] for non-2xx, [SocketException]/[TimeoutException] for
/// connectivity) and logs every request/response for debugging.
@LazySingleton(as: HttpService)
class DioHttpService implements HttpService {
  DioHttpService(this._dio);

  final Dio _dio;

  @factoryMethod
  factory DioHttpService.create() {
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: Env.requestTimeout,
        receiveTimeout: Env.requestTimeout,
      ),
    );
    return DioHttpService(dio);
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _request(
      path,
      queryParameters: queryParameters,
      headers: headers,
      responseType: ResponseType.json,
    );
  }

  @override
  Future<String> getRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    if (path.startsWith(_kAssetScheme)) {
      return rootBundle.loadString(path.substring(_kAssetScheme.length));
    }
    final dynamic data = await _request(
      path,
      queryParameters: queryParameters,
      headers: headers,
      responseType: ResponseType.plain,
    );
    return data is String ? data : "${data ?? ""}";
  }

  Future<dynamic> _request(
    String path, {
    required ResponseType responseType,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    developer.log(
      "GET $path  query=${_redact(queryParameters)}",
      name: _kLog,
    );
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers, responseType: responseType),
      );
      developer.log(
        "← ${response.statusCode} $path "
        "type=${response.data.runtimeType} "
        "contentType=${response.headers.value(Headers.contentTypeHeader)}",
        name: _kLog,
      );
      _ensureSuccess(response.statusCode);
      return response.data;
    } on DioException catch (e, stackTrace) {
      developer.log(
        "✗ $path failed: ${e.type} status=${e.response?.statusCode} "
        "msg=${e.message} body=${_preview(e.response?.data)}",
        name: _kLog,
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDioError(e);
    }
  }

  void _ensureSuccess(int? statusCode) {
    final int code = statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw HttpStatusException(code);
    }
  }

  /// Translates a [DioException] into the exception types `catchError` maps.
  Object _mapDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        TimeoutException(e.message),
      DioExceptionType.connectionError =>
        const SocketException("connection error"),
      DioExceptionType.badResponse => HttpStatusException(
          e.response?.statusCode ?? 0,
          _preview(e.response?.data),
        ),
      _ => HttpStatusException(0, e.message),
    };
  }

  /// Hides the password value in logged query parameters.
  String _redact(Map<String, dynamic>? query) {
    if (query == null) return "{}";
    return query
        .map(
          (String k, dynamic v) =>
              MapEntry<String, dynamic>(k, k == "password" ? "***" : v),
        )
        .toString();
  }

  String _preview(dynamic body) {
    final String s = "$body";
    return s.length > 200 ? "${s.substring(0, 200)}…" : s;
  }
}
