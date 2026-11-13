import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/window_log.dart';

import '../support/recorded_log.dart';

/// Usage: the window's log says {'was refused'}
Future<void> theWindowsLogSays(WidgetTester tester, String words) async {
  final lines = (windowLog as RecordedLog).lines;
  expect(lines.where((line) => line.contains(words)), hasLength(1), reason: lines.join('\n'));
}
