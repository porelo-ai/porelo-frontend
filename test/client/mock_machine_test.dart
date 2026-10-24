// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// Holds the stand-in to the behavior the interface is built on, over a real socket.
///
/// The frame's own tests run against a hand-written fake, because a widget test's clock cannot
/// carry real input and output. That leaves the thing a person actually opens the interface
/// against — `tool/mock_daemon.dart`, which is this machine — covered by nothing, and it is where
/// the mistake landed: `Stop` answered *removed* and went on listing the task, so a working
/// interface looked like one where nothing happens. Green tests, broken by hand in a minute.
void main() {
  late MockDaemon daemon;
  late MockMachine machine;

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  Future<void> machineIn(String situation) async {
    daemon = MockDaemon();
    await daemon.start();
    machine = MockMachine(daemon, situation: situation, pace: Duration.zero);
    addTearDown(() async {
      await machine.close();
      await daemon.stop();
    });
  }

  // Harm: an untyped mock dependency can hide a recovery that would target the wrong vault.
  test('the locked vault situation serves the dependency of its waiting messages', () async {
    await machineIn('vault-locked');
    final client = await connect();
    final messages = (await client.projects()).firstWhere((project) => project.name == 'checkout').messages!;
    expect(messages.waits, isNotEmpty);
    expect(messages.waitsOn, 'vault');
  });

  test('a stopped task is kept, and listed as one Start brings back', () async {
    await machineIn('work');
    final client = await connect();

    final stopped = await client.stop('porelo-checkout-shell');

    expect(stopped.outcome, Outcome.stopped);
    final task = (await client.tasks()).firstWhere((task) => task.name == 'porelo-checkout-shell');
    expect(task.running, isFalse);
    expect(task.startAction, StartAction.resume);
  });

  test('a running task is not removed, and says so', () async {
    await machineIn('work');
    final client = await connect();

    final refused = await client.remove('porelo-checkout-shell');

    expect(refused.outcome, Outcome.stillRunning);
    expect(refused.removed, isFalse);
    expect((await client.tasks()).map((task) => task.name), contains('porelo-checkout-shell'));
  });

  test('a removed task stops being listed', () async {
    await machineIn('work');
    final client = await connect();

    final removed = await client.remove('porelo-checkout-migrate');

    expect(removed.outcome, Outcome.removed);
    expect(removed.removed, isTrue);
    expect((await client.tasks()).map((task) => task.name), isNot(contains('porelo-checkout-migrate')));
  });

  test('a refused removal changes nothing at all', () async {
    await machineIn('holds-work');
    final client = await connect();

    final refused = await client.remove('porelo-checkout-migrate');

    expect(refused.outcome, Outcome.holdsWork);
    expect(refused.removed, isFalse);
    expect(refused.work, isNotEmpty);
    expect((await client.tasks()).map((task) => task.name), contains('porelo-checkout-migrate'));
  });

  test('asking again with force gets through, because that is the point of asking', () async {
    await machineIn('holds-work');
    final client = await connect();
    await client.remove('porelo-checkout-migrate');

    final forced = await client.remove('porelo-checkout-migrate', force: true);

    expect(forced.removed, isTrue);
    expect((await client.tasks()).map((task) => task.name), isNot(contains('porelo-checkout-migrate')));
  });

  test('a stopped task started again is listed as running', () async {
    await machineIn('work');
    final client = await connect();

    final started = await client.start(project: 'checkout', task: 'migrate').last;

    expect(started.action, StartAction.resume);
    expect(started.helpersStarted, lessThan(started.helpersRecorded!));
    final task = (await client.tasks()).firstWhere((task) => task.name == 'porelo-checkout-migrate');
    expect(task.running, isTrue);
    expect(task.startAction, StartAction.running);
  });

  test('a running task is refused a second start', () async {
    await machineIn('work');
    final client = await connect();

    final refused = await client.start(project: 'checkout', task: 'shell').last;

    expect(refused.action, StartAction.running);
  });

  test('a change reaches a watcher without it asking again', () async {
    await machineIn('work');
    final client = await connect();
    // Driven by the events themselves rather than by a delay: a stream test that waited for wall
    // time is a flaky test, and flaky tests get deleted.
    final seen = <int>[];
    final first = Completer<void>();
    final second = Completer<void>();
    final watching = client.watchTasks().listen((tasks) {
      seen.add(tasks.length);
      if (seen.length == 1) first.complete();
      if (seen.length == 2) second.complete();
    });

    await first.future;
    await client.remove('porelo-checkout-migrate');
    await second.future;

    expect(seen.first, 6);
    expect(seen.last, 5);
    await watching.cancel();
  });

  test('a log is followed, and a name it does not have is refused', () async {
    await machineIn('work');
    final client = await connect();

    final read = await client.tailLog('porelo-checkout-shell', 'agent.log').take(2).toList();
    expect(read.expand((lines) => lines), isNotEmpty);

    await expectLater(
      client.tailLog('porelo-checkout-shell', 'nowhere.log').first,
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'NoSuchLog')),
    );
  });

  test('a blocked connection arrives, and its answer comes back on the same stream', () async {
    await machineIn('work');
    final client = await connect();

    final seen = <Prompt>[];
    final asked = Completer<void>();
    final answered = Completer<void>();
    final watching = client.prompts().listen((prompt) {
      seen.add(prompt);
      if (seen.length == 1) asked.complete();
      if (seen.length == 2) answered.complete();
    });

    machine.blocks('api.example.test:443');
    await asked.future;
    expect(seen.single.settled, isFalse);
    expect(seen.single.prefix, isNotEmpty);

    await client.decide(seen.first, allow: true);
    await answered.future;

    // The same question a second time, carrying its answer — matched by task and key, because
    // `at` means the decision time here and `prefix` is empty.
    expect(seen.last.identity, seen.first.identity);
    expect(seen.last.settled, isTrue);
    expect(seen.last.verdict, 'allow');
    expect(seen.last.prefix, isEmpty);
    await watching.cancel();
  });

  test('a question that runs out says so, because nothing asks again', () async {
    await machineIn('work');
    final client = await connect();
    final seen = <Prompt>[];
    final expired = Completer<void>();
    final watching = client.prompts().listen((prompt) {
      seen.add(prompt);
      if (prompt.expired) expired.complete();
    });

    machine.expires(machine.blocks('api.example.test:443'));
    await expired.future;

    expect(seen.last.expired, isTrue);
    await watching.cancel();
  });

  test('a task says what it is doing, beside what the runtime says', () async {
    await machineIn('work');
    final client = await connect();

    final tasks = await client.tasks();
    final waiting = tasks.firstWhere((task) => task.activity == Activity.waiting);

    expect(waiting.waitingFor, isNotEmpty);
    expect(waiting.state, isNotEmpty, reason: 'state stays the runtime own words');
    expect(waiting.startedAt, isNotNull);
    expect(waiting.mode.recognized, isTrue);
    // A terminal attached means nothing on this side can see it, and that is its own answer.
    expect(tasks.map((task) => task.activity), contains(Activity.unknown));
  });

  test('an activity from a later release renders rather than throwing', () async {
    await machineIn('work');
    daemon.method(
      'List',
      (_) => <String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'a-task', 'activity': 'QUIESCED'},
        ],
      },
    );
    final client = await connect();

    final task = (await client.tasks()).single;

    expect(task.activity.recognized, isFalse);
    expect(task.activity.label, 'quiesced');
  });

  test('a preview writes nothing, and the same change written does', () async {
    await machineIn('work');
    final client = await connect();
    const project = 'checkout';

    final (before, _) = await client.egress(project);
    final previewed = await client.setEgress(project, addSets: <String>['containers'], dryRun: true);

    expect(previewed.outcome, EgressOutcome.previewed);
    expect(previewed.opens, isNotEmpty);
    // Hosts, not set names: adding one set opens three here.
    expect(previewed.opens.map((host) => host.host), contains('quay.io'));
    final (stillBefore, _) = await client.egress(project);
    expect(stillBefore.length, before.length, reason: 'a preview wrote something');

    final done = await client.setEgress(project, addSets: <String>['containers']);
    expect(done.outcome, EgressOutcome.changed);
    final (after, _) = await client.egress(project);
    expect(after.length, greaterThan(before.length));
  });

  test('a launch with no prompt ends when the container is up', () async {
    await machineIn('work');
    final client = await connect();

    final lines = <String>[];
    var code = -1;
    await for (final progress in client.start(project: 'checkout')) {
      if (progress.line != null) lines.add(progress.line!);
      if (progress.exitCode != null) code = progress.exitCode!;
    }

    expect(code, 0);
    expect(lines, isNotEmpty);
    expect(
      lines.any((line) => line.startsWith('agent:')),
      isFalse,
      reason: 'nothing was asked for, so nothing should have run',
    );
  });

  test('a launch with a prompt runs the agent and streams what it writes', () async {
    await machineIn('work');
    final client = await connect();

    final lines = <String>[];
    var code = -1;
    await for (final progress in client.start(
      task: 'porelo-checkout-run',
      project: 'checkout',
      agent: 'an-agent',
      mode: Mode.unattended,
      prompt: 'Fix the rounding in Money.pennies',
    )) {
      if (progress.line != null) lines.add(progress.line!);
      if (progress.exitCode != null) code = progress.exitCode!;
    }

    expect(code, 0);
    // The raw log, which is the same text `Tail` serves for `task.log`.
    expect(lines, contains('agent: Fix the rounding in Money.pennies'));

    // And it is listed afterwards, keeping what it was asked to do — which is what continuing it
    // with a new prompt reads back.
    final run = (await client.tasks()).firstWhere((task) => task.name == 'porelo-checkout-run');
    expect(run.mode, Mode.unattended);
    expect(run.prompt, 'Fix the rounding in Money.pennies');
    expect(run.running, isFalse);
  });

  test('a run killed by its own time limit comes back 124, with its log kept', () async {
    await machineIn('out-of-time');
    final client = await connect();

    final lines = <String>[];
    var code = -1;
    await for (final progress in client.start(project: 'checkout', prompt: 'Fix the rounding')) {
      if (progress.line != null) lines.add(progress.line!);
      if (progress.exitCode != null) code = progress.exitCode!;
    }

    expect(code, 124);
    expect(
      lines,
      contains('agent: running the tests'),
      reason: 'the log is kept, and what it managed to do is the interesting part',
    );
  });

  test('asking for a run with no agent installed comes back 69, having run nothing', () async {
    await machineIn('no-agent');
    final client = await connect();

    var code = -1;
    final lines = <String>[];
    await for (final progress in client.start(project: 'checkout', prompt: 'Fix the rounding')) {
      if (progress.line != null) lines.add(progress.line!);
      if (progress.exitCode != null) code = progress.exitCode!;
    }

    expect(code, 69);
    expect(lines.any((line) => line.startsWith('agent:')), isFalse, reason: 'nothing ran, so there is nothing to read');
  });

  test('the machine says what it can run, what it cannot, and what it never will', () async {
    await machineIn('work');
    final client = await connect();

    final answered = await client.agents();

    expect(answered.agents.map((agent) => agent.name), contains('an-agent'));
    // Named rather than left out: missing from a list looks exactly like never installed.
    expect(answered.failures.keys, contains('broken-agent'));
    // Installed and never started, with the copy that wins named beside it.
    expect(answered.shadowed, hasLength(1));
    expect(answered.shadowed.single.usedInstead, isNotEmpty);
  });

  test('an agent says what it pins, what it refuses, and what it fetches', () async {
    await machineIn('work');
    final client = await connect();

    final answered = await client.agents();
    final agent = answered.agents.firstWhere((each) => each.name == 'an-agent');

    // The pinned build, from the manifest. Nothing executes an agent to ask its version.
    expect(agent.version, '2.4.0');
    // Declared and deliberately not given — a decision, which a dropped packet cannot express.
    expect(agent.refusedDomains, contains('telemetry.example.test'));
    expect(agent.artifacts, hasLength(1));
    expect(agent.artifacts.single.unverified, isFalse);
    expect(agent.artifacts.single.sha256, hasLength(64));
  });

  test('an artifact fetched without a digest always says why', () async {
    await machineIn('work');
    final client = await connect();

    final answered = await client.agents();
    final agent = answered.agents.firstWhere((each) => each.name == 'other-agent');

    // Two states, never three: the daemon refuses to build one with neither a digest nor a
    // reason, so nothing here has to render a blank with no explanation.
    expect(agent.artifacts.single.unverified, isTrue);
    expect(agent.artifacts.single.sha256, isEmpty);
    expect(agent.artifacts.single.reason, isNotEmpty);
  });

  test('widening a running task grants the names, in the order asked for', () async {
    await machineIn('work');
    final client = await connect();

    final done = await client.widenTask('porelo-checkout-shell', <String>[
      'files.example.test',
      'docs.example.test',
    ], scope: Scope.runAndProject);

    expect(done.outcome, WidenOutcome.widened);
    // Names, not addresses, and not sorted: a grant covers what is under a name.
    expect(done.opens, <String>['files.example.test', 'docs.example.test']);
    expect(done.persisted, isTrue, reason: 'RUN_AND_PROJECT was asked for');
  });

  test('a preview grants nothing, so the same call afterwards still opens them', () async {
    await machineIn('work');
    final client = await connect();

    final previewed = await client.widenTask(
      'porelo-checkout-shell',
      <String>['files.example.test'],
      scope: Scope.run,
      dryRun: true,
    );
    expect(previewed.outcome, WidenOutcome.previewed);
    expect(previewed.opens, <String>['files.example.test']);

    // If the preview had written, this would come back NO_CHANGE.
    final done = await client.widenTask('porelo-checkout-shell', <String>['files.example.test'], scope: Scope.run);
    expect(done.outcome, WidenOutcome.widened);
    expect(done.persisted, isFalse, reason: 'RUN does not reach the project file');
  });

  test('asking twice for the same name is no change, not a second grant', () async {
    await machineIn('work');
    final client = await connect();
    const asking = <String>['files.example.test'];

    await client.widenTask('porelo-checkout-shell', asking, scope: Scope.run);
    final again = await client.widenTask('porelo-checkout-shell', asking, scope: Scope.run);

    expect(again.outcome, WidenOutcome.noChange);
    expect(again.opens, isEmpty);
  });

  test('a task that is not running is refused as an outcome, not an exception', () async {
    await machineIn('work');
    final client = await connect();

    final refused = await client.widenTask('porelo-checkout-migrate', <String>['files.example.test'], scope: Scope.run);

    expect(refused.outcome, WidenOutcome.notRunning);
    expect(refused.opens, isEmpty);
  });

  test('an offline project is refused by its class, the way the editor refuses it', () async {
    await machineIn('work');
    final client = await connect();

    final refused = await client.widenTask('porelo-billing-shell', <String>['files.example.test'], scope: Scope.run);

    expect(refused.outcome, WidenOutcome.refusedByClass);
  });

  test('a project with no file widens the run and says the file was not written', () async {
    await machineIn('work');
    final client = await connect();

    final partly = await client.widenTask('porelo-moved-work', <String>[
      'files.example.test',
    ], scope: Scope.runAndProject);

    // The run *was* widened. Reading this as a failure would tell somebody the task still cannot
    // reach the host when it can.
    expect(partly.outcome, WidenOutcome.noProjectFile);
    expect(partly.opens, <String>['files.example.test']);
    expect(partly.persisted, isFalse);
  });

  test('a parameter of the wrong type is refused, not left unanswered', () async {
    // Sent raw, because the client cannot get a type wrong; a stand-in that hung on it would read
    // as a daemon that never answers.
    await machineIn('work');
    final wire = await VarlinkConnection.open(daemon.socketPath);
    addTearDown(wire.close);

    await expectLater(
      wire
          .call('org.fuin.porelo.Tasks1.NarrowTask', <String, dynamic>{
            'task': 42,
            'domains': <String>['files.example.test'],
            'scope': 'RUN',
          })
          .timeout(const Duration(seconds: 5)),
      throwsA(isA<VarlinkException>().having((ex) => ex.simpleName, 'simpleName', 'InvalidParameter')),
    );
  });

  test('a call with no scope is refused rather than given a default', () async {
    // Sent raw, because the client cannot express this: `scope` is a required argument there.
    // It is worth holding anyway — the daemon choosing for somebody is the failure this
    // requirement is most exposed to, and a stand-in that quietly defaulted would hide it.
    await machineIn('work');
    final wire = await VarlinkConnection.open(daemon.socketPath);
    addTearDown(wire.close);

    await expectLater(
      wire.call('org.fuin.porelo.Tasks1.WidenTask', <String, dynamic>{
        'task': 'porelo-checkout-shell',
        'domains': <String>['files.example.test'],
      }),
      throwsA(isA<VarlinkException>().having((ex) => ex.simpleName, 'simpleName', 'ScopeRequired')),
    );
  });

  test('a set that is not installed is refused with its name, not an exception', () async {
    await machineIn('work');
    final client = await connect();

    final refused = await client.setEgress('checkout', addSets: <String>['nothing-like-this']);

    expect(refused.outcome, EgressOutcome.noSuchSet);
    expect(refused.detail, contains('nothing-like-this'));
  });

  test('what is refused is answered beside what is reachable', () async {
    await machineIn('work');
    final client = await connect();

    final (hosts, refused) = await client.egress('checkout');

    expect(hosts.first.origin, startsWith('agent '));
    expect(refused, isNotEmpty);
  });

  test('a project that has never run anything is still listed', () async {
    // The whole reason to ask rather than derive: a client that built the list from the tasks
    // could never show one, and that is the project most likely to need attention.
    await machineIn('work');
    final client = await connect();

    final projects = await client.projects();

    expect(projects.map((project) => project.name), contains('never-run'));
    expect(projects.firstWhere((project) => project.name == 'never-run').tasks, 0);
  });

  test('a project with no file recorded is listed and cannot be acted on', () async {
    // A state to render, not an error. Every method that acts on a project takes its file.
    await machineIn('work');
    final client = await connect();

    final moved = (await client.projects()).firstWhere((project) => project.name == 'moved-away');

    expect(moved.file, isEmpty);
    expect(moved.canBeActedOn, isFalse);
    expect(moved.pending, 1);
  });

  test('what is waiting at the gate can be read, judged and forwarded', () async {
    await machineIn('work');
    final client = await connect();
    const project = 'checkout';

    final gate = await client.gate(project);
    expect(gate.mode, 'gatekeeping');
    expect(gate.pending, hasLength(2));

    final (:diff, :log, files: _, asked: _) = await client.review(project, gate.pending.first.name);
    expect(diff, contains('diff --git'));
    expect(log, contains('commit'));

    await client.approve(project, gate.pending.first.name, 'fix-rounding');

    // Forwarding takes it out of the gate: it has been decided about and is not waiting any more.
    expect((await client.gate(project)).pending, hasLength(1));
  });

  test('each waiting push is reviewed as its own change', () async {
    // Asked for by its short name, as the contract says; a whole-ref comparison served every push
    // as the first one's diff.
    await machineIn('work');
    final client = await connect();

    final (:diff, :log, files: _, asked: _) = await client.review('checkout', 'drop-dead-code');

    expect(diff, contains('deleted file mode'));
    expect(log, contains('commit 7f21b0e'));
  });

  test('forwarding with no branch is refused rather than guessed at', () async {
    // Approve is the only call in the contract that sends anything anywhere. A branch inferred
    // here would be a push nobody decided about.
    await machineIn('work');
    final client = await connect();

    await expectLater(
      client.approve('checkout', 'migrate', ''),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'BranchRequired')),
    );
  });

  test('a branch already holding other work is refused by name, and nothing is forwarded', () async {
    await machineIn('work');
    final client = await connect();
    await client.approve('checkout', 'migrate', 'fix-rounding');

    await expectLater(
      client.approve('checkout', 'drop-dead-code', 'fix-rounding'),
      throwsA(
        isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'BranchExists').having(
          (refusal) => refusal.parameters,
          'parameters',
          <String, dynamic>{'branch': 'fix-rounding', 'at': '9a3c1f2'},
        ),
      ),
    );
    expect((await client.gate('checkout')).pending.map((push) => push.name), <String>['drop-dead-code']);
  });

  test('a new task whose earlier work waits at the gate is refused by name, naming that work', () async {
    await machineIn('work');
    final client = await connect();

    await expectLater(
      // drop-dead-code's container is gone, so this is a new task, not one started again.
      client.start(task: 'drop-dead-code', project: 'checkout').drain<void>(),
      throwsA(
        isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'EarlierWorkWaits').having(
          (refusal) => refusal.parameters,
          'parameters',
          <String, dynamic>{
            'task': 'drop-dead-code',
            'commit': '7f21b0e',
            'subject': 'Delete the retry loop nothing calls any more',
          },
        ),
      ),
    );
  });

  test('dropping a request takes it out of the gate and sends nothing', () async {
    await machineIn('work');
    final client = await connect();
    const project = 'checkout';

    await client.reject(project, 'drop-dead-code');

    expect((await client.gate(project)).pending, hasLength(1));
  });

  test('the machine says what it can run, and names one action per failure', () async {
    await machineIn('work');
    final client = await connect();

    final health = await client.doctor();

    expect(health.probes, isNotEmpty);
    // Degraded leaves a machine ready — it runs tasks, and the report says how well.
    expect(health.ready, isTrue);
    expect(health.worthReading, isNotEmpty);
    // A probe that fails and names nothing to do about it cannot be constructed on the daemon
    // side, so this can be rendered without checking. That is worth holding to.
    for (final probe in health.probes) {
      if (!probe.fine) expect(probe.action, isNotEmpty, reason: probe.name);
    }
  });

  test('a provider says where its credential belongs, under the key it really uses', () async {
    await machineIn('work');
    final client = await connect();

    final answer = await client.providers();

    expect(answer.readable, isTrue);
    final fallback = answer.providers.firstWhere((each) => each.name == 'other-provider');
    // Stored under the *agent's* name rather than its own — the key a client would never have
    // found by intersecting providers with stored names, which is why it is computed there.
    expect(fallback.credentialName, 'an-agent');
    expect(fallback.storeCommand, contains('an-agent'));
  });

  test('importing names an agent that is not there rather than failing vaguely', () async {
    await machineIn('work');
    final client = await connect();

    final answer = await client.importCredential(agent: 'not-installed');

    expect(answer.outcome, 'NO_SUCH_AGENT');
    expect(answer.stored, isFalse);
    expect(answer.length, 0);
  });

  test('the backups it lists tell a record from the bundle', () async {
    await machineIn('work');
    final client = await connect();

    // **The project's name, not its file.** The IDL says only `project: string` for this one,
    // and the daemon resolves it as a name — one record file per project name. Passing a path
    // answers an empty list, which reads as *nothing recorded* rather than as a wrong argument:
    // the worst shape a mistake can take on this particular field.
    final taken = await client.backups('checkout');

    expect(taken, hasLength(2));
    // Listed although the file is gone: dropping it would say the backup was never made.
    expect(taken.any((each) => !each.present), isTrue);
    expect(taken.firstWhere((each) => !each.present).bytes, 0);
  });

  test('restoring over unreviewed work refuses, and force says what it destroyed', () async {
    await machineIn('work');
    final client = await connect();
    const project = 'checkout';
    const bundle = '/srv/checkout/backups/before-sync.bundle';

    final refused = await client.restoreBackup(project, bundle);

    expect(refused.holdsWork, isTrue);
    expect(refused.unreviewed, isNotEmpty);

    final forced = await client.restoreBackup(project, bundle, force: true);

    expect(forced.done, isTrue);
    // Reported afterwards as well as before: somebody who forced needs it in the record.
    expect(forced.unreviewed, isNotEmpty);
  });

  test('an offline project is not reported as up to date', () async {
    await machineIn('work');
    final client = await connect();

    final said = await client.syncUpstream('billing');

    // Zero, and meaningless: the same number a project that is up to date answers.
    expect(said.behind, 0);
    expect(said.measured, isFalse);
    expect(said.reason, 'OFFLINE');
  });

  test('following a repository makes a project that is taken at once', () async {
    await machineIn('work');
    final client = await connect();

    final followed = await client.follow('payments', 'file:///srv/git/payments', unverified: true);
    final project = (await client.projects()).singleWhere((each) => each.name == 'payments');

    expect(followed.outcome, 'APPLIED');
    expect(project.following?.commit, followed.commit);
    expect(project.canBeActedOn, isTrue, reason: 'a followed project is one work can start in');
  });

  test('an unsigned commit is refused, needs a person, and is not in force', () async {
    await machineIn('work');
    final client = await connect();

    final followed = await client.follow('ledger', 'file:///srv/git/unsigned-ledger', unverified: true);

    expect(followed.outcome, 'NOT_SIGNED');
    expect(followed.needsAPerson, isTrue);
    expect(followed.inForce, isFalse);
  });

  test('asking for the enforcement it already has is not reported as a change', () async {
    await machineIn('work');
    final client = await connect();

    final first = await client.setClearance('porelo-billing-audit', 'off');

    expect(first.outcome, 'UNCHANGED');
    expect(first.settled, isTrue);
    // Empty when nothing changed, exactly as the contract says.
    expect(first.now, isEmpty);
  });

  test('taking back a name that was never granted changes nothing', () async {
    await machineIn('work');
    final client = await connect();

    final said = await client.narrowTask('porelo-checkout-shell', <String>['never.granted.test'], scope: Scope.run);

    expect(said.outcome, WidenOutcome.noChange);
  });

  test('taking a name back from the project reaches the project file', () async {
    await machineIn('work');
    final client = await connect();
    await client.widenTask('porelo-checkout-shell', <String>['files.example.test'], scope: Scope.runAndProject);

    final said = await client.narrowTask('porelo-checkout-shell', <String>[
      'files.example.test',
    ], scope: Scope.runAndProject);

    // The scope went out as the contract spells it; its Dart name was read as run-only once.
    expect(said.outcome, WidenOutcome.narrowed);
    expect(said.persisted, isTrue, reason: 'RUN_AND_PROJECT was asked for');
  });

  test('a build streams its steps and names the depth it used', () async {
    await machineIn('work');
    final client = await connect();

    final replies = await client.prepare('checkout', rebuild: 'AGENT').toList();

    expect(replies.where((each) => each.line != null), isNotEmpty);
    final result = replies.last;
    expect(result.built, isTrue);
    // Read back rather than assumed: a depth the daemon did not recognize has to be visible.
    expect(result.rebuild, 'AGENT');
  });

  test('what a task holds is three answers, and a wrong name is none of them', () async {
    await machineIn('work');
    final client = await connect();

    final running = await client.workHeld('porelo-checkout-shell');
    expect(running.readable, isTrue);
    // Current, so no instant: "holds" rather than "held".
    expect(running.current, isTrue);
    expect(running.holdsSomething, isTrue);

    final unreadable = await client.workHeld('porelo-checkout-tests');
    // Not "holds nothing": nobody could look.
    expect(unreadable.readable, isFalse);
    expect(unreadable.holdsSomething, isFalse);

    final stopped = await client.workHeld('porelo-checkout-migrate');
    expect(stopped.readable, isTrue);
    expect(stopped.current, isFalse, reason: 'a stopped task answers as of when it stopped');
    expect(stopped.asOf, isNotNull);

    // A name that is no task is a refusal, never an unreadable answer — collapsing them makes a
    // client's mistake arrive as a legitimate reading.
    await expectLater(
      client.workHeld('porelo-never-existed'),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'NoSuchTask')),
    );
  });

  test('a node says which node it is, and says the same thing twice', () async {
    await machineIn('work');
    final client = await connect();

    final first = await client.node();
    final second = await client.node();

    // Stable is the whole property: an id that changed between calls would report one node as
    // two, which is the failure it exists to prevent arriving backwards.
    expect(first, isNotEmpty);
    expect(second, first);
  });

  test('a deletion previews without removing, and names what it keeps', () async {
    await machineIn('work');
    final client = await connect();

    final would = await client.unfollow('billing', dryRun: true);

    expect(would.outcome, DeleteOutcome.previewed);
    expect(would.removes.map((each) => each.kind), contains('MIRROR'));
    // The operator's own file, named by the contract rather than worked out by a client — which
    // is what lets a confirmation say it survives.
    expect(would.keeps, contains('/srv/billing/project.yml'));

    // Nothing went: the project is still listed and its work is still there.
    expect((await client.projects()).map((each) => each.name), contains('billing'));
  });

  test('unreviewed work refuses a deletion, and force is what goes past it', () async {
    await machineIn('work');
    final client = await connect();

    final refused = await client.unfollow('checkout');

    expect(refused.outcome, DeleteOutcome.holdsWork);
    expect(refused.unreviewed, isNotEmpty);
    expect((await client.projects()).map((each) => each.name), contains('checkout'));

    final forced = await client.unfollow('checkout', force: true);

    expect(forced.outcome, DeleteOutcome.deleted);
    expect((await client.projects()).map((each) => each.name), isNot(contains('checkout')));
  });

  test('a project nothing knows is a named outcome, never an exception', () async {
    await machineIn('work');
    final client = await connect();

    final answer = await client.unfollow('never-existed');

    expect(answer.outcome, DeleteOutcome.noSuchProject);
    expect(answer.removes, isEmpty);
  });

  test('which logs a task has is asked, and an empty answer is normal', () async {
    await machineIn('work');
    final client = await connect();

    final found = await client.logsOf('porelo-checkout-shell');

    expect(found.map((log) => log.name), containsAll(<String>['agent.log', 'gate.log']));
    expect(found.first.bytes, greaterThan(0));
    // The name goes to Tail unchanged; it is a file name and never a path.
    expect(await client.tailLog('porelo-checkout-shell', found.first.name).first, isNotEmpty);
  });

  test('a log whose name is not .log is offered and reads like any other', () async {
    await machineIn('work');
    final client = await connect();

    final found = await client.logsOf('porelo-checkout-shell');
    final names = found.map((log) => log.name).toList();

    // **The file somebody needs when a task starts and then does nothing** is the firewall's
    // record, and its name says nothing about that. A suffix rule at this end would hide exactly
    // it, so the wire is asserted on a name that would not survive one.
    expect(names, contains('events.jsonl'));
    expect(await client.tailLog('porelo-checkout-shell', 'events.jsonl').first, isNotEmpty);

    // And an empty one is still a log: a size rule would hide it as surely as a suffix rule.
    final empty = found.firstWhere((log) => log.name == 'reader.err');
    expect(empty.bytes, 0);
    expect(names, contains('reader.err'));

    // The sentence that makes the name findable comes from the machine, for exactly the files
    // whose names say nothing — and is absent, not blank, for the ones that speak for themselves.
    expect(found.firstWhere((log) => log.name == 'events.jsonl').what, contains('firewall'));
    expect(empty.what, isNotNull);
    expect(found.firstWhere((log) => log.name == 'agent.log').what, isNull);
  });

  test('a launch streams its lines and then its result', () async {
    await machineIn('failing-start');
    final client = await connect();

    final progress = await client.start(dryRun: true).toList();

    expect(progress.where((step) => step.line != null), isNotEmpty);
    expect(progress.last.isResult, isTrue);
    expect(progress.last.exitCode, 1);
  });

  test('an enrolled device opens a shut store, and a revoked one no longer does', () async {
    await machineIn('work');
    final client = await connect();
    final share = newShare();

    final enrolled = await client.enrollDevice(name: 'laptop', share: share, storage: KeyslotStorage.userScoped);
    expect(enrolled.outcome, KeyslotOutcome.enrolled);
    final id = enrolled.slot!.id;
    expect((await client.keyslots()).map((slot) => slot.id), <String>['slot-0', id]);

    await client.lock();
    final opened = await client.unlockWithShare(share: share);
    expect(opened.outcome, KeyslotOutcome.unlocked);
    expect(opened.until, isEmpty, reason: 'no bound was asked for');
    expect((await client.credentials()).readable, isTrue);
    expect((await client.keyslots()).singleWhere((slot) => slot.self).id, id);

    expect((await client.revokeKeyslot(id)).outcome, KeyslotOutcome.revoked);
    await client.lock();
    expect((await client.unlockWithShare(share: share)).outcome, KeyslotOutcome.shareRejected);
    expect((await client.credentials()).readable, isFalse);
  });

  test('a share for a store that is already open re-arms the bound rather than being refused', () async {
    // Measured on the daemon: the unlock reads the vault again and
    // replaces what is cached, so asking for another hour is expressible. There is no outcome for
    // "it was open already", and this build carried one until that was measured.
    await machineIn('work');
    final client = await connect();
    final share = newShare();
    await client.enrollDevice(name: 'laptop', share: share, storage: KeyslotStorage.userScoped);
    await client.lock();

    expect((await client.unlockWithShare(share: share, minutes: 30)).outcome, KeyslotOutcome.unlocked);
    final again = await client.unlockWithShare(share: share, minutes: 60);
    expect(again.outcome, KeyslotOutcome.unlocked, reason: 'an open store is opened again, not refused');
    expect(again.until, isNotEmpty, reason: 'the new bound is what the second call is for');
  });

  test('a shut store enrolls nothing, and a share it never saw opens nothing', () async {
    await machineIn('work');
    final client = await connect();
    final share = newShare();
    await client.lock();

    final refused = await client.enrollDevice(name: 'laptop', share: share, storage: KeyslotStorage.userScoped);
    expect(refused.outcome, KeyslotOutcome.vaultLocked);
    expect(await client.keyslots(), hasLength(1));

    await client.unlockWithShare(share: share);
    expect((await client.credentials()).readable, isFalse, reason: 'an unenrolled share opened it');
  });
}
