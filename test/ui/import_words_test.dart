import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/authentication.dart';
import 'package:porelo_frontend/src/ui/authentication_view.dart';

const _provider = Provider(
  name: 'anthropic',
  label: 'Anthropic',
  upstream: 'api.anthropic.com',
  dialects: <String>[],
  authenticated: false,
  credentialType: 'api-key',
  credentialName: 'anthropic',
  storeCommand: '',
);

Future<void> _show(
  WidgetTester tester,
  Authentication model,
  ImportReads reads, {
  void Function(Provider provider)? onCarry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AuthenticationView(authentication: model, onImport: (_) {}, reads: reads, onCarry: onCarry),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Anthropic'));
  await tester.pumpAndSettle();
}

void main() {
  // Harm: the button says "there" and a person takes it for this computer, or the host's words stand on a WSL page.
  for (final (reads, words) in <(ImportReads, String)>[
    (ImportReads.host, 'Import what the agent already has on the host'),
    (ImportReads.wsl, 'Import what the agent already has in WSL'),
    (ImportReads.thisComputer, 'Import what the agent already has on this computer'),
  ]) {
    testWidgets('the import button says where it reads: ${reads.name}', (tester) async {
      final model = Authentication()..answer = const Providers(providers: <Provider>[_provider], readable: true);
      await _show(tester, model, reads);
      expect(find.text(words), findsOneWidget);
    });
  }

  // Harm: a host's provider row offers no way to bring this computer's credential, or this computer's own page
  // offers carrying to itself.
  testWidgets("a host's provider row offers importing from this computer", (tester) async {
    final carried = <String>[];
    final model = Authentication()..answer = const Providers(providers: <Provider>[_provider], readable: true);
    await _show(tester, model, ImportReads.host, onCarry: (provider) => carried.add(provider.name));
    await tester.tap(find.text('Import from this computer…'));
    expect(carried, <String>['anthropic']);

    await tester.pumpWidget(const SizedBox());
    await _show(tester, model, ImportReads.thisComputer);
    expect(find.text('Import what the agent already has on this computer'), findsOneWidget, reason: 'the row is open');
    expect(find.text('Import from this computer…'), findsNothing);
  });
}
