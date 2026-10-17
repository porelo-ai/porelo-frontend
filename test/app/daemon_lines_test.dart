import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

/// The lines that start and stop a daemon run in the account's login shell, so they find the
/// account's own `porelod` after `deploy --account`, and never ask for anything.
void main() {
  const vm = Machine(name: 'vm', socketPath: '/tmp/vm.sock', host: 'agent@vm', remoteSocket: '/run/s.sock');

  test('starting runs its line in the login shell, never waiting on a prompt', () {
    expect(Tunnels.startCommandFor(vm), <String>[
      'ssh', '-n', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', 'agent@vm',
      inTheLoginShell(Tunnels.startsIt),
    ]);
  });

  test('stopping runs its line in the login shell, never waiting on a prompt', () {
    expect(Tunnels.stopCommandFor(vm), <String>[
      'ssh', '-n', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', 'agent@vm',
      inTheLoginShell(Tunnels.stopsIt),
    ]);
  });

  test('stopping asks systemd first and stops only this account\'s own daemon otherwise', () {
    expect(Tunnels.stopsIt, contains('systemctl --user stop porelod'));
    expect(Tunnels.stopsIt, contains(r'pgrep -u "$(id -u)" -x porelod'));
  });
}
