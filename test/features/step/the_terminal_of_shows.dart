import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the terminal of {'porelo-billing-shell'} shows {'agent> make test'}
///
/// What the machine's `Screen` answers for the work's session, from now on.
Future<void> theTerminalOfShows(WidgetTester tester, String work, String line) async {
  // As Claude Code's screen looks: more lines than the tile shows, box drawing, an emoji, the prompt.
  World.backend.screens[work] = Screen(
    lines: <String>[
      '─' * 120,
      '📁 /workspace  ✻ Welcome',
      'earlier',
      '❯ ',
      '⏵⏵ bypass permissions on (shift+tab to cycle)',
      '─' * 120,
      line,
    ],
    live: true,
  );
}
