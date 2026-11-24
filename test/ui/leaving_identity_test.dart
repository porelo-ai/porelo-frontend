import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/leaving.dart';

void main() {
  // Harm: the window seems stuck while it waits for a keeping, or the person closes it thinking nothing runs.
  testWidgets('a keeping of a server identity is named, and leaving waits for it', (tester) async {
    bool? closes;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => closes = await confirmQuit(
              context,
              running: const [],
              waiting: 0,
              keepingIdentities: const ['orchard'],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The identity of orchard is being kept in your Porelo-Vault: closing waits for it, at most 45 seconds.',
      ),
      findsOneWidget,
    );
    expect(find.text('Nothing is running. Closing this changes nothing on any machine.'), findsNothing);
    await tester.tap(find.text('Close it'));
    await tester.pumpAndSettle();
    expect(closes, isTrue, reason: 'the window closes once the keeping ended, which HostRuns.leave waits for');
  });
}
