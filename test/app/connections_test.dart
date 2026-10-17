import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

/// A machine whose socket has not answered yet, as a backend refuses every call until then.
class _NotOpenYet implements FleetBackend {
  @override
  Future<VaultState> credentials() async => throw StateError('open() has not answered yet');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Found on the console: asked before the machine answered, an unhandled error.
  test('connections asked of a machine that has not answered yet say so, and throw nothing', () async {
    final connections = Connections();

    await connections.lookAt(_NotOpenYet(), 'new');

    expect(connections.problem, 'The machine has not answered yet. Ask again once it does.');
    expect(connections.busy, isFalse);
  });
}
