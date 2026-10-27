import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/start_agents.dart';

import 'support/idl.dart';

/// Runs this client against a **real** `porelod`.
///
/// Skipped unless one is there, because it needs the whole backend up:
///
/// ```bash
/// porelod &                       # or install the porelo package
/// PORELO_SOCKET=$XDG_RUNTIME_DIR/porelo/porelod.sock flutter test test/client/live_daemon_test.dart
/// ```
///
/// It is the only test that can say the hand-written client agrees with the daemon rather than
/// with our reading of the IDL. Everything else in this suite runs against a stand-in, and a
/// stand-in only ever proves that the client handles what *we* decided to send it. **A drifted
/// mock is worse than no mock**, and this is what keeps it honest.
void main() {
  final socket = Platform.environment['PORELO_SOCKET'] ?? '';
  final there = socket.isNotEmpty && (File(socket).existsSync() || Link(socket).existsSync());

  group('against a running daemon', () {
    late PoreloClient client;

    setUpAll(() async {
      client = await PoreloClient.connect(Backend(socketPath: socket, label: 'the live daemon'));
    });

    test('serves an interface this build understands', () async {
      expect(PoreloClient.supported, contains(client.interfaceName));
      expect(client.info.version, isNotEmpty);
    });

    test('declares every method this client calls', () async {
      // The drift check. A method renamed or dropped on the far side shows up here as a name this
      // contract no longer contains, rather than as a MethodNotFound in front of somebody.
      final contract = await client.contract();

      // Read from the client itself rather than listed here: a list beside it named 14 of 48.
      final called = RegExp(r"_call(?:More)?\('([A-Za-z]+)'")
          .allMatches(File('lib/src/client/porelo_client.dart').readAsStringSync())
          .map((match) => match.group(1)!)
          .toSet();
      expect(called, hasLength(greaterThan(40)), reason: 'the client source was not read');

      for (final method in called) {
        expect(
          contract,
          contains('method $method'),
          reason: '$method is called by this client and is not in the served contract',
        );
      }
    });

    test('declares every name this client sends to and reads from the vault keyslots', () async {
      // A method existing is not the requirement being covered: the parameters and the fields are
      // what the device screens are built on, so each one is looked for in its own declaration.
      final contract = await client.contract();
      String declaration(String head) {
        final found = declarationIn(contract, head);
        expect(found, isNotNull, reason: '"$head" is not in the served contract');
        return found!;
      }

      final expected = <String, List<String>>{
        'type Keyslot (': ['id', 'name', 'storage', 'enrolled', 'lastUsed', 'self', 'recovery'],
        'method EnrollDevice(': ['name', 'share', 'storage', 'outcome', 'slot', 'detail'],
        'method RevokeKeyslot(': ['id', 'outcome', 'remaining', 'detail'],
        'method UnlockWithShare(': ['share', 'minutes', 'outcome', 'until', 'slot', 'detail'],
      };
      for (final MapEntry(key: head, value: names) in expected.entries) {
        final text = declaration(head);
        for (final name in names) {
          expect(declares(text, name), isTrue, reason: '$name is used by this client and not declared in "$head"');
        }
      }
      for (final value in [
        ...KeyslotStorage.known.map((storage) => storage.name),
        ...KeyslotOutcome.known.map((outcome) => outcome.name),
      ]) {
        expect(contract, contains(value), reason: '$value is known to this client and not served');
      }
    });

    test('answers Keyslots with slots this build can read', () async {
      // Readable while the vault is locked and changes nothing, so it is the one keyslot call made
      // here; the other three would change a vault.
      final slots = await client.keyslots();
      for (final slot in slots) {
        expect(slot.id, isNotEmpty);
        expect(
          slot.storage.recognized || slot.recovery,
          isTrue,
          reason: 'slot ${slot.id} declares ${slot.storage.name}',
        );
      }
    });

    test(
      'enrolls a device, opens the vault with it, and takes it away again',
      () async {
        // Changes a vault, so it runs only where somebody said this vault is a test's to change.
        final share = base64.encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
        final name = 'live test ${DateTime.now().microsecondsSinceEpoch}';

        final enrolled = await client.enrollDevice(name: name, share: share, storage: KeyslotStorage.userScoped);
        expect(enrolled.outcome.name, KeyslotOutcome.enrolled.name, reason: enrolled.detail);
        final slot = enrolled.slot!;
        addTearDown(() => client.revokeKeyslot(slot.id));
        expect(slot.id, isNotEmpty);
        expect(slot.name, name);
        expect(slot.storage.name, KeyslotStorage.userScoped.name);
        expect(slot.enrolled, isNotEmpty);
        expect(slot.recovery, isFalse);

        final listed = await client.keyslots();
        expect(listed.map((each) => each.id), contains(slot.id));
        expect(
          listed.where((each) => each.recovery),
          hasLength(1),
          reason: 'the passphrase is keyslot 0 and is listed beside the devices',
        );

        final wrong = base64.encode(List<int>.filled(32, 7));
        expect(
          (await client.unlockWithShare(share: wrong, minutes: 1)).outcome.name,
          KeyslotOutcome.shareRejected.name,
        );

        final unlocked = await client.unlockWithShare(share: share, minutes: 1);
        expect(unlocked.outcome.name, KeyslotOutcome.unlocked.name, reason: unlocked.detail);
        expect(unlocked.until, isNotEmpty, reason: 'a bounded unlock says when it runs out');
        expect(unlocked.slot?.id, slot.id);

        final revoked = await client.revokeKeyslot(slot.id);
        expect(revoked.outcome.name, KeyslotOutcome.revoked.name, reason: revoked.detail);
        expect(revoked.remaining.map((each) => each.id), isNot(contains(slot.id)));
        expect(revoked.remaining.where((each) => each.recovery), hasLength(1));
      },
      skip: Platform.environment['PORELO_VAULT_TEST'] == '1'
          ? false
          : 'changes a vault: set PORELO_VAULT_TEST=1 where the vault is a test\'s own',
    );

    test('declares every name this client sends to and reads from held messages', () async {
      final contract = await client.contract();
      String declaration(String what) {
        final found = declarationIn(contract, what);
        expect(found, isNotNull, reason: '$what is not in the served contract');
        return found!;
      }

      final held = declaration('type HeldMessage (');
      for (final field in <String>[
        'task',
        'standing',
        'message',
        'id',
        'role',
        'peer',
        'kind',
        'at',
        'reason',
        'direction',
      ]) {
        expect(declares(held, field), isTrue, reason: 'HeldMessage has no $field');
      }
      final read = declaration('method ReadHeld(');
      for (final field in <String>['outcome', 'standing', 'message', 'text', 'reason', 'direction']) {
        expect(declares(read, field), isTrue, reason: 'ReadHeld answers no $field');
      }
      final release = declaration('method Release(');
      for (final field in <String>['refuse', 'outcome', 'detail']) {
        expect(declares(release, field), isTrue, reason: 'Release has no $field');
      }
    });

    test('declares every name this client sends to and reads from peers and what a person says', () async {
      final contract = await client.contract();
      String declaration(String what) {
        final found = declarationIn(contract, what);
        expect(found, isNotNull, reason: '$what is not in the served contract');
        return found!;
      }

      final peer = declaration('type TalkPeer (');
      for (final field in <String>[
        'name',
        'address',
        'trust',
        'perDay',
        'mode',
        'held',
        'sentToday',
        'receivedToday',
      ]) {
        expect(declares(peer, field), isTrue, reason: 'TalkPeer has no $field');
      }
      expect(declares(declaration('method Peers('), 'project'), isTrue);
      final moderate = declaration('method Moderate(');
      for (final field in <String>['task', 'project', 'name', 'held', 'mode']) {
        expect(declares(moderate, field), isTrue, reason: 'Moderate has no $field');
      }
      final say = declaration('method Say(');
      for (final field in <String>['task', 'peer', 'kind', 'text', 'context', 'message', 'outcome']) {
        expect(declares(say, field), isTrue, reason: 'Say has no $field');
      }
    });

    test('answers Held with messages this build can read', () async {
      expect(await client.held(), isA<List<HeldMessage>>());
    });

    test('answers a message that is not there with NO_SUCH_MESSAGE, and decides nothing', () async {
      final tasks = await client.tasks();
      if (tasks.isEmpty) {
        markTestSkipped('this account has no task to ask about');
        return;
      }
      final task = tasks.first.name;
      const nothing = 'e2e-no-such-message.json';
      expect((await client.readHeld(task, nothing)).outcome, 'NO_SUCH_MESSAGE');
      expect((await client.release(task, nothing)).outcome, 'NO_SUCH_MESSAGE');
      expect(await client.held(task: task), isA<List<HeldMessage>>());
    });

    test(
      'reads a message held for a person in full, and refuses it for good',
      () async {
        // Needs a task whose peer is held and a message a person wrote to it, made at the machine:
        //   porelo talk hold <task> <peer>; printf '...' | porelo talk say <task> <peer>; porelo talk pass <task>
        final task = Platform.environment['PORELO_TALK_TASK']!;
        final held = await client.held(task: task);
        final waiting = held.where((each) => each.standing == 'held').toList();
        expect(waiting, isNotEmpty, reason: 'nothing is held for a person in $task');
        final message = waiting.first;
        expect(message.task, task);
        expect(message.message, endsWith('.json'));
        expect(message.role, 'ROLE_USER', reason: 'a person wrote it with talk say');
        expect(message.direction, 'out', reason: 'a person wrote it to a peer, so it was leaving');
        final peers = await client.peers(task, Platform.environment['PORELO_TALK_PROJECT']!);
        final peer = peers.where((each) => each.name == message.peer).single;
        expect(peer.held, isTrue);
        expect(peer.sentToday, isNotNull, reason: 'the budget used is not said');
        expect(peer.receivedToday, isNotNull, reason: 'the budget used is not said');

        final read = await client.readHeld(task, message.handle);
        expect(read.outcome, 'FOUND');
        expect(read.standing, 'held');
        expect(read.message, message.message, reason: 'what was listed is what was read');
        expect(read.text, isNotEmpty);
        expect(read.reason, isNotEmpty);

        final done = await client.release(task, read.message, refuse: true);
        expect(done.outcome, 'REFUSED');
        expect(done.message, message.message);
        final after = await client.held(task: task);
        expect(after.where((each) => each.message == message.message).map((each) => each.standing), <String>[
          'refused-by-person',
        ], reason: 'refused for good is still listed, and never waits');
      },
      skip: Platform.environment['PORELO_TALK_TASK'] == null
          ? 'needs a task with a message held for a person: set PORELO_TALK_TASK and PORELO_TALK_PROJECT'
          : false,
    );

    test('answers List with tasks this build can read', () async {
      // Reading them at all is the assertion: every reader tolerates a shape the backend did not
      // promise, so a task that fails to parse here is a contract change, not a bad machine.
      expect(await client.tasks(), isA<List<Task>>());
    });
  }, skip: there ? false : 'no daemon: set PORELO_SOCKET to a running porelod to run these');

  // The agent of each repository at one click, against a daemon that names them: what the wizard was built against a
  // stand-in for, said by the real one.
  final walk = Platform.environment['PORELO_AGENTS_PROJECT'];
  group(
    'a project whose repositories name agents',
    () {
      late PoreloBackend backend;
      final started = <String>[];

      setUpAll(() async {
        backend = PoreloBackend(Backend(socketPath: socket, label: 'the live daemon'));
        await backend.open();
      });

      tearDownAll(() async {
        for (final task in started) {
          await backend.stopTask(task);
          await backend.removeTask(task, force: true);
        }
      });

      Future<Project> project() async => (await backend.projects()).singleWhere((each) => each.name == walk);

      test('names each repository\'s agent, and one click starts exactly those, attended', () async {
        final read = await project();
        final named = {for (final each in read.repositoryStates) each.name: each.agent};
        expect(
          named.values,
          everyElement(isNotNull),
          reason: 'a daemon that names agents says it for every repository',
        );
        expect(StartAgents.whyNot(read), isNull, reason: 'the command is offered');

        final model = StartAgents();
        addTearDown(model.dispose);
        await model.open(backend, read);
        expect(model.problem, isNull);
        final wanted = {
          for (final entry in named.entries)
            if (entry.value!.isNotEmpty) entry.key: entry.value,
        };
        expect({for (final row in model.toStart) row.repository: row.agent}, wanted, reason: 'one row each, its agent');
        expect(model.rows.where((row) => !row.namesAnAgent).map((row) => row.repository), isNotEmpty);
        for (final row in model.rows.where((row) => row.namesAnAgent)) {
          final repository = read.repositoryStates.singleWhere((each) => each.name == row.repository);
          expect(row.goesBy, repository.goesBy, reason: 'shown as the daemon says it, ${repository.goesBy}');
        }

        // What the wizard waits on before its start, each said by the machine.
        expect(model.askProblem, isNull);
        expect(model.signInsNeeded.map((agent) => agent.name), isEmpty, reason: 'the stub needs no sign-in');
        expect({for (final row in model.held) row.repository: row.held}, isEmpty);
        expect(model.asked, isTrue);
        await model.startAll();
        expect({for (final row in model.rows) row.repository: row.refusal}.values.nonNulls, isEmpty);
        final tasks = await backend.tasks();
        final made = tasks.where((task) => task.project == walk).toList();
        started.addAll(made.map((task) => task.name));
        expect({for (final task in made) task.repository: task.agent}, wanted, reason: 'exactly those were started');
        expect(made.map((task) => task.mode), everyElement(Mode.agent), reason: 'attended, with no prompt');

        // Opened again, nothing is started twice: each runs already.
        final again = StartAgents();
        addTearDown(again.dispose);
        await again.open(backend, await project());
        expect(again.toStart, isEmpty, reason: 'every one runs, or continues, already');
      }, timeout: const Timeout(Duration(minutes: 20)));
    },
    skip: there && walk != null
        ? false
        : 'needs a daemon that names repositories\' agents and a project naming them: set PORELO_AGENTS_PROJECT',
  );
}
