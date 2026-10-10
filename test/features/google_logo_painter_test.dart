import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_pass/features/auth/ui/widgets/google_logo.dart';

void main() {
  test('GoogleLogoPainter paints red, blue, yellow, and green paths', () async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const painter = GoogleLogoPainter();

    painter.paint(canvas, const Size(48, 48));
    final picture = recorder.endRecording();
    final image = await picture.toImage(48, 48);
    final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);

    expect(byteData, isNotNull);

    // Verify non-zero bytes are drawn (not empty canvas)
    final bytes = byteData!.buffer.asUint8List();
    bool hasRed = false;
    bool hasBlue = false;
    bool hasYellow = false;
    bool hasGreen = false;

    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final a = bytes[i + 3];

      if (a > 200) {
        // Red #EA4335: r~234, g~67, b~53
        if (r > 200 && g < 100 && b < 100) hasRed = true;
        // Blue #4285F4: r~66, g~133, b~244
        if (r < 100 && g > 100 && b > 200) hasBlue = true;
        // Yellow #FBBC05: r~251, g~188, b~5
        if (r > 200 && g > 150 && b < 50) hasYellow = true;
        // Green #34A853: r~52, g~168, b~83
        if (r < 100 && g > 130 && b < 120) hasGreen = true;
      }
    }

    expect(hasRed, isTrue, reason: 'Google logo should contain Red');
    expect(hasBlue, isTrue, reason: 'Google logo should contain Blue');
    expect(hasYellow, isTrue, reason: 'Google logo should contain Yellow');
    expect(hasGreen, isTrue, reason: 'Google logo should contain Green');
  });
}
