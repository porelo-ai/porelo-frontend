import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/terminal_copy.dart';
import 'package:xterm/xterm.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: the terminal shows the provider's link
Future<void> theTerminalShowsTheProvidersLink(WidgetTester tester) => pictured(tester, () async {
  if (Rehearsal.notRun != null) return;
  final view = find.byKey(const Key('unlock-terminal'));
  String shown() {
    if (view.evaluate().isEmpty) return '';
    final term = tester.widget<TerminalView>(view.first).terminal;
    return copiedText(term, BufferRangeLine(CellOffset(0, 0), CellOffset(term.viewWidth - 1, term.buffer.height - 1)));
  }

  // The first sign-in builds its image on the host first, which takes minutes and prints little.
  await pumpUntil(
    tester,
    () => RegExp(r'https://\S+').hasMatch(shown()),
    timeout: const Duration(minutes: 15),
    what: "the provider's link in the terminal",
  );
});
