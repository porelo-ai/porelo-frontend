import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

/// Which machines are this computer's own daemon.
///
/// The harm: on Windows, where there is no local daemon and its socket reads as `''`, every WSL
/// distribution, also `''`, counted as this computer. A silent one never showed under *Needs you*,
/// and *Start Porelo* ran `sh` on Windows.
void main() {
  test('a WSL distribution is never this computer, whatever socket it was stored with', () {
    for (final socket in <String>['', Backend.local().socketPath]) {
      final distribution = Machine(name: 'ubuntu', socketPath: socket, kind: 'wsl', distribution: 'Ubuntu');
      expect(distribution.isThisComputer, isFalse, reason: 'stored with socket "$socket"');
      expect(distribution.canBeStartedHere, isFalse, reason: 'stored with socket "$socket"');
    }
  });

  test("a machine with no socket at all is not this computer's own", () {
    expect(const Machine(name: 'blank', socketPath: '').isThisComputer, isFalse);
  });
}
