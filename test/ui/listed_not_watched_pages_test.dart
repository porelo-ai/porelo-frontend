import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';

/// A machine listed and not watched yet, as while it reconnects, is drawn by every page without an error.
void main() {
  const elsewhere = Machine(name: 'elsewhere', socketPath: '/tmp/world-elsewhere.sock');

  /// The window with a second machine whose forward is slow to come down, set to reconnect; the answer ends the wait.
  Future<Future<void> Function()> reconnecting(WidgetTester tester, {bool selected = false}) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.machines.add(elsewhere);
    await World.settle(tester);
    if (selected) World.machines.select(World.machines.all.singleWhere((each) => each.name == elsewhere.name));
    await World.settle(tester);
    final held = World.dropsHeld = Completer<void>();
    final disconnecting = World.machines.disconnect(elsewhere);
    await tester.pump();
    return () async {
      held.complete();
      await disconnecting;
      await World.settle(tester);
    };
  }

  /// What each section threw while drawn, with the machine that answers speaking meanwhile.
  Future<Map<Section, String>> drawnWhileItReconnects(WidgetTester tester, Iterable<Section> sections) async {
    final thrown = <Section, String>{};
    final staying = World.machines.all.singleWhere((each) => each.name != elsewhere.name);
    for (final section in sections) {
      World.shell.goTo(section);
      await tester.pump();
      World.machines.watching(staying)?.say('Still here.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.takeException() case final error?) thrown[section] = '$error';
    }
    return thrown;
  }

  // Harm: while a machine reconnects, every frame of a page that lists the machines threw instead of drawing it as not
  // answering, and the person saw an error where the page was.
  testWidgets('the pages that list the machines draw one that reconnects without an error', (tester) async {
    final end = await reconnecting(tester);

    final thrown = await drawnWhileItReconnects(tester, const [
      Section.work,
      Section.attention,
      Section.machines,
      Section.projects,
    ]);
    await end();

    expect(thrown, isEmpty, reason: 'a machine not watched yet is drawn as not answering, never as an error');
  });

  // Harm: the machine being acted on reconnecting threw in every frame of the window, since the whole window reads it.
  testWidgets('the selected machine reconnecting is drawn without an error', (tester) async {
    final end = await reconnecting(tester, selected: true);

    final thrown = await drawnWhileItReconnects(tester, const [Section.work, Section.machine, Section.projects]);
    await end();

    expect(thrown, isEmpty, reason: 'the selected machine not watched yet is drawn as not answering');
  });

  // Harm: a machine's page opened while the machine reconnects was never read once it was watched again, and showed
  // nothing of the machine until the person left and came back.
  testWidgets('a machine page opened while it reconnects is read once the machine is watched', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.machines.add(elsewhere);
    await World.settle(tester);
    await World.machines.disconnect(elsewhere);
    await World.settle(tester);
    final disconnected = World.machines.all.singleWhere((each) => each.name == elsewhere.name);
    final held = World.dropsHeld = Completer<void>();
    final reconnecting = World.machines.reconnect(disconnected);
    await tester.pump();
    World.shell.choosePlace(ShellPlace(Section.machine, machine: disconnected, machineSection: MachineSection.health));
    await tester.pump();
    await tester.pump();
    final before = World.elsewhere.healthAsked;

    held.complete();
    await reconnecting;
    await World.settle(tester);

    expect(World.elsewhere.healthAsked, greaterThan(before), reason: 'the page asks the machine once it is watched');
  });
}
