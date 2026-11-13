import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/window_log.dart';

import '../support/recorded_log.dart';

/// Usage: the window's log is kept
Future<void> theWindowsLogIsKept(WidgetTester tester) async {
  final before = windowLog;
  windowLog = RecordedLog();
  addTearDown(() => windowLog = before);
}
