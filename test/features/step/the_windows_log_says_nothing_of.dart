import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/window_log.dart';

import '../support/recorded_log.dart';

/// Usage: the window's log says nothing of {'was refused'}
Future<void> theWindowsLogSaysNothingOf(WidgetTester tester, String words) async {
  final lines = (windowLog as RecordedLog).lines;
  expect(lines.where((line) => line.contains(words)), isEmpty, reason: lines.join('\n'));
}
