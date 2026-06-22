import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Material app smoke test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Pin Genie')),
      ),
    );

    expect(find.text('Pin Genie'), findsOneWidget);
  });
}
