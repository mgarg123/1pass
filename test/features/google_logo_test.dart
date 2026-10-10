import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_pass/features/auth/ui/widgets/google_logo.dart';

void main() {
  testWidgets('GoogleLogo widget renders without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: GoogleLogo(size: 24),
          ),
        ),
      ),
    );

    expect(find.byType(GoogleLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
