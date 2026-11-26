import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';
import 'package:jig_getx/jig_getx.dart';

/// Exercises `JigConnect`: a successful call, a 401 that the authenticator
/// retries, and a timeout that never produces a response at all.
class ApiController extends GetxController {
  ApiController(this._base) {
    http
      ..baseUrl = _base
      ..timeout = const Duration(milliseconds: 900);
    http.httpClient.addAuthenticator<Object?>((request) async {
      request.headers['Authorization'] = 'Bearer good';
      return request;
    });
  }

  final String _base;
  final JigConnect http = JigConnect(maxAuthRetries: 2);

  final RxString lastStatus = 'idle'.obs;

  Future<void> loadItems() => _run('items', () => http.get<Object?>('/items'));

  Future<void> loadSecure() =>
      _run('secure', () => http.get<Object?>('/secure'));

  Future<void> loadSlow() => _run('slow', () => http.get<Object?>('/slow'));

  Future<void> _run(
    String label,
    Future<Response<Object?>> Function() call,
  ) async {
    lastStatus.value = '$label: pending';
    try {
      final response = await call();
      lastStatus.value = '$label: ${response.statusCode}';
    } catch (error) {
      lastStatus.value = '$label: failed';
    }
  }
}

/// The form's range control.
///
/// The rating lives in a controller rather than in the page's State so a reader can
/// answer "what is it at now?" - a slider has no text of its own to assert on, and a
/// scenario that steps it needs somewhere to check the result.
class FormController extends GetxController {
  final RxDouble rating = 3.0.obs;
}

/// Fast-moving state: the list reorders while the caller is trying to tap a row.
class FeedController extends GetxController {
  final Random _random = Random(7);
  final RxList<int> items =
      RxList<int>(List<int>.generate(8, (index) => index));

  final RxBool _shuffling = false.obs;

  /// Reads the observable, so an [Obx] that calls this rebuilds when the
  /// shuffle starts or stops.
  bool get isShuffling => _shuffling.value;

  Timer? _timer;

  void toggleShuffle() {
    if (_timer != null) {
      stopShuffle();
      return;
    }
    _shuffling.value = true;
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      items.shuffle(_random);
    });
  }

  void stopShuffle() {
    _timer?.cancel();
    _timer = null;
    _shuffling.value = false;
  }

  @override
  void onClose() {
    stopShuffle();
    super.onClose();
  }
}

/// Counts pull-to-refresh requests.
///
/// `RefreshIndicator` fires a callback and tells nobody; without a counter the only
/// thing a test could assert is that the gesture did not throw. Registered as
/// `refresh.count` so a harness proves the refresh happened instead of assuming it.
class RefreshController extends GetxController {
  final RxInt count = 0.obs;
}

class CartController extends GetxController {
  final RxInt count = 0.obs;
  final RxDouble total = 0.0.obs;

  void add(double price) {
    count.value += 1;
    total.value += price;
  }

  void clear() {
    count.value = 0;
    total.value = 0;
  }
}

/// Deliberately broken: step two writes step one.
///
/// A harness that reports success without checking state will call this flow
/// green. `Jig.state('buggy.step')` is what lets a scenario prove it is red.
class BuggyController extends GetxController {
  final RxInt step = 0.obs;

  void advance() {
    step.value = 1;
  }

  void confirm() {
    step.value = 1; // Should be 2.
  }

  void reset() => step.value = 0;
}

/// Holds what a dialog returned, so `jig snapshot` can prove the value landed
/// somewhere the widget tree cannot show.
class DialogController extends GetxController {
  final RxString lastResult = 'none'.obs;
}
