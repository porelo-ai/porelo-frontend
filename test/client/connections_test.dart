// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// How a machine connects out, over a real socket against the stand-in: the description travels,
/// the value never does, and the command that stores it is the machine's, as arguments.
void main() {
  late MockDaemon daemon;
  late MockMachine machine;

  Future<PoreloClient> connect() =>
      PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    machine = MockMachine(daemon, situation: 'work', pace: Duration.zero);
  });

  tearDown(() async {
    await machine.close();
    await daemon.stop();
  });

  test('declaring a key in the vault answers the command that stores it, and what it reads', () async {
    final client = await connect();

    final declared = await client.credentialDeclare(kind: 'SSH_KEY', match: 'git@gitlab.example:acme/x.git');

    expect(declared.connection.match, 'ssh://gitlab.example/acme/x.git', reason: 'normalized by the machine');
    expect(declared.storeCommand, <String>['porelo', 'vault', 'put', 'git.ssh.gitlab.example']);
    expect(declared.storeStdin, 'the private key file', reason: 'a key is a file, not a prompt');
    expect(declared.replaced, isFalse);
  });

  test('declaring the same address and purpose again replaces it, and says so', () async {
    final client = await connect();
    await client.credentialDeclare(kind: 'TOKEN', match: 'https://gitlab.example/acme/');

    final again = await client.credentialDeclare(kind: 'TOKEN', match: 'https://gitlab.example/acme/');

    expect(again.replaced, isTrue);
    expect(again.storeStdin, isEmpty, reason: 'a token is asked for at the prompt');
  });

  test('connections are listed with the store shut, and forgetting says what still holds the value',
      () async {
    final client = await connect();
    await client.credentialDeclare(kind: 'TOKEN', match: 'https://gitlab.example/acme/');

    final store = await client.credentials();
    expect(store.connections.map((each) => each.match), contains('https://gitlab.example/acme/'));

    final forgotten = await client.credentialForget('https://gitlab.example/acme/');
    expect(forgotten.forgotten, isTrue);
    expect(forgotten.leftBehind, contains('git.token.gitlab.example'));
  });

  test('a check answers without following: a local path needs nothing, an unknown host has nothing',
      () async {
    final client = await connect();

    expect((await client.credentialCheck('/home/somebody/repo')).outcome, 'NOT_NEEDED');
    expect((await client.credentialCheck('git@nowhere.example:a/b.git')).outcome, 'NO_CREDENTIAL');
    final github = await client.credentialCheck('git@github.com:porelo-ai/porelo-project.git');
    expect(github.connection.id, 'git.ssh.github.com', reason: 'the longest match it has');
  });

  test('the keys a machine has are described, never read out, each saying what stands in its way',
      () async {
    final client = await connect();

    final keys = await client.sshKeys();

    expect(keys.map((each) => each.path), contains('/home/somebody/.ssh/id_ed25519'));
    final signs = keys.firstWhere((each) => each.path.endsWith('id_ed25519'));
    expect(signs.usable && signs.privateHalf && signs.obstacle.isEmpty, isTrue);
    final configured = keys.firstWhere((each) => each.found == 'CONFIGURED');
    expect(configured.encrypted, isTrue);
    expect(configured.obstacle, contains('ssh-keygen -p'));
    final publicOnly = keys.firstWhere((each) => each.path.endsWith('company_key'));
    expect(publicOnly.servesWhereItLies, isFalse, reason: 'ssh signs with the private file');
  });

  test('a command for another machine goes over ssh, each word quoted for its shell', () {
    const remote = Machine(name: 'vm', socketPath: '/tmp/x.sock', host: 'alice@vm', remoteSocket: '/run/s.sock');
    const elsewhere = Machine(name: 'forwarded', socketPath: '/tmp/y.sock');

    expect(onTheMachine(remote, <String>['porelo', 'vault', 'put', 'a b'], terminal: true),
        <String>['ssh', '-t', 'alice@vm', r'exec "${SHELL:-/bin/sh}" -lc ' r"'porelo vault put '\''a b'\'''"]);
    expect(onTheMachine(remote, <String>['porelo', 'vault', 'put', 'k'], terminal: false),
        <String>['ssh', 'alice@vm', r'exec "${SHELL:-/bin/sh}" -lc ' r"'porelo vault put k'"],
        reason: 'a command fed on standard input must not have a terminal');
    expect(onTheMachine(elsewhere, <String>['porelo'], terminal: true), isNull,
        reason: 'a socket somebody else forwards has no machine here to run it on');
    expect(quoteForAShell("it's"), r"'it'\''s'");
  });

  test('a command on a machine runs in its login shell, so the account finds its own porelo', () {
    // A command over ssh gets no login shell and no ~/.local/bin, and so the machine-wide porelo.
    expect(inTheLoginShell('porelo task attach w'), r'exec "${SHELL:-/bin/sh}" -lc ' r"'porelo task attach w'");
    const remote = Machine(name: 'vm', socketPath: '/tmp/x.sock', host: 'alice@vm', remoteSocket: '/run/s.sock');
    expect(onTheMachineAsWritten(remote, "porelo vault put 'my key'"),
        <String>['ssh', '-t', 'alice@vm', r'exec "${SHELL:-/bin/sh}" -lc ' r"'porelo vault put '\''my key'\'''"]);
  });
}
