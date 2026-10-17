import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart';

/// Usage: its tile shows what its agent wrote
///
/// Read through the machine's `Tail` from the end, as the stub's formatter shows it.
Future<void> itsTileShowsWhatItsAgentWrote(WidgetTester tester) async {
  await toThePlace(tester, 'work');
  final console = find.byKey(const ValueKey<String>('tile-console $refusedTask'));
  await pumpUntil(
    tester,
    () => console.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the console on the tile of $refusedTask',
  );
  final written = find.descendant(of: console, matching: find.byType(RichText));
  await pumpUntil(
    tester,
    () =>
        written.evaluate().isNotEmpty &&
        find.descendant(of: console, matching: find.text('Nothing written yet.')).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
    what: 'a line its agent wrote on the tile of $refusedTask',
  );
}
