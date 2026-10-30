import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'host_run_test.dart' show CountingProvider, ScriptedRemote;
import 'server_contract_test.dart' show hostValues, wireGuardKey, sshKey;

class _ServerRemote extends ScriptedRemote {
  _ServerRemote(super.lines, {this.completion, super.playExit, this.hostRecord = true, this.afterHost = const []});
  final Object? completion;
  final bool hostRecord;
  final List<String> afterHost;
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    final result = await super.run(host, user, command, input: input, onLine: onLine);
    if (command.endsWith('porelo.host.up') && playExit == 0 && hostRecord) {
      onLine?.call(jsonEncode({'v': 1, 'state': 'ok', 'task': 'prepared'}));
      onLine?.call(jsonEncode({'v': 1, 'state': 'host', 'host': completion ?? hostValues()}));
      for (final line in afterHost) {
        onLine?.call(line);
      }
    }
    return result;
  }
}

/// Replays installation in a private tree, modeling root ownership without changing this machine.
class _CollectionRemote extends _ServerRemote {
  _CollectionRemote(this.root, this.owner) : super([]);

  final Directory root;
  final File owner;

  String get tree => '${root.path}/collections/ansible_collections/porelo/host';

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    final result = await super.run(host, user, command, input: input, onLine: onLine);
    if (!command.contains('ansible-galaxy collection install')) return result;
    final script = r'''
umask 077
cloud-init() { return 0; }
sudo() {
  case "$1" in
    DEBIAN_FRONTEND=noninteractive) shift; test "$1" = apt-get;;
    env)
      shift 3
      test "$1 $2 $3" = 'ansible-galaxy collection install' || return 99
      /usr/bin/mkdir -p -- "$collection_tree" && printf collection > "$collection_tree/MANIFEST.json";;
    /usr/bin/stat)
      shift
      test "$1 $2 $3 $4" = "-c %u -- $collection_root" || return 99
      /usr/bin/cat -- "$collection_owner";;
    /usr/bin/chown)
      shift
      if test "$1" = -R; then shift; fi
      test "$1" = root:root || return 99
      shift
      for directory in "$@"; do
        if test "$directory" = "$collection_root"; then printf 0 > "$collection_owner"; fi
      done;;
    /usr/bin/install)
      shift
      local arguments=()
      while test "$#" -gt 0; do
        case "$1" in
          -o|-g) test "$2" = root || return 99; shift 2;;
          *) arguments+=("$1"); shift;;
        esac
      done
      /usr/bin/install "${arguments[@]}" && printf 0 > "$collection_owner";;
    /usr/bin/chmod|/usr/bin/find|/usr/bin/test) "$@";;
    *) echo "Unexpected sudo command: $1" >&2; return 99;;
  esac
}
''';
    final installed = await Process.run(
      '/bin/bash',
      ['-c', '$script\n${command.replaceAll('/usr/share/ansible', root.path)}'],
      environment: {
        'collection_root': root.path,
        'collection_tree': tree,
        'collection_owner': owner.path,
        'PATH': '/usr/bin:/bin',
      },
      includeParentEnvironment: false,
    );
    return RemoteResult(installed.exitCode, installed.stderr as String);
  }
}

void main() {
  late Directory scratch;
  late File collection;
  late CountingProvider provider;
  late List<Step> steps;
  late List<PreparedHost> completed;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('server-run-');
    collection = await File('${scratch.path}/collection.tar.gz').writeAsString('collection fixture');
    provider = CountingProvider()
      ..rented = const RentedHost(id: 'rental', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
    steps = [];
    completed = [];
  });
  tearDown(() => scratch.delete(recursive: true));
  HostPlan plan({
    String name = 'orchard',
    int network = 7,
    String? peer,
    bool forge = true,
    String publicKey = sshKey,
  }) => HostPlan(
    hostName: name,
    network: network,
    loginUser: 'root',
    publicKey: publicKey,
    collection: collection.path,
    collectionSha256: sha256.convert(collection.readAsBytesSync()).toString(),
    vpnPeerPublicKey: wireGuardKey,
    vpnPeerAddress: peer ?? '10.73.$network.2/32',
    forge: forge,
  );
  HostRun run(Remote remote) => HostRun(
    provider: provider,
    remote: remote,
    emit: (step) {
      steps.add(step);
      if (step.state == StepState.host) completed.add(step.host!);
    },
    environment: {'XDG_STATE_HOME': scratch.path},
  );

  // Harm: valid DNS labels must not collide with project locks or Windows device names.
  // Harm: own-account plays cannot find the checked collection, or can replace root's installed code.
  test('up installs a globally readable root-owned collection and runs that same path', () async {
    final remote = _ServerRemote([]);
    expect(await run(remote).up(plan()), Exit.done);
    final install = remote.commands.singleWhere((command) => command.contains('ansible-galaxy collection install'));
    expect(install, contains('-p /usr/share/ansible/collections '));
    expect(install, contains('chown'));
    expect(install, contains('root:root'));
    expect(install, allOf(contains('0755'), contains('0644')));
    final play = remote.commands.singleWhere((command) => command.contains('ansible-playbook'));
    expect(play, contains('ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections '));
    expect(remote.commands, everyElement(isNot(contains('/var/tmp/porelo-host/collections'))));
  });

  // Harm: a writable or linked parent lets another account replace the collection root runs.
  for (final kind in ['absent', 'root-owned', 'foreign-owned', 'link', 'file']) {
    test('collection installation checks and normalizes the $kind ansible directory', () async {
      final root = Directory('${scratch.path}/ansible');
      final owner = await File('${scratch.path}/owner').writeAsString(kind == 'foreign-owned' ? '1001' : '0');
      final outside = await Directory('${scratch.path}/outside').create();
      final kept = await File('${outside.path}/keep').writeAsString('preserve');
      if (kind == 'root-owned' || kind == 'foreign-owned') {
        await root.create();
        final mode = await Process.run('/usr/bin/chmod', ['0700', root.path]);
        expect(mode.exitCode, 0, reason: mode.stderr as String);
      } else if (kind == 'link') {
        await Link(root.path).create(outside.path);
      } else if (kind == 'file') {
        await File(root.path).writeAsString('preserve');
      }
      final remote = _CollectionRemote(root, owner);
      final allowed = kind == 'absent' || kind == 'root-owned';

      expect(await run(remote).up(plan()), allowed ? Exit.done : Exit.refused);
      expect(await File('${remote.tree}/MANIFEST.json').exists(), allowed);
      expect(await kept.readAsString(), 'preserve');
      if (allowed) {
        expect(await owner.readAsString(), '0', reason: 'the parent must be root-owned');
        expect((await root.stat()).mode & 0x1ff, 0x1ed, reason: 'every account must be able to traverse the parent');
        expect((await Directory(remote.tree).stat()).mode & 0x1ff, 0x1ed);
        expect((await File('${remote.tree}/MANIFEST.json').stat()).mode & 0x1ff, 0x1a4);
      } else {
        expect(steps.last.words, contains(root.path));
        expect(remote.commands.where((command) => command.contains('ansible-playbook')), isEmpty);
        if (kind == 'foreign-owned') {
          expect(await owner.readAsString(), '1001');
          expect((await root.stat()).mode & 0x1ff, 0x1c0);
        } else if (kind == 'link') {
          expect(await Link(root.path).target(), outside.path);
        } else {
          expect(await File(root.path).readAsString(), 'preserve');
        }
      }
    });
  }

  test('server names use their own lock namespace and accept the contract boundaries', () async {
    expect(HostPlan.serverLockName('con'), 'host-con');
    for (final name in ['con', '0', 'a' * 63]) {
      for (final network in [0, 255]) {
        expect(() => plan(name: name, network: network).check(), returnsNormally);
        expect(await run(_ServerRemote([])).down(plan(name: name, network: network)), Exit.done);
      }
    }
  });

  // Harm: a later rental's SSH pin must not prevent teardown of an earlier one.
  test('down pins the provider key before uploading the inventory', () async {
    final remote = _ServerRemote([]);
    final pins = <(String, String)>[];
    final runner = HostRun(
      provider: provider,
      remote: remote,
      emit: steps.add,
      environment: {'XDG_STATE_HOME': scratch.path},
      trust: (address, key) async {
        expect(remote.commands, isEmpty);
        pins.add((address, key));
      },
    );
    expect(await runner.down(plan()), Exit.done);
    expect(pins, [('203.0.113.7', 'ssh-ed25519 AAAA')]);
  });

  // Harm: a private SSH key selected as the public half must never leave this laptop.
  test('a rental key that is not public is refused before remote work', () async {
    final remote = _ServerRemote([]);
    expect(await run(remote).up(plan(publicKey: '-----BEGIN OPENSSH PRIVATE KEY-----')), Exit.refused);
    expect(remote.commands, isEmpty);
  });

  // Harm: a root setup must not create a project account or install a project key.
  for (final forge in [true, false]) {
    test('up and down use the exact server-only inventory with forge $forge', () async {
      final remote = _ServerRemote([]);
      final hostRun = run(remote);
      expect(await hostRun.up(plan(forge: forge)), Exit.done);
      expect(completed.single.values, hostValues());
      expect(steps[steps.length - 2].step, 'up');
      expect(steps.last.state, StepState.host);
      expect(remote.commands.any((command) => command.contains('/etc/porelo-host/host.json')), isFalse);
      expect(remote.commands, isNot(contains('id -u')));
      expect(await hostRun.down(plan(forge: forge)), Exit.done);
      final inventories = remote.runs
          .where((each) => each.command.endsWith('inventory.yml'))
          .map((each) => jsonDecode(each.input) as Map)
          .toList();
      expect(inventories, hasLength(2));
      for (final inventory in inventories) {
        expect((inventory['all'] as Map)['vars'], {
          'porelo_host_inventory_version': 2,
          'porelo_host_name': 'orchard',
          'porelo_host_network': 7,
          'porelo_host_distribution': 'snapshots',
          'porelo_host_vpn_peer_public_key': wireGuardKey,
          'porelo_host_vpn_peer_address': '10.73.7.2/32',
          'porelo_host_forge': forge,
        });
      }
      expect(remote.users.toSet(), {'root'});
      expect(provider.released, ['rental']);
    });
  }
  // Harm: a rental completion for another host is published as this server’s trusted card.
  for (final name in ['orchard', 'other']) {
    test('SSH-only completion is checked against rental identity $name', () async {
      final card = <String, Object?>{
        'name': name,
        'address': '203.0.113.7',
        'ssh_port': 22,
        'host_key': sshKey,
        'services': {
          'forge': {'web_port': 3000, 'git_port': 3001},
          'matrix': {'port': 8448},
        },
      };
      expect(await run(_ServerRemote([], completion: card)).up(plan()), name == 'orchard' ? Exit.done : Exit.refused);
      expect(completed.map((host) => host.stored), name == 'orchard' ? [card] : isEmpty);
    });
  }

  // Harm: missing, repeated, or misplaced metadata can falsely confirm a host or release its rental.
  test('a successful up without a host protocol line is refused', () async {
    expect(await run(_ServerRemote([], hostRecord: false)).up(plan()), Exit.refused);
    expect(steps.last.fix, contains('host.json'));
    expect(completed, isEmpty);
  });
  test('up refuses a repeated host protocol line', () async {
    final remote = _ServerRemote(
      [],
      afterHost: [
        jsonEncode({'v': 1, 'state': 'host', 'host': hostValues()}),
      ],
    );
    expect(await run(remote).up(plan()), Exit.refused);
    expect(steps.last.fix, contains('repeated'));
    expect(completed, isEmpty);
  });
  test('up refuses host metadata before its final successful task', () async {
    final remote = _ServerRemote([
      jsonEncode({'v': 1, 'state': 'host', 'host': hostValues()}),
    ], hostRecord: false);
    expect(await run(remote).up(plan()), Exit.refused);
    expect(steps.last.fix, contains('successful up task'));
    expect(completed, isEmpty);
  });
  test('up refuses a task after the host protocol line', () async {
    final remote = _ServerRemote(
      [],
      afterHost: [
        jsonEncode({'v': 1, 'state': 'ok', 'task': 'later'}),
      ],
    );
    expect(await run(remote).up(plan()), Exit.refused);
    expect(steps.last.fix, contains('last line'));
    expect(completed, isEmpty);
  });
  test('down refuses a host protocol line and keeps the rental', () async {
    final remote = _ServerRemote([
      jsonEncode({'v': 1, 'state': 'host', 'host': hostValues()}),
    ], hostRecord: false);
    expect(await run(remote).down(plan()), Exit.refused);
    expect(steps.where((step) => step.fix?.contains('only from up') == true), isNotEmpty);
    expect(provider.released, isEmpty);
    expect(completed, isEmpty);
  });

  test('the root stop asks only for the host VPN key and certificate', () async {
    final remote = _ServerRemote([
      jsonEncode({
        'v': 1,
        'state': 'waiting',
        'needs': ['wireguard', 'forge-certificate'],
      }),
    ], playExit: 2);
    expect(await run(remote).up(plan()), Exit.waiting);
    expect(steps.last.needs, ['wireguard', 'forge-certificate']);
    expect(steps.last.admin, 'root');
    expect(steps.last.account, isEmpty);
    expect(completed, isEmpty);
  });
  for (final need in ['vault', 'vault-new', 'drive', 'keys', 'matrix-token', 'unknown']) {
    test('refuses a root stop asking for $need', () async {
      final remote = _ServerRemote([
        jsonEncode({
          'v': 1,
          'state': 'waiting',
          'needs': ['wireguard', need],
        }),
      ], playExit: 2);
      expect(await run(remote).up(plan()), Exit.refused);
      expect(steps.last.fix, contains(need));
      expect(completed, isEmpty);
    });
  }
  for (final (field, value) in [
    ('network', '10.73.8.0/24'),
    ('address', '203.0.113.8'),
    ('homeserver', 'matrix.other.porelo.internal'),
  ]) {
    test('refuses completion $field that differs from the rented server', () async {
      final remote = _ServerRemote(
        [],
        completion: {...hostValues(), field: value, if (field == 'address') 'endpoint': '$value:51820'},
      );
      expect(await run(remote).up(plan()), Exit.refused);
      expect(steps.last.fix, contains(field));
      expect(completed, isEmpty);
    });
  }
  for (final name in ['', '-orchard', 'orchard-', 'Orchard', 'one.two', 'a' * 64, 'one;id', 'one\nroot']) {
    test('rejects invalid host name before remote work: ${jsonEncode(name)}', () async {
      final remote = _ServerRemote([]);
      expect(await run(remote).up(plan(name: name)), Exit.refused);
      expect(remote.commands, isEmpty);
    });
  }
  for (final peer in ['10.73.7.1', '10.73.8.2', '10.73.7.0', '10.73.7.255', '10.73.7.02', '10.73.7.2;id']) {
    test('rejects an invalid VPN peer before remote work: $peer', () async {
      final remote = _ServerRemote([]);
      expect(await run(remote).up(plan(peer: peer)), Exit.refused);
      expect(remote.commands, isEmpty);
    });
  }
  for (final network in [-1, 256]) {
    test('rejects an out-of-range network $network', () async {
      final remote = _ServerRemote([]);
      expect(await run(remote).down(plan(network: network)), Exit.refused);
      expect(provider.released, isEmpty);
    });
  }
}
