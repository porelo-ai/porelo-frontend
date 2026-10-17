import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the work reads as {'schema migration, second attempt'}
Future<void> theWorkReadsAs(WidgetTester tester, String caption) async {
  final reads = tester.widgetList<SelectableText>(find.byKey(const Key('tile-what'))).map((text) => text.data);
  expect(reads, contains(caption));
}
