import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A real HTTP server living inside the app.
///
/// It runs on loopback so the fixture exercises the actual `GetConnect` path -
/// modifiers, authenticator retries, timeouts - without needing a backend the
/// reader has to start. Timings are chosen to be visibly wrong when a harness
/// lies about them: `/slow` outlives the client timeout, so a transport failure
/// that never reaches a response modifier is unavoidable.
final class FakeBackend {
  FakeBackend._(this._server) {
    _serve();
  }

  final HttpServer _server;

  String get base => 'http://127.0.0.1:${_server.port}';

  static Future<FakeBackend> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeBackend._(server);
  }

  Future<void> stop() => _server.close(force: true);

  void _serve() {
    unawaited(
      _server.listen((HttpRequest request) async {
        final response = request.response;
        response.headers.contentType = ContentType.json;
        try {
          await _route(request, response);
        } catch (error) {
          response.statusCode = 500;
          response.write(jsonEncode(<String, Object?>{'error': '$error'}));
        } finally {
          await response.close();
        }
      }).asFuture<void>(),
    );
  }

  Future<void> _route(HttpRequest request, HttpResponse response) async {
    switch (request.uri.path) {
      case '/login':
        response.write(jsonEncode(<String, Object?>{'token': 'good'}));
      case '/items':
        response.write(
          jsonEncode(<String, Object?>{
            'items': <Object?>[
              for (var index = 0; index < 5; index++)
                <String, Object?>{'id': index, 'name': 'Item $index'},
            ],
          }),
        );
      case '/secure':
        final authorization = request.headers.value('authorization');
        if (authorization == 'Bearer good') {
          response.write(jsonEncode(<String, Object?>{'ok': true}));
        } else {
          response.statusCode = 401;
          response.write(jsonEncode(<String, Object?>{'error': 'unauthorized'}));
        }
      case '/slow':
        // Longer than ApiController's timeout, so the client must fail.
        await Future<void>.delayed(const Duration(seconds: 3));
        response.write(jsonEncode(<String, Object?>{'ok': true}));
      default:
        response.statusCode = 404;
        response.write(jsonEncode(<String, Object?>{'error': 'not found'}));
    }
  }
}
