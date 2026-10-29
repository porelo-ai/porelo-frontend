import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';

void main() {
  // Harm: disclosure can navigate away, and navigation can accidentally run an action.
  testWidgets('navigation and disclosure never perform the main command', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = 0;
    var acted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpandableListRow(
            leading: const Icon(Icons.dns_outlined),
            title: 'Build machine',
            state: 'Interrupted',
            onOpen: () => opened++,
            primary: continueHostPreparationCommand(project: 'Build machine', goOn: () => acted++),
            details: const Text('Retained server details'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Build machine'));
    await tester.pump();
    expect(opened, 1, reason: 'the body opens exactly this item');
    expect(acted, 0, reason: 'opening details must not resume a rented server');
    expect(find.text('Retained server details'), findsNothing, reason: 'navigation does not disclose local controls');

    await tester.tap(find.byTooltip('Show more'));
    await tester.pump();
    expect(opened, 1, reason: 'disclosure must keep the current page');
    expect(acted, 0, reason: 'disclosure cannot resume setup');
    expect(find.text('Retained server details'), findsOneWidget, reason: 'disclosure reveals the local details');

    await tester.tap(find.byTooltip('Show less'));
    await tester.pump();
    expect(find.text('Retained server details'), findsNothing, reason: 'only disclosure closes the local details');
    expect(opened, 1, reason: 'closing disclosure cannot navigate');
    expect(acted, 0, reason: 'closing disclosure cannot run the main command');
  });

  // Harm: a command sent from the wrong row can change another machine, or bypass a refusal.
  testWidgets('primary commands act only on their own row and honor refusals', (tester) async {
    // Going on with a server's preparation is the host admin's.
    roles = Roles.fromArguments(const ['--roles', 'host-admin']);
    addTearDown(() => roles = const Roles());
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final events = <String>[];
    Widget row(String name, {String? unavailable}) => ExpandableListRow(
      key: ValueKey(name),
      leading: const Icon(Icons.dns_outlined),
      title: name,
      state: 'Interrupted',
      onOpen: () => events.add('open $name'),
      primary: continueHostPreparationCommand(
        project: name,
        goOn: () => events.add('continue $name'),
      ).unless(unavailable),
      details: const Text('Server details'),
    );
    Future<void> show(List<Widget> rows) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Column(children: rows)),
      ),
    );
    await show([row('one'), row('two'), row('busy', unavailable: 'the host command is still running')]);
    Finder button(String name) => find.descendant(of: find.byKey(ValueKey(name)), matching: find.text('Go on'));
    await tester.tap(button('two'));
    await tester.pump();
    expect(events, ['continue two'], reason: 'the second row must never act on the first machine or navigate');
    await tester.tap(button('busy'));
    await tester.pump();
    expect(events, ['continue two'], reason: 'an unavailable action cannot bypass the running command guard');
    await show([row('two'), row('one'), row('busy', unavailable: 'the host command is still running')]);
    await tester.tap(button('one'));
    await tester.pump();
    expect(events, ['continue two', 'continue one'], reason: 'reordered rows retain the correct machine command');
  });
}
