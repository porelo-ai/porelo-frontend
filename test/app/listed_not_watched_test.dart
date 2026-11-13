import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/notifications.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/where_you_were.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_frontend/src/ui/planning_reports.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

class _Silent extends FakeBackend {
  _Silent() : super(const []);

  @override
  Future<ServiceInfo> open() => throw const VarlinkDisconnected('nothing there');
}

/// Holds a machine's forward down until [let] completes, as a slow ssh does.
class _SlowDrop extends FakeTunnels {
  final Completer<void> let = Completer<void>();

  /// What taking a forward down throws, as an ssh that fails; null where it goes.
  Object? dropFails;

  /// What saving the host cards throws; null where they are saved.
  Object? cardsFail;

  @override
  Future<void> dropAndUnpublish(Machine machine) async {
    await let.future;
    if (dropFails case final failure?) throw failure;
    await super.dropAndUnpublish(machine);
  }

  /// Holds every forward's raising until it completes; null raises at once.
  Completer<void>? raiseHeld;

  @override
  Future<bool> raiseFor(Machine machine) async {
    await raiseHeld?.future;
    return super.raiseFor(machine);
  }

  @override
  FutureOr<void> replaceCards(Iterable<Machine> machines) {
    if (cardsFail case final failure?) throw failure;
    return super.replaceCards(machines);
  }
}

/// Records every error a listener threw, which a notifier reports rather than passes on.
List<FlutterErrorDetails> _reported() {
  final reported = <FlutterErrorDetails>[];
  final before = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = before);
  return reported;
}

void main() {
  // Harm: every start of a window whose saved machines list a host card before another machine threw while what
  // needs a person was worked out, as the card's connection spoke before the machine after it was opened.
  test('a card saved before another machine opens without an error, and the other one still asks', () async {
    final reported = _reported();
    final card = Machine.fromHostCard(
      HostCardSsh(
        name: 'build',
        address: 'build.example.org',
        sshPort: 22,
        hostKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        login: 'hana',
        publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      ),
      socketPath: '/tmp/build.sock',
      sshConfig: '/tmp/build.config',
    );
    const other = Machine(name: 'apple', socketPath: '/tmp/apple.sock');
    final asking = FakeBackend([
      Task.from(<String, dynamic>{
        'name': 'porelo-checkout-shell',
        'project': 'checkout',
        'running': true,
        'mode': 'SHELL',
        'activity': 'WAITING',
        'waitingFor': 'api.example.test:443',
        'since': '2026-09-07T14:59:00Z',
      }),
    ]);
    final settings = Settings(MemorySettingsStore());
    await settings.rememberMachines([card, other]);
    final machines = Machines(
      settings,
      reach: (machine) => machine.hostCard != null ? _Silent() : asking,
      tunnels: FakeTunnels(),
    );
    final attention = Attention(machines);
    addTearDown(() {
      attention.dispose();
      machines.dispose();
      settings.dispose();
    });

    await machines.load();
    for (final machine in machines.all) {
      await machines.of(machine).untilAsked();
    }
    await pumpEventQueue();
    expect(reported.map((each) => each.exceptionAsString()), isEmpty, reason: 'nothing may throw while machines open');
    expect(
      [for (final tile in attention.needing) '${tile.machine.name}/${tile.task?.name}'],
      ['apple/porelo-checkout-shell'],
      reason: 'the machine that answers still says what it asks',
    );
  });

  // Harm: a machine set to reconnect is listed and not watched while its forward comes down, and another machine
  // speaking then threw in every listener that walks the machines, among them the one raising its questions.
  test('another machine speaking while one reconnects raises nothing in what follows the machines', () async {
    final reported = _reported();
    final window = await _reconnecting();
    final attention = Attention(window.machines);
    final notifications = Notifications(RecordingNotifier(), window.machines.settings);
    addTearDown(() {
      notifications.dispose();
      attention.dispose();
    });
    notifications.watchMachines(window.machines, open: (_) {});

    final disconnecting = window.machines.disconnect(window.going);
    await pumpEventQueue();
    window.machines.of(window.staying).say('Still here.');
    window.tunnels.let.complete();
    await disconnecting;
    await pumpEventQueue();

    expect(reported.map((each) => each.exceptionAsString()), isEmpty, reason: 'nothing may throw while one reopens');
  });

  // Harm: the planning and a machine's own pages threw while a machine reconnects, rather than reading it as one that
  // does not answer.
  test('what reads the machines while one reconnects takes it as not answering', () async {
    final window = await _reconnecting();
    final machines = window.machines;
    final disconnecting = machines.disconnect(window.going);
    addTearDown(() async {
      if (!window.tunnels.let.isCompleted) window.tunnels.let.complete();
      await disconnecting;
    });
    await pumpEventQueue();
    final listed = machines.all.singleWhere((each) => each.name == window.going.name);

    expect(
      plannedProjects(machines),
      unorderedEquals(<String>['checkout', 'unrecorded', 'billing']),
      reason: 'the projects the machine that answers lists',
    );
    expect(
      () => plannerProjectOf(machines, 'checkout'),
      throwsA(isA<PlanningRefusal>()),
      reason: 'refused in words, as no machine here says where it is kept',
    );
    expect(
      [for (final each in projectsOnMachine(machines, listed)) each.name],
      [defaultProject],
      reason: 'a machine not watched lists only the project every machine has',
    );
    await expectLater(
      removeHandedDiscussion(machines, listed.name, 'porelo-demo-discussion'),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('not answering'))),
      reason: 'a removal that could not go is said, in words',
    );
    final source = _Source();
    expect(planningMachineOf(machines, _PathPlanner(source), source, project: 'demo'), same(machines.current));
    final starts = WindowTaskStarts.of(machines, _PathPlanner(source));
    expect(starts.machineFor('demo'), same(machines.current));
    final reports = WindowTaskReports.of(machines, _PathPlanner(source), starts);
    expect(reports.tasksOn(listed.name), isNull, reason: 'a machine not answering lists no work');
    await expectLater(reports.resultOf(listed.name, 'porelo-demo-discussion'), throwsA(isA<StateError>()));
    await expectLater(
      () => reports.stopOn(listed, 'porelo-demo-shell'),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('not answering'))),
      reason: 'a stop that could not go is said, in words',
    );
  });

  // Harm: the selected machine reconnecting threw where the window keeps where the person was, and the planning
  // handed out the selected machine, which the next call could not reach.
  test('the selected machine reconnecting is not read, and the planning finds no machine in it', () async {
    final reported = _reported();
    final window = await _reconnecting();
    final machines = window.machines;
    final shell = ShellModel();
    final whereYouWere = WhereYouWere(machines.settings, machines, shell);
    addTearDown(() {
      whereYouWere.dispose();
      shell.dispose();
    });
    await whereYouWere.restore();
    machines.select(machines.all.singleWhere((each) => each.name == window.going.name));
    final disconnecting = machines.disconnect(window.going);
    addTearDown(() async {
      if (!window.tunnels.let.isCompleted) window.tunnels.let.complete();
      await disconnecting;
    });
    await pumpEventQueue();
    machines.of(window.staying).say('Still here.');

    expect(reported.map((each) => each.exceptionAsString()), isEmpty, reason: 'nothing may throw while it reopens');
    final source = _Source();
    expect(planningMachineOf(machines, _PathPlanner(source), source, project: 'demo'), isNull);
    expect(WindowTaskStarts.of(machines, _PathPlanner(source)).machineFor('demo'), isNull);
  });

  // Harm: a caller holding a machine that reconnects - a button, a page's action - threw where it read the machine,
  // rather than meeting a machine that does not answer yet.
  test('a machine that reconnects reads as not answering, and every call on it is refused', () async {
    final window = await _reconnecting();
    final machines = window.machines;
    final disconnecting = machines.disconnect(window.going);
    addTearDown(() async {
      if (!window.tunnels.let.isCompleted) window.tunnels.let.complete();
      await disconnecting;
    });
    await pumpEventQueue();
    final listed = machines.all.singleWhere((each) => each.name == window.going.name);
    machines.select(listed);

    expect(machines.watching(listed), isNull, reason: 'it is not watched yet');
    expect(machines.of(listed).reachability, Reachability.unreachable, reason: 'it does not answer yet');
    expect(machines.fleet.reachability, Reachability.unreachable, reason: 'nor as the machine being acted on');
    expect(
      () => machines.of(listed).backend.tasks(),
      throwsA(isA<VarlinkDisconnected>()),
      reason: 'a call on it is refused as one on a machine not answering',
    );
    await machines.of(listed).connect();
    expect(machines.of(listed).reachability, Reachability.unreachable, reason: 'a try opens nothing behind its back');
  });

  // Harm: a reconnect whose forward did not come down left the machine listed and never watched again, so it
  // showed as not answering for good, whatever the machine did.
  test('a reconnect whose forward does not come down watches the machine again as it was', () async {
    final window = await _reconnecting();
    final machines = window.machines;
    window.tunnels
      ..dropFails = StateError('ssh did not answer')
      ..let.complete();

    await expectLater(machines.disconnect(window.going), throwsStateError);

    final listed = machines.all.singleWhere((each) => each.name == window.going.name);
    expect(listed.disconnected, isFalse, reason: 'it stays as it was');
    expect(machines.watching(listed), isNotNull, reason: 'and is watched again');
  });

  // Harm: a host card that could not be replaced left the window drawing the machine as not watched, since nothing
  // told it that the machine was watched again.
  test('a host card that could not be replaced tells the window the machine is watched again', () async {
    final window = await _reconnecting();
    final machines = window.machines;
    // Its forward held, so the connection of the machine watched again says nothing meanwhile.
    final raising = Completer<void>();
    addTearDown(raising.complete);
    window.tunnels
      ..cardsFail = StateError('the cards could not be saved')
      ..raiseHeld = raising;
    final told = <bool>[];
    void listen() => told.add(machines.watching(window.going) != null);
    machines.addListener(listen);
    addTearDown(() => machines.removeListener(listen));

    await expectLater(
      machines.add(const Machine(name: 'orchard', socketPath: '/tmp/orchard-2.sock', kind: 'host')),
      throwsStateError,
    );

    expect(told, isNotEmpty, reason: 'the window is told');
    expect(told.last, isTrue, reason: 'that the machine is watched again');
  });

  // Harm: what waits for a machine to answer, as the check after a start, kept the fleet a reconnect replaced and
  // never saw the machine answer again.
  test('what follows a machine is handed the fleet that watches it after a reconnect', () async {
    final window = await _reconnecting();
    final machines = window.machines;
    final seen = <FleetModel?>[];
    final stop = machines.follow(window.going, seen.add);
    addTearDown(stop);
    window.tunnels.let.complete();
    await machines.disconnect(window.going);
    final disconnected = machines.all.singleWhere((each) => each.name == window.going.name);

    await machines.reconnect(disconnected);
    await machines.watching(disconnected)!.untilAsked();
    await pumpEventQueue();

    expect(seen, contains(isNull), reason: 'while it is not watched it is handed no fleet');
    expect(seen.last, same(machines.watching(window.going)), reason: 'then the fleet watching it now');
    expect(seen.last?.reachability, Reachability.connected, reason: 'which answers');
  });

  // Harm: the stand-in of a machine not watched yet stayed what the window read once the machine was watched, or
  // stayed behind undisposed with what listened to it.
  test('once the machine is watched its own fleet is read, and the stand-in is gone', () async {
    final window = await _reconnecting();
    final machines = window.machines;
    final disconnecting = machines.disconnect(window.going);
    await pumpEventQueue();
    final listed = machines.all.singleWhere((each) => each.name == window.going.name);
    final standIn = machines.of(listed);
    expect(machines.watching(listed), isNull, reason: 'not watched yet');

    window.tunnels.let.complete();
    await disconnecting;

    final watched = machines.all.singleWhere((each) => each.name == window.going.name);
    expect(machines.of(watched), same(machines.watching(watched)), reason: 'its own fleet once it is watched');
    expect(machines.of(watched), isNot(same(standIn)), reason: 'not the stand-in');
    expect(() => standIn.addListener(() {}), throwsFlutterError, reason: 'the stand-in was disposed');
  });

  // Harm: a stored list that could not be taken in left the window drawing the machine it started with as not
  // watched, since nothing told it that the machine was watched again.
  test('a stored list that could not be taken in tells the window its machine is watched again', () async {
    final settings = Settings(MemorySettingsStore());
    await settings.load();
    await settings.rememberMachines(const [Machine(name: 'apple', socketPath: '/tmp/apple.sock')]);
    // Its forward held, so its connection says nothing meanwhile.
    final raising = Completer<void>();
    final tunnels = _SlowDrop()
      ..cardsFail = StateError('the cards could not be saved')
      ..raiseHeld = raising;
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: tunnels);
    addTearDown(() {
      raising.complete();
      machines.dispose();
      settings.dispose();
    });
    final told = <bool>[];
    machines.addListener(() => told.add(machines.all.every((each) => machines.watching(each) != null)));

    await expectLater(machines.load(), throwsStateError);

    expect(told, isNotEmpty, reason: 'the window is told');
    expect(told.last, isTrue, reason: 'that what it lists is watched again');
  });
}

/// A window watching a host and another machine, with the host's forward slow to come down.
Future<({Machines machines, _SlowDrop tunnels, Machine going, Machine staying})> _reconnecting() async {
  const going = Machine(name: 'orchard', socketPath: '/tmp/orchard.sock', kind: 'host');
  const staying = Machine(name: 'apple', socketPath: '/tmp/apple.sock');
  final settings = Settings(MemorySettingsStore());
  await settings.load();
  final tunnels = _SlowDrop();
  final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: tunnels);
  addTearDown(() {
    machines.dispose();
    settings.dispose();
  });
  await machines.add(going);
  await machines.add(staying);
  for (final machine in machines.all) {
    await machines.of(machine).untilAsked();
  }
  return (machines: machines, tunnels: tunnels, going: going, staying: staying);
}

/// The planner found on the path: a provider named as no watched machine is.
class _PathPlanner extends ChangeNotifier implements PlanningClient {
  _PathPlanner(this.source);

  final PlanningSource source;

  @override
  List<PlanningProvider> get providers => [
    PlanningProvider(name: 'porelo-planner', connected: true, projects: const ['demo'], source: source),
  ];

  @override
  String? get currentProvider => 'porelo-planner';

  @override
  String? get chosenProject => null;

  @override
  Future<void> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
  }) async {}
}

class _Source extends Fake implements PlanningSource {
  @override
  String get label => 'planner';
}
