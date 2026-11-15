import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/connections.dart' show inTheLoginShell;
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/host_forge_token.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

/// A host an organization's card names, reached by the card's own ssh login.
final _orchard = Machine.fromHostCard(
  HostCardSsh(
    name: 'orchard',
    address: 'orchard.example.org',
    sshPort: 22,
    hostKey: _key,
    login: 'hana',
    publicKey: _key,
  ),
  socketPath: '/tmp/orchard.sock',
  sshConfig: '/tmp/orchard.config',
);

/// What the machine refuses the pull requests with, naming its own command.
final _missing = MissingHostForgeToken(
  const VarlinkException('org.fuin.porelo.Tasks1.MissingHostForgeToken', <String, dynamic>{
    'credential': 'orchard.localhost.person',
    'storeCommand': ['porelo', 'host', 'forge-token'],
  }),
);

void main() {
  late Desk before;
  setUp(() {
    before = desk;
    desk = Desk.of('linux', const {});
  });
  tearDown(() => desk = before);

  // Harm: the token is minted on another account or as root, or the window puts words of its own into the line.
  test("the line is the machine's own command, over the card's own login, with no terminal", () {
    final line = HostForgeTokens.commandFor(_orchard, _missing)!;
    expect(line, [
      'ssh',
      '-F',
      '/tmp/orchard.config',
      '-o',
      'ControlMaster=no',
      '-o',
      'ProxyCommand=false',
      'orchard',
      inTheLoginShell('porelo host forge-token'),
    ]);
    expect(line.any((word) => word.contains('root')), isFalse, reason: 'never as root');
    expect(HostForgeTokens.commandFor(Machine.local(), _missing), isNull, reason: 'never on this computer');
  });

  // Harm: two runs at once mint two tokens, the second revoking the first while the first is still being stored.
  test('a press while a run stores the token joins it, and nothing runs twice', () async {
    final held = Completer<({int code, String said})>();
    var runs = 0;
    final tokens = HostForgeTokens((command) {
      runs++;
      return held.future;
    });
    addTearDown(tokens.dispose);
    final first = tokens.store(_orchard, _missing);
    final second = tokens.store(_orchard, _missing);
    tokens.heard(_orchard, _missing);
    expect(tokens.running('orchard'), isTrue);
    held.complete((code: 0, said: ''));
    expect(await first, isNull);
    expect(await second, isNull);
    expect(runs, 1);
    expect(tokens.running('orchard'), isFalse);
  });

  // Harm: the window stores by itself again and again, each run revoking the token before.
  test('a missing token is stored by itself once per machine, a failed run included', () async {
    var runs = 0;
    final tokens = HostForgeTokens((command) async {
      runs++;
      return (code: 69, said: 'porelo: the host answered no valid forge token');
    });
    addTearDown(tokens.dispose);
    tokens.heard(_orchard, _missing);
    await pumpEventQueue();
    tokens.heard(_orchard, _missing);
    await pumpEventQueue();
    expect(runs, 1);
    expect(tokens.failed('orchard'), 'porelo: the host answered no valid forge token');
  });

  // Harm: a run that failed reads as stored, or one that said nothing reads as nothing at all.
  test("a failed run answers the command's own last line, or its exit code where it said nothing", () async {
    final silent = HostForgeTokens((command) async => (code: 65, said: ''));
    addTearDown(silent.dispose);
    expect(await silent.store(_orchard, _missing), 'Storing the forge token ended with exit code 65.');
    final stored = HostForgeTokens((command) async => (code: 0, said: ''));
    addTearDown(stored.dispose);
    expect(await stored.store(_orchard, _missing), isNull);
    expect(stored.failed('orchard'), isNull);
  });
}
