import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/conversation.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/messages_view.dart';

import '../features/support/world.dart';

class _Backend extends FakeBackend {
  _Backend() : super([]);

  final accounts = <MessageMember>[];
  final requests = <({String project, String person, bool reset})>[];
  Completer<List<MessageMember>>? listing;
  bool refusesJoin = false;

  @override
  Future<List<MessageMember>> messageMembers(String project) async =>
      listing?.future ?? List<MessageMember>.of(accounts);

  @override
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) async {
    requests.add((project: project, person: person, reset: reset));
    if (refusesJoin) throw const VarlinkException('org.fuin.porelo.Tasks1.ConversationRefused', {});
    if (!accounts.any((each) => each.person == person)) {
      accounts.add(MessageMember(person: person, user: '@$person:room'));
    }
    return MessagesJoined(
      transport: 'matrix',
      shown: '',
      login: {'user': '@$person:room', 'password': 'test-only-${requests.length}'},
    );
  }
}

void main() {
  const machine = Machine(name: 'local', socketPath: '/unused');
  final project = Project.from({'name': 'demo'});

  // Harm: sharing an identity between machines can reset someone else's account in another room.
  test('a remembered room identity belongs only to its machine and project', () async {
    const machineA = Machine(name: 'node-a', socketPath: '/first');
    const machineB = Machine(name: 'node-b', socketPath: '/second');
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    final onA = ProjectConversation(_Backend(), machineA, project, settings: settings);
    addTearDown(onA.dispose);
    await onA.join('anna');
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    final backendB = _Backend()..accounts.add(const MessageMember(person: 'anna', user: '@anna:another-room'));
    final onB = ProjectConversation(backendB, machineB, project, settings: reopened);
    addTearDown(onB.dispose);
    await onB.load();
    expect(onB.members?.single.person, 'anna', reason: 'the other room must contain the same name to expose aliasing');
    expect(onB.joinedAs, isNull, reason: 'joining on one machine must not claim an account on another');
    await onB.newPassword();
    expect(backendB.requests, isEmpty, reason: 'the other room must never receive a reset using this saved identity');
    final backendA = _Backend()..accounts.add(const MessageMember(person: 'anna', user: '@anna:room'));
    final backOnA = ProjectConversation(backendA, machineA.withSocketPath('/reconnected'), project, settings: reopened);
    addTearDown(backOnA.dispose);
    await backOnA.load();
    expect(backOnA.joinedAs?.person, 'anna', reason: 'the stable machine name must survive a socket change');
  });

  // Harm: New password without reset or with a different person invalidates the wrong login or fails.
  testWidgets('reopening resets only the remembered account in its project', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend()..accounts.add(const MessageMember(person: 'bea', user: '@bea:room'));
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    final first = ProjectConversation(backend, machine, project, settings: settings);
    await first.join('anna');
    first.dispose();
    final reopenedSettings = Settings(store);
    addTearDown(reopenedSettings.dispose);
    await reopenedSettings.load();
    final reopened = ProjectConversation(backend, machine, project, settings: reopenedSettings);
    addTearDown(reopened.dispose);
    await reopened.load();
    await tester.pumpWidget(MaterialApp(home: MessagesDialog(conversation: reopened)));
    await tester.tap(find.byKey(const Key('join-reset')));
    await World.settle(tester);
    expect(backend.requests, [
      (project: 'demo', person: 'anna', reset: false),
      (project: 'demo', person: 'anna', reset: true),
    ], reason: 'the reset action must target the saved person rather than the first room member');
    expect(reopened.joined?.login['user'], '@anna:room', reason: 'the daemon answer must belong to that account');
    final password = tester.widget<SelectableText>(find.byKey(const Key('login password'))).data;
    expect(
      password == reopened.joined?.login['password'] && password != null,
      isTrue,
      reason: 'the newly answered password must be shown without putting its value in test output',
    );
    expect((await store.read())['messagePeople'], {
      'local': {'demo': 'anna'},
    }, reason: 'only the scoped person name belongs in settings');
  });

  // Harm: guessing membership before a reply can target a password reset at an account never joined.
  test('joining waits for the member answer before remembering an account', () async {
    final backend = _Backend()..listing = Completer<List<MessageMember>>();
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    final model = ProjectConversation(backend, machine, project, settings: settings);
    addTearDown(model.dispose);
    final joining = model.join('anna');
    await pumpEventQueue();
    expect(backend.requests, [(project: 'demo', person: 'anna', reset: false)], reason: 'the daemon join must run');
    expect(model.joinedAs, isNull, reason: 'a pending list must not invent membership');
    expect(settings.messagePerson('local', 'demo'), isNull, reason: 'a pending list must not persist membership');
    backend.listing!.complete([const MessageMember(person: 'bea', user: '@bea:room')]);
    await joining;
    expect(model.members?.map((each) => each.person), ['bea'], reason: 'only the returned list is authoritative');
    expect(model.joinedAs, isNull, reason: 'a successful join cannot override an absent member');
    expect(settings.messagePerson('local', 'demo'), isNull, reason: 'an absent member must not be kept');
  });

  // Harm: a stale identity blocks joining again and can reset a removed account instead.
  test('only a successful member list clears a vanished account across reopening', () async {
    final backend = _Backend()..accounts.add(const MessageMember(person: 'anna', user: '@anna:room'));
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.rememberMessagePerson('local', 'demo', 'anna');
    final model = ProjectConversation(backend, machine, project, settings: settings);
    addTearDown(model.dispose);
    await model.load();
    await model.newPassword();
    backend.listing = Completer<List<MessageMember>>();
    final failedLoad = model.load();
    backend.listing!.completeError(const VarlinkDisconnected('gone'));
    await failedLoad;
    expect(model.joinedAs?.person, 'anna', reason: 'a lost connection must keep the last member answer');
    expect(settings.messagePerson('local', 'demo'), 'anna', reason: 'failure is not an empty list');
    backend.listing = null;
    backend.accounts.clear();
    await model.load();
    expect(model.joinedAs, isNull, reason: 'the returned empty list revokes the remembered membership');
    expect(model.joined, isNull, reason: 'a removed account must not keep offering its obsolete login');
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(
      reopened.messagePerson('local', 'demo'),
      isNull,
      reason: 'the vanished member must stay forgotten after restart',
    );
  });

  // Harm: a refused join must not overwrite the saved account used by a later password reset.
  test('a refused join preserves the confirmed account', () async {
    final backend = _Backend()
      ..accounts.add(const MessageMember(person: 'anna', user: '@anna:room'))
      ..refusesJoin = true;
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.rememberMessagePerson('local', 'demo', 'anna');
    final model = ProjectConversation(backend, machine, project, settings: settings);
    addTearDown(model.dispose);
    await model.load();
    await model.join('bea');
    expect(model.problem, isNotNull, reason: 'the refusal must remain visible');
    expect(model.joined, isNull, reason: 'a refusal must not publish a login');
    expect(model.joinedAs?.person, 'anna', reason: 'the last confirmed account remains the current identity');
    expect(settings.messagePerson('local', 'demo'), 'anna', reason: 'a refused account must not be persisted');
  });
}
