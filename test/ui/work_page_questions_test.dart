import 'package:flutter_test/flutter_test.dart';

import '../features/support/world.dart';

/// Questions for work a machine does not list yet, on the Work page.
///
/// The harm: two such questions on one machine gave their tiles one key between them, and the
/// frame threw "Duplicate GlobalKey" in place of showing either.
void main() {
  testWidgets('two questions for work not listed yet show as two tiles', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);

    World.backend.asking
      ..add(World.blocked('files.example.test:22', task: 'porelo-ghost-one'))
      ..add(World.blocked('files.example.test:22', task: 'porelo-ghost-two'));
    await World.settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('porelo-ghost-one'), findsWidgets);
    expect(find.textContaining('porelo-ghost-two'), findsWidgets);
  });
}
