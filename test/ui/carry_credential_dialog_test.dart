import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/credential_carry.dart';
import 'package:porelo_frontend/src/ui/carry_credential_dialog.dart';

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

const _sources = <CarrySource>[
  VaultEntrySource(name: 'anthropic', type: 'api-key', characters: 51),
  AgentSignInSource(agent: 'claude', agentLabel: 'Claude Code', account: 'someone@example.org'),
  AgentSignInSource(agent: 'pi', agentLabel: 'pi', whyNot: 'pi is not signed in on this computer.'),
];

Future<List<String>> _open(WidgetTester tester, List<CarryOutcome> answers) async {
  final carried = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CarryCredentialDialog(
          provider: _provider,
          hostName: 'host-1',
          sources: () async => _sources,
          carry: (source, {required replace}) async {
            carried.add('${source.id} replace=$replace');
            return answers.removeAt(0);
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return carried;
}

void main() {
  // Harm: one kind of source is missing, or a source that cannot go looks as if it could.
  testWidgets('both kinds stand side by side, and one that cannot go is greyed with its reason', (tester) async {
    await _open(tester, <CarryOutcome>[]);
    expect(find.text("This computer's porelo vault"), findsOneWidget);
    expect(find.text("Local agents' own sign-ins"), findsOneWidget);
    expect(find.text('api-key · 51 characters'), findsOneWidget);
    expect(find.text('agent sign-in · someone@example.org'), findsOneWidget);
    final pi = tester.widget<ListTile>(find.byKey(const Key('carry-source agent pi')));
    expect(pi.enabled, isFalse);
    expect(find.text('pi is not signed in on this computer.'), findsOneWidget);
    // Nothing chosen, nothing to carry.
    expect(tester.widget<FilledButton>(find.byKey(const Key('carry-it'))).onPressed, isNull);
  });

  // Harm: the chosen source is not the one carried, or a kept entry cannot be replaced from the dialog.
  testWidgets('the one picked is carried, and a kept entry is replaced on asking', (tester) async {
    final carried = await _open(tester, <CarryOutcome>[
      const CarryOutcome(stored: false, exists: true, words: 'The host already holds anthropic and kept it.'),
      const CarryOutcome(stored: true, exists: false, words: 'Carried: the host holds it as anthropic.'),
    ]);
    await tester.tap(find.byKey(const Key('carry-source agent claude')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('carry-it')));
    await tester.pumpAndSettle();
    expect(find.text('The host already holds anthropic and kept it.'), findsOneWidget);
    expect(find.text('Replace it on the host'), findsOneWidget);
    await tester.tap(find.byKey(const Key('carry-it')));
    await tester.pumpAndSettle();
    expect(carried, <String>['agent claude replace=false', 'agent claude replace=true']);
    expect(find.text('Carried: the host holds it as anthropic.'), findsOneWidget);
    expect(find.byKey(const Key('carry-it')), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  // Harm: a failing call leaves the dialog silent, so nobody knows whether it went.
  testWidgets('a failing carry says so in the dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarryCredentialDialog(
            provider: _provider,
            hostName: 'host-1',
            sources: () async => _sources,
            carry: (source, {required replace}) async => throw StateError('lost contact'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('carry-source vault anthropic')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('carry-it')));
    await tester.pumpAndSettle();
    expect(find.textContaining('It could not be carried'), findsOneWidget);
  });
}
