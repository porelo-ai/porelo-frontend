import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart' show HostIdentityVaultShut;

import '../features/support/world.dart';

void main() {
  // Harm: the list of hosts whose identity this computer's vault keeps goes stale, so give-up is offered for a host
  // already given up, or refused for one just kept, until the window starts again.
  testWidgets('a refresh by hand reads the kept identities again, also after a read that failed', (tester) async {
    await World.startBackend(const []);
    await World.startApp(tester);
    await World.settle(tester);
    World.here.identityFailure = const HostIdentityVaultShut();
    final before = World.here.identityListsAsked;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await World.settle(tester);
    expect(World.here.identityListsAsked, greaterThan(before));

    World.here.identityFailure = null;
    final failed = World.here.identityListsAsked;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await World.settle(tester);
    expect(World.here.identityListsAsked, greaterThan(failed), reason: 'a failed read is tried again');
  });
}
