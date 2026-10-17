import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-migrate'} holds {'jira'} for {'jira'}, granted by {'alice'} at {'2026-09-30T05:40:00Z'}
Future<void> theWorkHoldsForGrantedByAt(
  WidgetTester tester,
  String work,
  String entry,
  String destination,
  String by,
  String at,
) async {
  World.backend.publish(<Task>[
    for (final task in World.backend.tasksNow)
      task.name == work
          ? Task.from(<String, dynamic>{
              ...wire(task),
              'credentials': <String, dynamic>{entry: destination},
              'grants': <String, dynamic>{
                entry: <String, dynamic>{'grantedBy': by, 'grantedAt': at},
              },
            })
          : task,
  ]);
  await World.settle(tester);
}
