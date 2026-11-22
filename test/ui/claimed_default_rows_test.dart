import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/ui/claimed_default_rows.dart';

/// A machine's `default`, as its Porelo lists it, and every LeaveDefault asked of it.
class _Default extends Fake implements FleetBackend {
  _Default(this.repositories, {this.named});

  List<DefaultRepository> repositories;

  /// What NamedDefaultRepositories answers; null for a Porelo without it.
  List<NamedDefaultRepository>? named;

  /// Each repository asked to leave `default`, in order.
  final left = <String>[];

  /// What the machine answers LeaveDefault with instead of taking it out, or null.
  Exception? refusal;

  @override
  Future<List<DefaultRepository>> defaultRepositories() async => repositories;

  @override
  Future<List<NamedDefaultRepository>> namedDefaultRepositories() async =>
      named ?? (throw const FeatureNotSupported('NamedDefaultRepositories'));

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> leaveDefault(String name) async {
    left.add(name);
    if (refusal case final refused?) throw refused;
    repositories = [
      for (final each in repositories)
        if (each.name != name) each,
    ];
    named = named == null
        ? null
        : [
            for (final each in named!)
              if (each.name != name) each,
          ];
    return (removed: true, keys: const <MachineDeployKey>[]);
  }
}

DefaultRepository _repository(String name, {String claimedBy = ''}) =>
    DefaultRepository(name: name, upstream: 'git@forge.example.org:acme/$name.git', checkout: '', claimedBy: claimedBy);

NamedDefaultRepository _named(String name, String project) => NamedDefaultRepository(
  name: name,
  upstream: 'git@forge.example.org:acme/$name.git',
  project: project,
  projectRepository: '$name-service',
  removal: 'porelo project default remove $name',
);

void main() {
  Future<void> show(WidgetTester tester, _Default machine) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClaimedDefaultRows(machines: [(name: 'laptop', backend: machine)])),
      ),
    );
    await tester.pumpAndSettle();
  }

  final offer = find.byKey(const ValueKey<String>('default-leave laptop/checkout'));
  final confirm = find.byKey(const Key('default-leave-confirm'));

  // Harm: a repository a project now names stays in Default unseen, and the person cannot tell why its next task
  // starts elsewhere, or where to take it out.
  testWidgets('a repository of Default a project names is offered for leaving, saying where its next task starts', (
    tester,
  ) async {
    await show(tester, _Default([_repository('checkout', claimedBy: 'payments'), _repository('notes')]));

    final row = find.byKey(const ValueKey<String>('default-claimed laptop/checkout'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('next task starts in payments')), findsOneWidget);
    expect(offer, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('default-claimed laptop/notes')), findsNothing, reason: 'named by none');
  });

  // Harm: one click takes a repository out of Default, or a second click asks twice.
  testWidgets('leaving is asked once, sent once, and said', (tester) async {
    final machine = _Default([_repository('checkout', claimedBy: 'payments')]);
    await show(tester, machine);

    await tester.tap(offer);
    await tester.pumpAndSettle();
    expect(machine.left, isEmpty, reason: 'asked first');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(machine.left, ['checkout']);
    expect(find.textContaining('checkout is out of Default on laptop'), findsOneWidget);
    expect(offer, findsNothing);
  });

  // Harm: a refusal while a task works on it is lost, and the person thinks it left.
  testWidgets("a refusal is said in place, in the machine's terms", (tester) async {
    final machine = _Default([_repository('checkout', claimedBy: 'payments')])
      ..refusal = const VarlinkException('org.fuin.porelo.Tasks1.DefaultRepositoryInUse', {
        'name': 'checkout',
        'tasks': ['porelo-default_checkout'],
      });
    await show(tester, machine);

    await tester.tap(offer);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    final said = tester.widget<Text>(find.byKey(const ValueKey<String>('default-left laptop/checkout'))).data;
    expect(said, allOf(contains('porelo-default_checkout'), contains('stays in Default')));
    expect(offer, findsOneWidget);
  });

  // Harm: Default itself, or a repository nobody names, is offered for removal from the work page.
  testWidgets('nothing is shown where no project names a repository of Default', (tester) async {
    await show(tester, _Default([_repository('notes')]));

    expect(find.byType(ListTile), findsNothing);
  });

  // Harm: a repository an organization's project names, though not placed on this machine, stays in Default unseen;
  // or the person cannot tell which repository of that project it is, or how to take it out at a terminal.
  testWidgets("a repository the organization's project names is offered with that project's key and the command", (
    tester,
  ) async {
    final machine = _Default([_repository('checkout'), _repository('notes')], named: [_named('checkout', 'payments')]);
    await show(tester, machine);

    final row = find.byKey(const ValueKey<String>('default-claimed laptop/checkout'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.textContaining('payments names it now as checkout-service')),
      findsOneWidget,
    );
    expect(
      tester.widget<SelectableText>(find.byKey(const ValueKey<String>('default-removal laptop/checkout'))).data,
      'At a terminal: porelo project default remove checkout',
    );
    expect(find.byKey(const ValueKey<String>('default-claimed laptop/notes')), findsNothing, reason: 'named by none');

    await tester.tap(offer);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(machine.left, ['checkout']);
    expect(find.textContaining('its next task starts in payments'), findsOneWidget);
    expect(offer, findsNothing);
  });

  // Harm: a placed project's claim the organization no longer makes is offered again, against what the machine lists.
  testWidgets("where the machine lists the organization's names, its list alone is offered", (tester) async {
    await show(tester, _Default([_repository('checkout', claimedBy: 'payments')], named: const []));

    expect(find.byType(ListTile), findsNothing);
  });
}
