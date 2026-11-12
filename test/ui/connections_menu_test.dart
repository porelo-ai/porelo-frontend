import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/client/models.dart';
import 'package:porelo_frontend/src/ui/connections_view.dart';

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
}
