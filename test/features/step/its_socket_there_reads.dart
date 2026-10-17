import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: its socket there reads {'/run/user/1001/porelo/porelod.sock'}
Future<void> itsSocketThereReads(WidgetTester tester, String socket) async {
  final field = tester.widget<TextField>(find.byKey(const Key('machine-remote-socket')));
  expect(field.controller!.text, socket);
}
