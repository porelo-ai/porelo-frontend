import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/client/models.dart';
import 'package:porelo_frontend/src/ui/connections_view.dart';

/// Connections whose reading the test turns on and off, as a read or a change does.
class _Turning extends Connections {
  void turn({required bool busy}) {
    this.busy = busy;
    notifyListeners();
  }
}

/// Adding and forgetting a connection stand in the view's menu, offered only while they can be done.
void main() {
  Future<Map<String, bool>> offered(WidgetTester tester, {bool busy = false, bool stale = false}) async {
    final connections = Connections()
      ..machine = 'laptop'
      ..read = true
      ..busy = busy
      ..all = const [Connection(id: 'github', kind: 'SSH_KEY', match: 'ssh://github.com')];
    final filter = TextEditingController();
    addTearDown(filter.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionsView(
            connections: connections,
            onAdd: () {},
            onForget: (_) {},
            head: (
              id: 'connections laptop',
              path: const [],
              pathKey: const Key('path'),
              notices: const [],
              stale: stale,
              filter: filter,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('connections-menu')));
    // A busy view draws a running bar, so the menu is pumped open, not settled.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return {
      for (final item in tester.widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>)))
        item.value!: item.enabled,
    };
  }

  testWidgets('both are offered while the connections stand still and are answered', (tester) async {
    expect(await offered(tester), {'add-connection': true, 'forget ssh://github.com': true});
  });

  // Harm: a second change starts while the first one still runs, and the two answers cross.
  testWidgets('neither is offered while the connections are read or changed', (tester) async {
    expect(await offered(tester, busy: true), {'add-connection': false, 'forget ssh://github.com': false});
  });

  // Harm: a connection is forgotten from a list the machine no longer answers for.
  testWidgets('forgetting is not offered while the rows are only the ones last read', (tester) async {
    expect(await offered(tester, stale: true), {'add-connection': true, 'forget ssh://github.com': false});
  });

  // An open menu follows the view: what it offered when it opened is not what it offers now.
  Future<(_Turning, List<String>)> openWhile(WidgetTester tester, {required bool busy}) async {
    final connections = _Turning()
      ..machine = 'laptop'
      ..read = true
      ..busy = busy
      ..all = const [Connection(id: 'github', kind: 'SSH_KEY', match: 'ssh://github.com')];
    final filter = TextEditingController();
    addTearDown(filter.dispose);
    final forgotten = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionsView(
            connections: connections,
            onAdd: () {},
            onForget: forgotten.add,
            head: (
              id: 'connections laptop',
              path: const [],
              pathKey: const Key('path'),
              notices: const [],
              stale: false,
              filter: filter,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('connections-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return (connections, forgotten);
  }

  bool forgetOffered(WidgetTester tester) =>
      tester.widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>).last).enabled;

  // Harm: a key's re-read ends while the menu is open, and its grey Forget does nothing when chosen.
  testWidgets('an entry greyed out when the menu opened turns runnable once the reading ends', (tester) async {
    final (connections, forgotten) = await openWhile(tester, busy: true);
    expect(forgetOffered(tester), isFalse);
    connections.turn(busy: false);
    await tester.pump();
    await tester.pump();
    expect(forgetOffered(tester), isTrue, reason: 'the open menu follows the connections');
    await tester.tap(find.textContaining('Forget ssh://github.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(forgotten, ['ssh://github.com']);
  });

  // Harm: a second change starts from a menu opened before the first one began.
  testWidgets('an entry runnable when the menu opened is greyed out once a change begins', (tester) async {
    final (connections, forgotten) = await openWhile(tester, busy: false);
    expect(forgetOffered(tester), isTrue);
    connections.turn(busy: true);
    await tester.pump();
    await tester.pump();
    expect(forgetOffered(tester), isFalse, reason: 'the open menu follows the connections');
    expect(find.textContaining('Unavailable: Still reading or changing the connections.'), findsWidgets);
    await tester.tap(find.textContaining('Forget ssh://github.com'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(forgotten, isEmpty);
  });
}
