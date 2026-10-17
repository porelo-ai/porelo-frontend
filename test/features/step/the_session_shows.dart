import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the session shows {'root@porelo-billing-shell:/work#'}
///
/// Read off the terminal's own buffer rather than found among widgets: a terminal is painted, not
/// laid out as text, so there is no `Text` to look for. The buffer is what the painter draws.
Future<void> theSessionShows(WidgetTester tester, String words) async {
  final session = World.sessions.current!;
  expect(session.terminal.buffer.toString(), contains(words));
}
