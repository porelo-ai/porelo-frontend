import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/placing_project_dialog.dart';

import '../support/organization_fixtures.dart';

/// Putting a project on a machine leads through its token, and follows until it is carried.
void main() {
  const waiting = HostProgress(
    projects: [HostProjectProgress(project: 'demo', state: 'waiting-for-token')],
  );
  const carried = HostProgress(
    projects: [HostProjectProgress(project: 'demo', state: 'carried')],
  );

  Future<void> open(
    WidgetTester tester,
    FixtureConnections connections, {
    Future<String?> Function(String host)? onGiveToken,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacingProjectDialog(
            project: 'demo',
            host: 'build',
            view: null,
            connections: connections,
            onGiveToken: onGiveToken,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  String words(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('placing-project.words'))).data!;

  // Harm: the token waits on another page, which the person does not know to look for.
  testWidgets('a machine waiting for the token offers it here, and follows to carried', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = waiting;
    final gave = <String>[];
    await open(
      tester,
      connections,
      onGiveToken: (host) async {
        gave.add(host);
        connections.hostProgress = carried;
        return null;
      },
    );
    await tester.tap(find.byKey(const Key('placing-project.giveToken')));
    await tester.pump();
    await tester.pump();
    expect(gave, <String>['build']);
    expect(words(tester), 'build carries demo.');
    expect(find.byKey(const Key('placing-project.giveToken')), findsNothing);
    await close(tester);
  });

  // Harm: a token not given leaves a person with nothing, as the foo test's button did.
  testWidgets('a token not given says why, in the same dialog', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = waiting;
    await open(tester, connections, onGiveToken: (_) async => 'No GitHub token is kept.');
    await tester.tap(find.byKey(const Key('placing-project.giveToken')));
    await tester.pump();
    await tester.pump();
    expect(find.text('No GitHub token is kept.'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a machine not connected is connected first', (tester) async {
    final connections = FixtureConnections()..hostProgress = carried;
    await open(tester, connections);
    expect(connections.asked, contains('connect build'));
    expect(words(tester), 'build carries demo.');
    await close(tester);
  });

  // Harm: the dialog waits forever on a connection that was refused.
  testWidgets('a refused connection says so and stops', (tester) async {
    final connections = FixtureConnections()..refuseNext = const OrganizationRefused('No card here.');
    await open(tester, connections);
    expect(words(tester), contains('did not connect to build: No card here.'));
    await close(tester);
  });

  testWidgets('a project the machine holds says why', (tester) async {
    final connections = FixtureConnections(['build'])
      ..hostProgress = const HostProgress(
        projects: [HostProjectProgress(project: 'demo', state: 'held', why: 'its repository is gone')],
      );
    await open(tester, connections);
    expect(words(tester), contains('its repository is gone'));
    await close(tester);
  });

  // Harm: the machine goes on by itself for minutes and the dialog must see it arrive.
  testWidgets('it asks again until the machine carries it', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = const HostProgress();
    await open(tester, connections);
    expect(words(tester), contains('within five minutes'));
    connections.hostProgress = carried;
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(words(tester), 'build carries demo.');
    await close(tester);
  });

  // Harm: the machine waits for the organization's token, and the dialog says it takes the project by itself.
  testWidgets('a machine waiting for its first token offers it, whatever the project says', (tester) async {
    final connections = FixtureConnections(['build'])
      ..hostProgress = const HostProgress(
        waitsForToken: true,
        projects: [HostProjectProgress(project: 'demo', state: 'pending')],
      );
    await open(tester, connections, onGiveToken: (_) async => null);
    expect(find.byKey(const Key('placing-project.giveToken')), findsOneWidget);
    await close(tester);
  });

  // Harm: a person waits five minutes for a project that cannot come until its admin opens it.
  testWidgets('a project with no address says so, and stops following', (tester) async {
    final connections = FixtureConnections(['build'])
      ..hostProgress = const HostProgress(
        projects: [HostProjectProgress(project: 'demo', state: 'waiting-for-token', hasNoAddress: true)],
      );
    await open(tester, connections, onGiveToken: (_) async => null);
    expect(words(tester), contains('no address yet'));
    expect(find.byKey(const Key('placing-project.giveToken')), findsNothing);
    await close(tester);
  });

  testWidgets('a fetch the machine refused is said', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(refused: 'git fetch failed');
    await open(tester, connections);
    expect(words(tester), contains('git fetch failed'));
    await close(tester);
  });

  // Harm: a machine's account appears after the first token, and the person is left unconnected.
  testWidgets('after the first token the connection is raised', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
    await open(
      tester,
      connections,
      onGiveToken: (_) async {
        connections.hostProgress = carried;
        return null;
      },
    );
    await tester.tap(find.byKey(const Key('placing-project.giveToken')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(connections.asked, contains('connect build'));
    await close(tester);
  });

  // Harm: each refused login counts against this address, and a dialog left open keeps the machine shut.
  testWidgets('a machine that refuses is asked less and less often', (tester) async {
    final connections = _RefusingProgress(['build']);
    await open(tester, connections);
    for (var tick = 0; tick < 11; tick++) {
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
    }
    expect(connections.asks, 4, reason: 'at ticks 1, 3, 6 and 11');
    await close(tester);
  });

  // Harm: a press whose giving throws leaves the button dead and the dialog following nothing.
  testWidgets('a giving that throws does not leave the button dead', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = waiting;
    await open(tester, connections, onGiveToken: (_) async => throw const OrganizationRefused('no'));
    await tester.tap(find.byKey(const Key('placing-project.giveToken')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('placing-project.tokenWhy')), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('placing-project.giveToken')));
    expect(button.onPressed, isNotNull);
    await close(tester);
  });
}

class _RefusingProgress extends FixtureConnections {
  _RefusingProgress(super.hosts);

  int asks = 0;

  @override
  Future<HostProgress> progress(String host) async {
    asks++;
    throw const OrganizationRefused('Connection closed by 203.0.113.9 port 22');
  }
}
