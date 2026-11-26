import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jig_fixture/controllers.dart';
import 'package:jig_fixture/pages/form_page.dart';
import 'package:jig_flutter/jig_flutter.dart';
import 'package:jig_protocol/jig_protocol.dart';

import 'support/jig_harness.dart';

void main() {
  setUp(() {
    JigNavHistory.clear();
    Get.reset();
    // The form page reads its rating from a controller, so a page mounted here needs
    // one; this test only cares about pixels.
    Get.put(FormController());
  });

  testWidgets('a screenshot is a PNG of the frame, not an empty canvas', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      // A capture finishes on the raster thread, so this one needs the engine's
      // event loop as well as pumped frames.
      final shot = await driveAsync(tester, JigActions.screenshot());
      final bytes = base64Decode(shot['base64']! as String);

      expect(shot['format'], 'png');
      expect(bytes.take(8).toList(), <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ]);
      expect(shot['width'], greaterThan(0));
      expect(shot['height'], greaterThan(0));

      // Size alone proves nothing: a blank canvas also encodes to a few kilobytes.
      // What separates a capture from a blank one is that a rendered page has more
      // than one colour in it.
      final colours = await tester.runAsync(() => _colours(bytes));
      expect(colours, greaterThan(1));
    });
  });

  testWidgets('pixelRatio scales the image the app reports', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      final single = await driveAsync(tester, JigActions.screenshot());
      final doubled = await driveAsync(
        tester,
        JigActions.screenshot(pixelRatio: 2),
      );

      expect(doubled['width'], (single['width']! as int) * 2);
      expect(doubled['height'], (single['height']! as int) * 2);
      expect(doubled['pixelRatio'], 2);
    });
  });

  testWidgets('a capture is refused when the scale is not a positive number', (
    WidgetTester tester,
  ) async {
    await withPage(tester, const FormPage(), () async {
      final error = await driveFailure(
        tester,
        JigActions.screenshot(pixelRatio: 0),
      );
      expect(error?.code, JigErrorCode.invalidArgument);
    });
  });
}

/// How many distinct colours the image holds, sampled on a coarse grid.
Future<int> _colours(List<int> png) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = rgba!.buffer.asUint8List();
    final seen = <int>{};
    for (var y = 0; y < image.height; y += 8) {
      for (var x = 0; x < image.width; x += 8) {
        final offset = (y * image.width + x) * 4;
        seen.add(
          pixels[offset] << 24 |
              pixels[offset + 1] << 16 |
              pixels[offset + 2] << 8 |
              pixels[offset + 3],
        );
      }
    }
    return seen.length;
  } finally {
    image.dispose();
  }
}
