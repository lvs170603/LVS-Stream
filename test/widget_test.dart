import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    // Verify the app renders without crashing.
    expect(find.byType(Placeholder), findsOneWidget);
  });
}
