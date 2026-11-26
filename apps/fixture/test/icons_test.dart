import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixture draws eleven `Icons.*`, and a missing font asset turns every one of
/// them into a tofu box that no analyzer, no semantics node and no other test sees.
///
/// `uses-material-design: true` is what puts `MaterialIcons-Regular.otf` in the
/// bundle. Widget tests read the same asset bundle the app is built with, so the
/// absence is observable here instead of only on a screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Material icons font is bundled', () async {
    final font = await rootBundle.load('fonts/MaterialIcons-Regular.otf');

    expect(font.lengthInBytes, greaterThan(1000));
  });
}
