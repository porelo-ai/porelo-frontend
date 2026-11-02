// Linux only: publication checks chmod modes, Unix sockets and the OpenSSH config parser.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

const publicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

Map<String, Object?> cardValues() => {
  'name': 'alpha',
  'address': 'alpha.example.org',
  'ssh_port': 2222,
  'host_key': publicKey,
  'login': 'alice',
  'public_key': publicKey,
  'services': {
    'forge': {'web_port': 18080, 'git_port': 18081},
    'matrix': {'port': 18082},
  },
};

void main() {
  // Prevents forwarding the signing agent through aliases before its socket exists.
  test('refuses a missing agent endpoint through a symlinked parent', () async {
    final root = await Directory.systemTemp.createTemp('a-');
    addTearDown(() => root.delete(recursive: true));
    final target = await Directory('${root.path}/target').create();
    await Link('${root.path}/alias').create(target.path);
    expect(
      () => HostCardSsh.checkMessengerSocket('${root.path}/alias/agent', agentSocket: '${target.path}/agent'),
      throwsA(isA<HostFilesRefused>()),
    );
  });

  // Prevents a hard link from exposing the signing agent to the host.
  test('refuses hard links to the agent socket', () async {
    final root = await Directory.systemTemp.createTemp('a-');
    addTearDown(() => root.delete(recursive: true));
    final agent = await ServerSocket.bind(InternetAddress('${root.path}/agent', type: InternetAddressType.unix), 0);
    addTearDown(agent.close);
    final linked = await Process.run('ln', ['--', '${root.path}/agent', '${root.path}/alias']);
    expect(linked.exitCode, 0, reason: '${linked.stderr}');
    expect(
      () => HostCardSsh.checkMessengerSocket('${root.path}/alias', agentSocket: '${root.path}/agent'),
      throwsA(isA<HostFilesRefused>()),
    );
  });

  // Prevents stored settings from restricting an unrelated directory or hiding the master from Core.
  test('refuses publication outside the platform host config directory', () async {
    final root = await Directory.systemTemp.createTemp('p-');
    addTearDown(() => root.delete(recursive: true));
    final before = root.statSync().mode;
    final card = HostCardSsh.fromStored(cardValues());
    await expectLater(card.publish('${root.path}/alpha.conf'), throwsA(isA<HostFilesRefused>()));
    expect(root.statSync().mode, before);
    expect(root.listSync(), isEmpty);
  });

  // Prevents scoped addresses from becoming SSH percent-token expansions.
  test('escapes IPv6 zone identifiers in the published SSH hostname', () async {
    final root = await Directory.systemTemp.createTemp('');
    addTearDown(() => root.delete(recursive: true));
    final card = HostCardSsh.fromStored({...cardValues(), 'address': 'fe80::1%1'});
    final environment = {'XDG_CONFIG_HOME': root.path};
    final config = card.configPath(environment: environment);
    await card.publish(config, environment: environment);
    final parsed = await Process.run('ssh', ['-F', config, '-G', card.name], environment: {'SSH_AUTH_SOCK': ''});
    expect(parsed.exitCode, 0, reason: '${parsed.stderr}');
    expect('${parsed.stdout}', contains('hostname fe80::1%'));
  });

  // Harm: ssh looks the host key up under another spelling than the card wrote, and every connection is refused.
  for (final address in ['orchard.example.org', '2001:db8::7']) {
    for (final port in [22, 2222]) {
      test('a card at $address on port $port is written as ssh reads it', () async {
        final root = await Directory.systemTemp.createTemp('');
        addTearDown(() => root.delete(recursive: true));
        final card = HostCardSsh.fromStored({...cardValues(), 'address': address, 'ssh_port': port});
        final environment = {'XDG_CONFIG_HOME': root.path};
        final config = card.configPath(environment: environment);
        await card.publish(config, environment: environment);
        final parsed = await Process.run('ssh', ['-F', config, '-G', card.name], environment: {'SSH_AUTH_SOCK': ''});
        expect(parsed.exitCode, 0, reason: '${parsed.stderr}');
        expect('${parsed.stdout}', contains('hostname $address\n'));
        expect('${parsed.stdout}', contains('port $port\n'));
        final lookup = port == 22 ? address : '[$address]:$port';
        final known = await Process.run('ssh-keygen', ['-F', lookup, '-f', '$config.known_hosts']);
        expect(known.exitCode, 0, reason: 'ssh finds the host key under $lookup');
        expect('${known.stdout}', contains('found'));
      });
    }
  }

  // Prevents untrusted card values from injecting SSH directives, selecting identities or escaping paths.
  for (final change in <String, Object?>{
    'name': 'Alpha',
    'address': 'alpha\nProxyCommand bad',
    'ssh_port': '22',
    'host_key': '$publicKey\nHost *',
    'login': 'alice/root',
    'public_key': 'ssh-ed25519 AAAA',
    'services': <String, Object?>{},
  }.entries) {
    test('refuses malformed ${change.key} before publication', () {
      expect(() => HostCardSsh.fromStored({...cardValues(), change.key: change.value}), throwsException);
    });
  }

  test('refuses repeated service ports within a host', () {
    expect(
      () => HostCardSsh.fromStored({
        ...cardValues(),
        'services': {
          'forge': {'web_port': 18080, 'git_port': 18080},
          'matrix': {'port': 18082},
        },
      }),
      throwsA(isA<HostFilesRefused>()),
    );
  });

  test('refuses every invalid DNS label without changing it', () {
    for (final name in ['', '-alpha', 'alpha-', 'alpha.beta', '../alpha', 'alpha beta', 'a' * 64]) {
      expect(() => HostCardSsh.fromStored({...cardValues(), 'name': name}), throwsException, reason: name);
    }
  });

  // Harm: the tunnel forwards another account's daemon, or lets the host write into another person's directory.
  test('the daemon and return sockets are the admitted login\'s own', () {
    final card = HostCardSsh.fromStored({...cardValues(), 'login': 'porelo-alice'});
    expect(card.daemonSocket, '/run/porelo-host/people/porelo-alice/porelod.sock');
    expect(card.returnSocket, '/run/porelo-host/people/porelo-alice/return.sock');
  });

  // Harm: a login Core would never admit reaches a host path, walking out of the person's directory.
  test('refuses a login outside Core\'s rule before it reaches a path', () {
    for (final login in [
      '',
      'Alice',
      'a_b',
      '_alice',
      '1alice',
      '-alice',
      'a' * 33,
      'alice/root',
      '../bob',
      'al ice',
    ]) {
      expect(
        () => HostCardSsh.fromStored({...cardValues(), 'login': login}),
        throwsA(isA<HostFilesRefused>()),
        reason: login,
      );
    }
    expect(HostCardSsh.fromStored({...cardValues(), 'login': 'a${'-' * 31}'}).login, 'a${'-' * 31}');
  });

  // Harm: a watched host saved with its uid and return socket is lost, or keeps a socket the host no longer serves.
  test('an older record with a uid and return socket reads, its sockets taken from the login', () {
    final card = HostCardSsh.fromStored({
      ...cardValues(),
      'uid': 1001,
      'return_socket': '/run/porelo-host/people/alice/messenger.sock',
    });
    expect(card.daemonSocket, '/run/porelo-host/people/alice/porelod.sock');
    expect(card.returnSocket, '/run/porelo-host/people/alice/return.sock');
    expect(card.stored.keys, isNot(anyOf(contains('uid'), contains('return_socket'))));
    expect(card, HostCardSsh.fromStored(cardValues()));
  });

  test('an occupied fixed port names the host and port without selecting another', () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final card = HostCardSsh.fromStored({
      ...cardValues(),
      'services': {
        'forge': {'web_port': occupied.port, 'git_port': occupied.port == 18081 ? 18084 : 18081},
        'matrix': {'port': occupied.port == 18082 ? 18085 : 18082},
      },
    });
    await expectLater(
      card.checkPortsAvailable(),
      throwsA(
        isA<HostFilesRefused>().having(
          (error) => error.message,
          'safe refusal',
          allOf(contains('alpha'), contains('${occupied.port}'), contains('busy')),
        ),
      ),
    );
    expect(occupied.address.address, '127.0.0.1');
  });

  // Harm: a tunnel started by hand on a fixed port blocks the host's own, and nobody can tell which process to end.
  test('an occupied fixed port names the program and pid that hold it', () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final card = HostCardSsh.fromStored({
      ...cardValues(),
      'services': {
        'forge': {'web_port': occupied.port, 'git_port': occupied.port == 18081 ? 18084 : 18081},
        'matrix': {'port': occupied.port == 18082 ? 18085 : 18082},
      },
    });
    await expectLater(
      card.checkPortsAvailable(holder: (port) async => port == occupied.port ? (program: 'ssh', pid: 1209613) : null),
      throwsA(
        isA<HostFilesRefused>().having(
          (error) => error.message,
          'who holds it',
          allOf(contains('held by ssh (pid 1209613)'), contains('kill 1209613')),
        ),
      ),
    );
    expect(HostCardSsh.holderIn('LISTEN 0 128 127.0.0.1:8448 0.0.0.0:* users:(("ssh",pid=1209613,fd=5))'), (
      program: 'ssh',
      pid: 1209613,
    ));
    expect(HostCardSsh.holderIn('LISTEN 0 128 127.0.0.1:8448 0.0.0.0:*'), isNull, reason: 'another account\'s');
    expect(HostCardSsh.holderIn('users:(("a\$(x)",pid=1,fd=5))'), isNull, reason: 'a name not shown as it is');
  });

  test('config paths use XDG config and Windows APPDATA', () {
    final card = HostCardSsh.fromStored(cardValues());
    expect(card.configPath(environment: {'XDG_CONFIG_HOME': '/config'}), '/config/porelo/ssh/alpha.conf');
    expect(
      card.configPath(environment: {'APPDATA': r'C:\Users\Alice\AppData\Roaming'}, windows: true),
      r'C:\Users\Alice\AppData\Roaming\porelo\ssh\alpha.conf',
    );
  });

  test('OpenSSH reads quoted config paths and the public identity without personal config', () async {
    final root = await Directory.systemTemp.createTemp('c-');
    addTearDown(() => root.delete(recursive: true));
    final folder = await Directory('${root.path}/a b').create();
    final environment = {'XDG_CONFIG_HOME': folder.path};
    final config = '${folder.path}/porelo/ssh/alpha.conf';
    final card = HostCardSsh.fromStored(cardValues());
    await card.publish(config, environment: environment);
    final parsed = await Process.run('ssh', ['-F', config, '-G', card.name], environment: {'SSH_AUTH_SOCK': ''});
    expect(parsed.exitCode, 0, reason: '${parsed.stderr}');
    expect('${parsed.stdout}', contains('hostname alpha.example.org\n'));
    expect('${parsed.stdout}', contains('identityfile $config.pub\n'));
    expect('${parsed.stdout}', contains('forwardagent no\n'));
    expect('${parsed.stdout}', contains('controlpath ${card.controlSocket(config)}\n'));
    final key = await Process.run('ssh-keygen', ['-l', '-f', '$config.pub']);
    expect(key.exitCode, 0, reason: 'OpenSSH must accept the full public identity blob');
  });

  test('changed host keys leave every published file unchanged', () async {
    final folder = await Directory.systemTemp.createTemp('p-');
    addTearDown(() => folder.delete(recursive: true));
    final environment = {'XDG_CONFIG_HOME': folder.path};
    final config = '${folder.path}/porelo/ssh/alpha.conf';
    final card = HostCardSsh.fromStored(cardValues());
    await card.publish(config, environment: environment);
    final before = File('$config.known_hosts').readAsStringSync();
    final changed = HostCardSsh.fromStored({
      ...cardValues(),
      'host_key': publicKey.replaceFirst('AAAAIAAA', 'AAAAIBAA'),
    });
    await expectLater(changed.publish(config, environment: environment), throwsA(isA<HostFilesRefused>()));
    expect(File('$config.known_hosts').readAsStringSync(), before);
  });

  // Harm: the pins of a card whose join was never confirmed stay and refuse the host's next card, or taking them down
  // deletes another card's files.
  test('unpublish removes this card\'s files and leaves another card\'s alone', () async {
    final folder = await Directory.systemTemp.createTemp('u-');
    addTearDown(() => folder.delete(recursive: true));
    final environment = {'XDG_CONFIG_HOME': folder.path};
    final config = '${folder.path}/porelo/ssh/alpha.conf';
    final card = HostCardSsh.fromStored(cardValues());
    final rotated = HostCardSsh.fromStored({
      ...cardValues(),
      'host_key': publicKey.replaceFirst('AAAAIAAA', 'AAAAIBAA'),
    });
    await card.publish(config, environment: environment);
    await rotated.unpublish(config, environment: environment);
    for (final file in [config, '$config.known_hosts', '$config.pub']) {
      expect(File(file).existsSync(), isTrue, reason: '$file holds the other card\'s pin');
    }
    await card.unpublish(config, environment: environment);
    for (final file in [config, '$config.known_hosts', '$config.pub']) {
      expect(File(file).existsSync(), isFalse, reason: file);
    }
    await rotated.publish(config, environment: environment);
    expect(File('$config.known_hosts').readAsStringSync(), contains(rotated.hostKey));
  });

  test('SSH paths refuse config injection and unexpected expansion', () async {
    final card = HostCardSsh.fromStored(cardValues());
    for (final config in [
      '/config/a\n/alpha.conf',
      '/config/"/alpha.conf',
      '/config/\$USER/alpha.conf',
      '~/alpha.conf',
    ]) {
      await expectLater(card.publish(config), throwsException, reason: config);
    }
  });

  // Prevents publication through an ancestor link into an unrelated directory.
  test('refuses symlink ancestors without creating files at their target', () async {
    final root = await Directory.systemTemp.createTemp('s-');
    addTearDown(() => root.delete(recursive: true));
    final target = await Directory('${root.path}/target').create();
    await Link('${root.path}/alias').create(target.path);
    final card = HostCardSsh.fromStored(cardValues());
    final environment = {'XDG_CONFIG_HOME': '${root.path}/alias'};
    await expectLater(
      card.publish(card.configPath(environment: environment), environment: environment),
      throwsA(isA<HostFilesRefused>()),
    );
    expect(target.listSync(), isEmpty);
  });

  // Prevents an incorrect messenger boundary from forwarding the person's local signing agent.
  test('refuses the SSH agent socket as a messenger return endpoint', () async {
    expect(
      () => HostCardSsh.checkMessengerSocket('/private/agent.sock', agentSocket: '/private/agent.sock'),
      throwsA(isA<HostFilesRefused>()),
    );
    final folder = await Directory.systemTemp.createTemp('a-');
    addTearDown(() => folder.delete(recursive: true));
    final agent = await File('${folder.path}/agent').create();
    final alias = await Link('${folder.path}/alias').create(agent.path);
    expect(
      () => HostCardSsh.checkMessengerSocket(alias.path, agentSocket: agent.path),
      throwsA(isA<HostFilesRefused>()),
    );
  });
}
