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
  'uid': 1001,
  'return_socket': '/run/porelo-host/people/alice/messenger.sock',
  'services': {
    'forge': {'web_port': 18080, 'git_port': 18081},
    'matrix': {'port': 18082},
  },
};

void main() {
  // Prevents untrusted card values from injecting SSH directives, selecting identities or escaping paths.
  for (final change in <String, Object?>{
    'name': 'Alpha',
    'address': 'alpha\nProxyCommand bad',
    'ssh_port': '22',
    'host_key': '$publicKey\nHost *',
    'login': 'alice/root',
    'public_key': 'ssh-ed25519 AAAA',
    'uid': 0,
    'return_socket': '/run/porelo-host/people/bob/messenger.sock',
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

  test('refuses return socket traversal and nested endpoints', () {
    for (final suffix in ['../bob/m.sock', 'other/m.sock', '.', '..', 'm.sock\n']) {
      expect(
        () => HostCardSsh.fromStored({...cardValues(), 'return_socket': '/run/porelo-host/people/alice/$suffix'}),
        throwsException,
        reason: suffix,
      );
    }
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
    final config = '${folder.path}/alpha.conf';
    final card = HostCardSsh.fromStored(cardValues());
    await card.publish(config);
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
    final config = '${folder.path}/alpha.conf';
    final card = HostCardSsh.fromStored(cardValues());
    await card.publish(config);
    final before = File('$config.known_hosts').readAsStringSync();
    final changed = HostCardSsh.fromStored({
      ...cardValues(),
      'host_key': publicKey.replaceFirst('AAAAIAAA', 'AAAAIBAA'),
    });
    await expectLater(changed.publish(config), throwsA(isA<HostFilesRefused>()));
    expect(File('$config.known_hosts').readAsStringSync(), before);
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
    await expectLater(card.publish('${root.path}/alias/new/alpha.conf'), throwsA(isA<HostFilesRefused>()));
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
