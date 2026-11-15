import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/declared_hand_on.dart';
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

  Future<void> open(WidgetTester tester, FixtureConnections connections, {GiveHostToken? onGiveToken}) async {
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
      onGiveToken: (host, {atOnce = false}) async {
        gave.add(atOnce ? '$host at once' : host);
        connections.hostProgress = carried;
        return null;
      },
    );
    await tester.tap(find.byKey(const Key('placing-project.giveToken')));
    await tester.pump();
    await tester.pump();
    expect(gave, <String>['build at once'], reason: 'the second ask is one press where the vault declares it');
    expect(words(tester), 'build carries demo.');
    expect(find.byKey(const Key('placing-project.giveToken')), findsNothing);
    await close(tester);
  });

  // Harm: a person whose Porelo-Vault declares the token is asked for it again for every project put on the host.
  testWidgets('a machine waiting for the token is handed the declared one without a press, and says so', (
    tester,
  ) async {
    final connections = FixtureConnections(['build'])..hostProgress = waiting;
    final handedOn = <String>[];
    final release = Completer<void>();
    connections.handOnDeclared = (host, projects) async {
      handedOn.add('$host ${projects.join(',')}');
      await release.future;
      connections.hostProgress = carried;
      return const HandOn(HandOnOutcome.handedOn);
    };
    final pressed = <String>[];
    await open(
      tester,
      connections,
      onGiveToken: (host, {atOnce = false}) async {
        pressed.add(host);
        return null;
      },
    );
    expect(handedOn, ['build demo'], reason: 'handed on as soon as the project was heard waiting');
    expect(words(tester), contains('Handing on the token your Porelo-Vault declares'));
    expect(find.byKey(const Key('placing-project.giveToken')), findsNothing, reason: 'no button while it runs');
    release.complete();
    await tester.pump();
    await tester.pump();
    expect(words(tester), 'build carries demo.');
    expect(pressed, isEmpty);
    await close(tester);
  });

  // Harm: with nothing declared, or a declared token that did not help, the person is left without the button.
  testWidgets('a declared token not found, or not helping, leaves the button as before', (tester) async {
    for (final outcome in [HandOnOutcome.notDeclared, HandOnOutcome.notRun, HandOnOutcome.handedOn]) {
      final connections = FixtureConnections(['build'])..hostProgress = waiting;
      connections.handOnDeclared = (host, projects) async => HandOn(outcome);
      await open(tester, connections);
      expect(find.byKey(const Key('placing-project.giveToken')), findsNothing, reason: 'no give without a hook');
      await close(tester);
      await open(tester, connections, onGiveToken: (_, {atOnce = false}) async => null);
      expect(find.byKey(const Key('placing-project.giveToken')), findsOneWidget, reason: '$outcome');
      if (outcome == HandOnOutcome.handedOn) {
        expect(find.textContaining('still waits for a token after the one your Porelo-Vault declares'), findsOneWidget);
      }
      await close(tester);
    }
  });

  // Harm: the window's own hand-over already ran and did not help, so the dialog shows a bare button, without saying
  // that the declared token was handed on and the machine still waits.
  testWidgets('a declared token the window already handed on says it did not help', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = waiting;
    final given = <String>[];
    final handOn = DeclaredHandOn((host) async {
      given.add(host);
      return const HandOn(HandOnOutcome.handedOn);
    });
    addTearDown(handOn.dispose);
    // The window heard the wait first and handed the token on; the machine still says demo waits.
    await handOn.forWaits('build', {'demo'});
    connections.handOnDeclared = handOn.forWaits;
    await open(tester, connections, onGiveToken: (_, {atOnce = false}) async => null);
    expect(given, ['build'], reason: 'not handed on again for the same wait');
    expect(find.textContaining('still waits for a token after the one your Porelo-Vault declares'), findsOneWidget);
    expect(find.byKey(const Key('placing-project.giveToken')), findsOneWidget);
    await close(tester);
  });

  // Harm: a token not given leaves a person with nothing, as the foo test's button did.
  testWidgets('a token not given says why, in the same dialog', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = waiting;
    await open(tester, connections, onGiveToken: (_, {atOnce = false}) async => 'No GitHub token is kept.');
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
    await open(tester, connections, onGiveToken: (_, {atOnce = false}) async => null);
    expect(find.byKey(const Key('placing-project.giveToken')), findsOneWidget);
    await close(tester);
  });

  // Harm: a person waits five minutes for a project that cannot come until its admin opens it.
  testWidgets('a project with no address says so, and stops following', (tester) async {
    final connections = FixtureConnections(['build'])
      ..hostProgress = const HostProgress(
        projects: [HostProjectProgress(project: 'demo', state: 'waiting-for-token', hasNoAddress: true)],
      );
    await open(tester, connections, onGiveToken: (_, {atOnce = false}) async => null);
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
      onGiveToken: (_, {atOnce = false}) async {
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

  // Harm: the button turns active again for a moment before the machine is said to carry the project, so the person
  // hands the token over a second time, or closes the dialog before it is done.
  testWidgets('giving the token cannot be pressed again until the machine is said to carry the project', (
    tester,
  ) async {
    final connections = _HeldRefresh(['build'])..hostProgress = waiting;
    final given = Completer<String?>();
    await open(tester, connections, onGiveToken: (_, {atOnce = false}) => given.future);
    connections.holding = true;
    final button = find.byKey(const Key('placing-project.giveToken'));
    await tester.tap(button);
    await tester.pump();
    void runs(String when) {
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull, reason: 'it cannot be pressed again $when');
    }

    runs('while the token is given');
    connections.hostProgress = carried;
    given.complete(null);
    await tester.pump();
    await tester.pump();
    runs('while the machine is asked whether it took it');
    connections.held.complete();
    await tester.pump();
    await tester.pump();
    expect(button, findsNothing, reason: 'the button does not come back');
    expect(find.byKey(const Key('placing-project.done')), findsOneWidget, reason: 'it says it is done');
    await close(tester);
  });

  // Harm: the machine does not answer after the token was handed over, and the dialog says only that it has the token.
  testWidgets('a machine that does not answer after the hand-over is said', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = waiting;
    await open(
      tester,
      connections,
      onGiveToken: (_, {atOnce = false}) async {
        connections.refuseNext = const OrganizationRefused('Connection closed by 203.0.113.9 port 22');
        return null;
      },
    );
    await tester.tap(find.byKey(const Key('placing-project.giveToken')));
    await tester.pump();
    await tester.pump();
    expect(words(tester), contains('Connection closed by 203.0.113.9 port 22'));
    await close(tester);
  });

  // Harm: the token given does not let the machine read, and the button never comes back to give a working one.
  testWidgets('a machine still waiting for a token after the hand-over offers giving it again', (tester) async {
    final connections = FixtureConnections(['build'])..hostProgress = waiting;
    await open(tester, connections, onGiveToken: (_, {atOnce = false}) async => null);
    await tester.tap(find.byKey(const Key('placing-project.giveToken')));
    await tester.pump();
    await tester.pump();
    final button = find.byKey(const Key('placing-project.giveToken'));
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.byKey(const Key('placing-project.tokenWhy')), findsOneWidget);
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
    await open(tester, connections, onGiveToken: (_, {atOnce = false}) async => throw const OrganizationRefused('no'));
    await tester.tap(find.byKey(const Key('placing-project.giveToken')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('placing-project.tokenWhy')), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('placing-project.giveToken')));
    expect(button.onPressed, isNotNull);
    await close(tester);
  });
}

/// Once [holding], answers a refresh only when [held] completes, as a machine does that takes its time.
class _HeldRefresh extends FixtureConnections {
  _HeldRefresh(super.hosts);

  bool holding = false;
  final held = Completer<void>();

  @override
  Future<HostProgress> refresh(String host) async {
    if (holding) await held.future;
    return super.refresh(host);
  }
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
