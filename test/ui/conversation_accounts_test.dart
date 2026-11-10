import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/conversation.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/messages_view.dart';

import '../features/support/world.dart';

/// A test-only value in an invitation's login that must never be shown.
const _invitedSecret = 'test-only-invited-secret';

class _Backend extends FakeBackend {
  _Backend() : super([]);

  final accounts = <MessageMember>[];
  final requests = <({String project, String person, bool reset})>[];
  Completer<List<MessageMember>>? listing;
  bool refusesJoin = false;

  /// Whether the join invites the person's existing account, as the transport answers for a second room.
  bool invites = false;

  /// The invitation's login in place of the usual one, where a test needs another.
  Map<String, Object?>? invitedLogin;

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
    if (invites) {
      // Decoded as the client decodes the daemon's reply. The password is one a transport should not send with an
      // invitation; it is there so that showing it would be seen.
      return MessagesJoined.from(<String, dynamic>{
        'transport': 'matrix',
        'shown': '',
        'invited': true,
        'login':
            invitedLogin ??
            <String, Object?>{
              'homeserver': 'https://matrix.example.org',
              'user': '@$person:example.org',
              'room': '#demo:example.org',
              'password': _invitedSecret,
            },
      });
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

  // Harm: a person invited with the account they have is told to sign in with a password that does not exist, asks for
  // a new one, and so ends that account's sessions in every room.
  testWidgets('a join that invites an existing account says to accept the invitation, with no password', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend()..invites = true;
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final model = ProjectConversation(backend, machine, project, settings: settings);
    addTearDown(model.dispose);
    await model.join('anna');
    await tester.pumpWidget(MaterialApp(home: MessagesDialog(conversation: model)));
    await World.settle(tester);
    expect(find.textContaining('ccept the invitation'), findsWidgets);
    expect(find.textContaining('@anna:example.org'), findsWidgets);
    expect(find.textContaining('#demo:example.org'), findsWidgets);
    expect(find.textContaining('assword'), findsNothing, reason: 'no step or button names a password');
    expect(find.byKey(const Key('login password')), findsNothing, reason: 'a password in an invitation is not shown');
    expect(find.textContaining(_invitedSecret), findsNothing, reason: 'a password in an invitation is not shown');
    expect(find.textContaining('shown once'), findsNothing);
    expect(find.byKey(const Key('join-reset')), findsNothing, reason: 'no new password is offered for an invitation');
  });

  // Harm: an invited account offered New password on a second look gets one, which ends its sessions in every room.
  testWidgets('an invited account is offered no new password after Done and opening again', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend()..invites = true;
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final first = ProjectConversation(backend, machine, project, settings: settings);
    await first.join('anna');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () => unawaited(
              showDialog<void>(
                context: context,
                builder: (_) => MessagesDialog(conversation: first),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await World.settle(tester);
    expect(find.byKey(const Key('login-invited')), findsOneWidget, reason: 'the invitation was shown first');
    await tester.tap(find.byKey(const Key('messages-close')));
    await World.settle(tester);
    first.dispose();
    final reopened = ProjectConversation(backend, machine, project, settings: settings);
    addTearDown(reopened.dispose);
    await reopened.load();
    await tester.pumpWidget(MaterialApp(home: MessagesDialog(conversation: reopened)));
    await World.settle(tester);
    expect(find.byKey(const Key('joined-as')), findsOneWidget, reason: 'the invited account is the remembered one');
    expect(find.byKey(const Key('join-reset')), findsNothing, reason: 'no new password for an invited account');
    await reopened.newPassword();
    expect(backend.requests.where((each) => each.reset), isEmpty, reason: 'no reset reaches the invited account');
  });

  // Harm: a busy note naming a button that is not there points the person at an action that does not exist.
  testWidgets('while busy, an invitation names no grey New password', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final model = ProjectConversation(_Backend()..invites = true, machine, project, settings: settings);
    addTearDown(model.dispose);
    await model.join('anna');
    await tester.pumpWidget(MaterialApp(home: MessagesDialog(conversation: model)));
    model
      ..busy = true
      ..personChanged();
    await World.settle(tester);
    expect(find.byKey(const Key('join-reset')), findsNothing);
    expect(find.byKey(const Key('messages-why')), findsNothing, reason: 'nothing grey is there to explain');
  });

  // Harm: an invitation to a homeserver on a machine's loopback, without the forward said, leaves the client unable to
  // reach it.
  testWidgets('an invitation to a loopback homeserver says where it is reached', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final backend = _Backend()
      ..invites = true
      ..invitedLogin = <String, Object?>{
        'homeserver': 'http://127.0.0.1:8448',
        'user': '@anna:example.org',
        'room': '#demo:example.org',
        'loopback': 'true',
        'port': '8448',
      };
    final model = ProjectConversation(backend, machine, project, settings: settings);
    addTearDown(model.dispose);
    await model.join('anna');
    await tester.pumpWidget(MaterialApp(home: MessagesDialog(conversation: model)));
    await World.settle(tester);
    expect(find.byKey(const Key('login-invited')), findsOneWidget);
    expect(find.byKey(const Key('login-forward')), findsOneWidget, reason: 'the loopback homeserver is said for it');
  });

  // Harm: an empty Matrix ID or room read as one tells the person to sign in as nobody and shows an empty row.
  testWidgets('an invitation with an empty Matrix ID and room names neither', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final backend = _Backend()
      ..invites = true
      ..invitedLogin = <String, Object?>{'homeserver': 'https://matrix.example.org', 'user': '', 'room': ''};
    final model = ProjectConversation(backend, machine, project, settings: settings);
    addTearDown(model.dispose);
    await model.join('anna');
    await tester.pumpWidget(MaterialApp(home: MessagesDialog(conversation: model)));
    await World.settle(tester);
    expect(find.byKey(const Key('login user')), findsNothing, reason: 'an empty Matrix ID is absent');
    expect(find.byKey(const Key('login room')), findsNothing, reason: 'an empty room is absent');
    expect(find.textContaining('signed in as'), findsNothing);
    expect(find.textContaining('account  was'), findsNothing);
    expect(find.textContaining('room ,'), findsNothing);
  });

  // Harm: a Matrix ID or homeserver retyped by hand from the invitation signs in to the wrong account or server.
  testWidgets('an invitation copies each field it shows, and nothing of a password', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final model = ProjectConversation(_Backend()..invites = true, machine, project, settings: settings);
    addTearDown(model.dispose);
    await model.join('anna');
    await tester.pumpWidget(MaterialApp(home: MessagesDialog(conversation: model)));
    await World.settle(tester);
    for (final field in <String>['homeserver', 'user', 'room']) {
      expect(find.byKey(ValueKey<String>('login-copy $field')), findsOneWidget, reason: 'the $field is copied');
    }
    expect(find.byKey(const ValueKey<String>('login-copy password')), findsNothing);
    expect(find.byKey(const Key('login-copy-all')), findsNothing, reason: 'nothing copies the login as a whole');
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
