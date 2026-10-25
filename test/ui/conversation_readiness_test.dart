import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/conversation.dart';
import 'package:porelo_frontend/src/app/homeserver_forwards.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/messages_view.dart';

import '../features/support/world.dart';

class _Backend extends FakeBackend {
  _Backend() : super([]);

  bool refuses = false;
  int joinsAsked = 0;

  @override
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) async {
    joinsAsked++;
    if (refuses) {
      throw const VarlinkException('org.fuin.porelo.Tasks1.ConversationRefused', {'message': 'room refused'});
    }
    membersOf[project] = [MessageMember(person: person, user: '@$person:localhost')];
    return const MessagesJoined(
      transport: 'matrix',
      shown: '',
      login: {
        'homeserver': 'http://127.0.0.1:8008',
        'user': '@anna:localhost',
        'password': 'invented-once',
        'loopback': 'true',
        'port': '8008',
      },
    );
  }
}

class _Forward implements HeldForward {
  @override
  Future<void> close() async {}
}

void main() {
  // Forwarding the daemon socket separately does not make the named SSH destination local.
  const machine = Machine(name: 'host', socketPath: '/unused', host: 'porelo@host');
  final project = Project.from({'name': 'demo'});

  for (final failure in ['join', 'forward']) {
    // Harm: claiming a refused or unreachable room is ready loses messages sent to it.
    testWidgets('a refused $failure stays a refusal in Messages and never reads as joined', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = _Backend()..refuses = failure == 'join';
      var raises = 0;
      final forwards = HomeserverForwards(
        Settings(MemorySettingsStore()),
        raise: (_, _) async {
          raises++;
          throw const ForwardRefused('forward refused');
        },
      );
      addTearDown(forwards.dispose);
      final model = ProjectConversation(
        backend,
        machine,
        project,
        settings: Settings(MemorySettingsStore()),
        forwards: forwards,
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(MaterialApp(home: MessagesDialog(conversation: model)));
      await tester.enterText(find.byKey(const Key('join-person')), 'anna');
      await tester.pump();
      await tester.tap(find.byKey(const Key('join-it')));
      await World.settle(tester);
      expect(
        backend.joinsAsked,
        1,
        reason: 'the enabled join action must reach the daemon before checking its refusal',
      );
      expect(model.joined, isNull);
      expect(find.byKey(const Key('messages-problem')), findsOneWidget);
      expect(find.byKey(const Key('login user')), findsNothing);
      expect(raises, failure == 'join' ? 0 : 1);
    });
  }

  // Harm: a pending forward must not advertise a room as ready before it answers.
  test('a joined account becomes ready only after its forward answers', () async {
    final backend = _Backend();
    final raising = Completer<HeldForward>();
    final askedToForward = Completer<void>();
    final forwards = HomeserverForwards(
      Settings(MemorySettingsStore()),
      raise: (_, _) {
        askedToForward.complete();
        return raising.future;
      },
    );
    addTearDown(forwards.dispose);
    final model = ProjectConversation(
      backend,
      machine,
      project,
      settings: Settings(MemorySettingsStore()),
      forwards: forwards,
    );
    addTearDown(model.dispose);
    final joining = model.join('anna');
    await pumpEventQueue(times: 10);
    expect(
      askedToForward.isCompleted,
      isTrue,
      reason: 'a remote homeserver must be forwarded even without a daemon tunnel',
    );
    expect(model.joined, isNull);
    raising.complete(_Forward());
    await joining;
    expect(model.joined?.login['user'], '@anna:localhost');
    expect(model.forwarded, 8008);
  });

  // Harm: retrying a failed forward must not lose the only password by creating the account twice.
  test('a failed forward can be retried without another daemon join', () async {
    final backend = _Backend();
    var refuses = true;
    final forwards = HomeserverForwards(
      Settings(MemorySettingsStore()),
      raise: (_, _) async {
        if (refuses) throw const ForwardRefused('forward refused');
        return _Forward();
      },
    );
    addTearDown(forwards.dispose);
    final model = ProjectConversation(
      backend,
      machine,
      project,
      settings: Settings(MemorySettingsStore()),
      forwards: forwards,
    );
    addTearDown(model.dispose);
    await model.join('anna');
    expect(model.joined, isNull);
    refuses = false;
    await model.join('anna');
    expect(model.joined?.login['password'], 'invented-once');
    expect(backend.joinsAsked, 1);
  });

  // Harm: a lost forward must stop advertising a room as reachable while its dialog stays open.
  test('a forward that fails after joining withdraws readiness until it is restored', () async {
    final backend = _Backend();
    var refuses = false;
    final forwards = HomeserverForwards(
      Settings(MemorySettingsStore()),
      raise: (_, _) async {
        if (refuses) throw const ForwardRefused('forward refused');
        return _Forward();
      },
      answers: (_) async => false,
    );
    addTearDown(forwards.dispose);
    final model = ProjectConversation(
      backend,
      machine,
      project,
      settings: Settings(MemorySettingsStore()),
      forwards: forwards,
    );
    addTearDown(model.dispose);
    await model.join('anna');
    expect(model.joined, isNotNull);
    refuses = true;
    await forwards.retry(machine, project.name);
    expect(model.joined, isNull);
    expect(model.problem, contains('forward refused'));
    refuses = false;
    await forwards.retry(machine, project.name);
    expect(model.joined?.login['user'], '@anna:localhost');
    expect(model.problem, isNull);
    expect(backend.joinsAsked, 1);
  });
}
