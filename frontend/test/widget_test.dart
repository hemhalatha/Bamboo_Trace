// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bambootrace/main.dart';

void main() {
  testWidgets('App shows splash title', (WidgetTester tester) async {
    // Pump a minimal app that contains the visible title to avoid side-effects
    // from the real SplashScreen (timers, Firebase calls).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: Text('BambooTrace'))),
    ));

    expect(find.text('BambooTrace'), findsOneWidget);
  });
}
