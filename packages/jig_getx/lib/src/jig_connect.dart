import 'package:get/get.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

/// A [GetConnect] that reports every exchange to the jig bus.
///
/// Tracing sits in overrides rather than in request/response modifiers for one
/// reason: `GetConnect` turns transport failures into a `GetHttpException`
/// without ever invoking a response modifier, so a modifier-only design reports
/// happy paths and silently drops timeouts and DNS failures.
///
/// Swapping `extends GetConnect` for `extends JigConnect` in a repository base
/// class therefore instruments every repository under it.
class JigConnect extends GetConnect {
  JigConnect({
    super.timeout,
    super.maxAuthRetries,
    super.allowAutoSignedCert,
  });

  int _nextId = 0;

  Future<Response<T>> _trace<T>(
    String method,
    String? url,
    Future<Response<T>> Function() send,
  ) async {
    final id = ++_nextId;
    final stopwatch = Stopwatch()..start();
    JigBus.instance.emit(JigSource.http, 'request', <String, Object?>{
      'id': id,
      'method': method,
      'url': ?url,
    });
    try {
      final response = await send();
      stopwatch.stop();
      if (response.statusCode == null) {
        // GetConnect reports some transport failures as a bodiless response
        // rather than an exception; classifying those as successes is exactly
        // the silent-drop this tracing exists to prevent.
        final statusText = response.statusText;
        JigBus.instance.emit(JigSource.http, 'error', <String, Object?>{
          'id': id,
          'method': method,
          'url': ?url,
          'error': statusText == null || statusText.isEmpty
              ? 'no response'
              : statusText,
          'ms': stopwatch.elapsedMilliseconds,
        });
        return response;
      }
      JigBus.instance.emit(JigSource.http, 'response', <String, Object?>{
        'id': id,
        'method': method,
        'url': ?url,
        'status': response.statusCode,
        'ms': stopwatch.elapsedMilliseconds,
      });
      return response;
    } catch (error) {
      stopwatch.stop();
      JigBus.instance.emit(JigSource.http, 'error', <String, Object?>{
        'id': id,
        'method': method,
        'url': ?url,
        'error': error.toString(),
        'ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  @override
  Future<Response<T>> get<T>(
    String url, {
    Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
  }) {
    return _trace(
      'GET',
      url,
      () => super.get<T>(
        url,
        headers: headers,
        contentType: contentType,
        query: query,
        decoder: decoder,
      ),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String? url,
    dynamic body, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    return _trace(
      'POST',
      url,
      () => super.post<T>(
        url,
        body,
        contentType: contentType,
        headers: headers,
        query: query,
        decoder: decoder,
        uploadProgress: uploadProgress,
      ),
    );
  }

  @override
  Future<Response<T>> put<T>(
    String url,
    dynamic body, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    return _trace(
      'PUT',
      url,
      () => super.put<T>(
        url,
        body,
        contentType: contentType,
        headers: headers,
        query: query,
        decoder: decoder,
        uploadProgress: uploadProgress,
      ),
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String url,
    dynamic body, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    return _trace(
      'PATCH',
      url,
      () => super.patch<T>(
        url,
        body,
        contentType: contentType,
        headers: headers,
        query: query,
        decoder: decoder,
        uploadProgress: uploadProgress,
      ),
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String url, {
    Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
  }) {
    return _trace(
      'DELETE',
      url,
      () => super.delete<T>(
        url,
        headers: headers,
        contentType: contentType,
        query: query,
        decoder: decoder,
      ),
    );
  }

  @override
  Future<Response<T>> request<T>(
    String url,
    String method, {
    dynamic body,
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    Decoder<T>? decoder,
    Progress? uploadProgress,
  }) {
    return _trace(
      method.toUpperCase(),
      url,
      () => super.request<T>(
        url,
        method,
        body: body,
        contentType: contentType,
        headers: headers,
        query: query,
        decoder: decoder,
        uploadProgress: uploadProgress,
      ),
    );
  }
}
