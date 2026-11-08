import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

Machine _machine({String? host, bool card = true}) => Machine.fromStored(<String, Object?>{
  'name': 'orchard',
  'kind': 'host',
  'host': host ?? 'orchard',
  'identity': '/keys/orchard.pub',
  'socket': '/sockets/orchard.sock',
  'remoteSocket': '/run/user/1001/porelo/porelod.sock',
  'sshConfig': '/config/porelo/ssh/orchard.conf',
  if (card)
    'hostCard': <String, Object?>{
      'name': 'orchard',
      'address': 'orchard.example.org',
      'ssh_port': 22,
      'host_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'login': 'alice',
      'public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'uid': 1001,
      'return_socket': '/run/porelo-host/people/alice/messenger.sock',
      'services': <String, Object?>{
        'forge': <String, Object?>{'web_port': 18080, 'git_port': 18081},
        'matrix': <String, Object?>{'port': 18082},
      },
    },
});

void main() {
  // Harm: the fetch line names a config whose Host is not the name it logs in to, so ssh skips the config's pin and
  // key; or building the line throws for a machine without a card.
  test('the config is carried only for its own Host, through a tunnel, and never on Windows', () {
    expect(reviewFetchConfig(_machine(), windows: false), '/config/porelo/ssh/orchard.conf');
    expect(reviewFetchConfig(_machine(), windows: true), isNull);
    expect(reviewFetchConfig(_machine(host: 'worker@192.0.2.7'), windows: false), isNull);
    expect(reviewFetchConfig(_machine(host: ''), windows: false), isNull);
  });

  test('a host machine without a card carries no config, and nothing throws', () {
    final machine = Machine.fromStored(<String, Object?>{
      'name': 'old',
      'kind': 'host',
      'host': 'worker@192.0.2.7',
      'socket': '/sockets/old.sock',
      'remoteSocket': '/run/user/1001/porelo/porelod.sock',
    });
    expect(reviewFetchConfig(machine, windows: false), isNull);
  });
}
