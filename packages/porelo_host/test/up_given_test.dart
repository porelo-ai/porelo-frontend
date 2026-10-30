// Linux: HostRun uses chmod; upload-path guards are exercised through bash.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import '../bin/porelo_host.dart' show runHostCommand;
import 'host_run_test.dart' show ScriptedRemote;
import 'server_contract_test.dart' show sshKey;

void main() {
  late Directory scratch;
  late File collection;
  late ScriptedRemote remote;
  late StringBuffer output;
  late StringBuffer errors;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('up-given-');
    collection = File('${scratch.path}/collection.tar.gz');
    await collection.writeAsBytes([0, 128, 255, 10]);
    output = StringBuffer();
    errors = StringBuffer();
    remote = ScriptedRemote([
      jsonEncode({'v': 1, 'state': 'ok', 'task': 'finished', 'text': 'Host ready'}),
      jsonEncode({
        'v': 1,
        'state': 'host',
        'host': {
          'address': '192.0.2.7',
          'ssh_host_key': sshKey,
          'homeserver': 'orchard',
          'services': {
            'forge': {'web_port': 3000, 'git_port': 3001},
          },
        },
      }),
    ]);
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<int> up({bool limits = true, String? digest, List<String> extra = const []}) async => runHostCommand(
    [
      'up',
      '--given',
      '192.0.2.7',
      '--host-key',
      sshKey,
      '--host-name',
      'orchard',
      if (limits) ...['--forge-runner-capacity', '1', '--forge-job-cpus', '1', '--forge-job-memory', '768m'],
      '--collection',
      collection.path,
      '--collection-sha256',
      digest ?? sha256.convert(await collection.readAsBytes()).toString(),
      ...extra,
    ],
    remote: remote,
    output: output,
    errors: errors,
    environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
  );

  // Harm: preparation cannot run, or records a host ready before executing the checked setup.
  test('up given runs the rehearsed preparation in order and completes the host', () async {
    expect(await up(), Exit.done, reason: errors.toString());
    expect(remote.commands, [
      'true',
      remote.commands[1],
      remote.commands[2],
      'cat > /var/tmp/porelo-host/inventory.yml',
      "set -e; if command -v cloud-init >/dev/null; then cloud-init status --wait >/dev/null || [ \$? -le 2 ]; fi\n"
          'DEBIAN_FRONTEND=noninteractive apt-get update -q >/dev/null\n'
          'DEBIAN_FRONTEND=noninteractive apt-get install -y -q ansible-core >/dev/null\n'
          'install -d -o root -g root -m 0755 /usr/share/ansible\n'
          'env LC_ALL=C.UTF-8 LANG=C.UTF-8 ansible-galaxy collection install --force -p /usr/share/ansible/collections /var/tmp/porelo-host/collection.tar.gz >/dev/null',
      'env LC_ALL=C.UTF-8 LANG=C.UTF-8 ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections '
          'ANSIBLE_STDOUT_CALLBACK=porelo.host.lines ansible-playbook -c local -i /var/tmp/porelo-host/inventory.yml porelo.host.up',
    ]);
    expect(remote.commands[2], matches(r'^copy .*/collection\.tar\.gz /var/tmp/porelo-host/collection\.tar\.gz$'));
    expect(remote.users.toSet(), {'root'});
    final inventory = jsonDecode(
      remote.runs.singleWhere((r) => r.command == 'cat > /var/tmp/porelo-host/inventory.yml').input,
    );
    expect(inventory, {
      'all': {
        'hosts': {'localhost': <String, Object?>{}},
        'vars': {
          'porelo_host_inventory_version': 2,
          'porelo_host_name': 'orchard',
          'porelo_host_network': 0,
          'porelo_host_distribution': 'snapshots',
          'porelo_host_forge': true,
          'forge_runner_capacity': 1,
          'forge_job_cpus': 1,
          'forge_job_memory': '768m',
        },
      },
    });
    final steps = LineSplitter.split(output.toString()).map(Step.fromLine).toList();
    expect(steps.every((s) => s != null), isTrue);
    expect(steps[steps.length - 2]!.step, 'up');
    expect(steps.last!.host!.stored, {
      'name': 'orchard',
      'address': '192.0.2.7',
      'ssh_port': 22,
      'ssh_host_key': sshKey,
      'services': PreparedHost.defaultLocalServices,
    });
  });
  // Harm: a reported failure, even with exit 0, must not produce a ready host.
  for (final state in ['failed', 'waiting']) {
    for (final trailing in ['none', 'ok', 'host']) {
      test('a $state line followed by $trailing keeps the gate words and refuses even with exit zero', () async {
        final later = trailing == 'none' ? <String>[] : [trailing == 'ok' ? remote.lines.first : remote.lines.last];
        remote.lines = [
          jsonEncode({
            'v': 1,
            'state': state,
            'task': 'matrix-gate',
            'text': 'Prepare the Matrix gate',
            'msg': "unknown verb 'gate'",
          }),
          ...later,
        ];
        expect(await up(), Exit.refused);
        final steps = LineSplitter.split(output.toString()).map(Step.fromLine).whereType<Step>();
        expect(steps.where((s) => s.state == StepState.host), isEmpty);
        expect(steps.last.text, 'Prepare the Matrix gate');
        expect(steps.last.words, "unknown verb 'gate'");
        expect(steps.any((s) => s.text == 'Prepare the Matrix gate' && s.words == "unknown verb 'gate'"), isTrue);
      });
    }
  }
  // Harm: malformed stop fields must never turn failed setup into a ready host.
  for (final state in ['failed', 'waiting']) {
    for (final field in ['msg', 'needs', 'seconds', 'task']) {
      for (final afterHost in [false, true]) {
        test('malformed $state $field after host=$afterHost stops preparation', () async {
          remote.lines = [
            if (afterHost) ...remote.lines,
            jsonEncode({'v': 1, 'state': state, field: null}),
            if (!afterHost) ...remote.lines,
          ];
          expect(await up(), Exit.refused);
          final steps = LineSplitter.split(output.toString()).map(Step.fromLine).whereType<Step>();
          expect(steps.where((s) => s.state == StepState.host), isEmpty);
          expect(steps.last.fix, isNotEmpty);
        });
      }
    }
  }
  // Harm: changed or incomplete host records must not redirect a signed card.
  for (final mode in ['missing', 'wrong-key', 'wrong-address', 'repeated', 'trailing', 'failed-process']) {
    test('a $mode completion never records a ready host', () async {
      final host = jsonDecode(remote.lines.last) as Map<String, dynamic>;
      switch (mode) {
        case 'missing':
          remote.lines.removeLast();
        case 'wrong-key':
          host['host']['ssh_host_key'] =
              'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcH';
          remote.lines[1] = jsonEncode(host);
        case 'wrong-address':
          host['host']['address'] = '192.0.2.8';
          remote.lines[1] = jsonEncode(host);
        case 'repeated':
          remote.lines.add(remote.lines.last);
        case 'trailing':
          remote.lines.add(remote.lines.first);
        case 'failed-process':
          remote.playExit = 2;
      }
      expect(await up(), Exit.refused);
      expect(
        LineSplitter.split(output.toString())
            .map(Step.fromLine)
            .whereType<Step>()
            .where((s) => s.state == StepState.host),
        isEmpty,
      );
    });
  }
  // Harm: a substituted collection must not execute commands as root.
  test('a digest mismatch refuses before SSH', () async {
    expect(await up(digest: '0' * 64), Exit.refused);
    expect(remote.commands, isEmpty);
  });
  // Harm: invalid settings or endpoint values must not reach privileged commands.
  for (final extra in [
    ['--forge-job-cpus', '0'],
    ['--forge-job-memory', '768m;id'],
    ['--given', '127.0.0.1'],
    ['--host-key', 'ssh-ed25519 AAAA'],
  ]) {
    test('invalid public input $extra refuses before SSH', () async {
      expect(await up(extra: extra), Exit.refused);
      expect(remote.commands, isEmpty);
    });
  }
  test('omitted job limits leave the role defaults and chosen local ports stay local', () async {
    expect(await up(limits: false, extra: ['--forge-web-port', '3100']), Exit.done);
    final inventory = jsonDecode(remote.runs.singleWhere((r) => r.command.endsWith('/inventory.yml')).input);
    expect((inventory['all']['vars'] as Map).keys.toSet(), {
      'porelo_host_inventory_version',
      'porelo_host_name',
      'porelo_host_network',
      'porelo_host_distribution',
      'porelo_host_forge',
    });
    expect(Step.fromLine(LineSplitter.split(output.toString()).last)!.host!.services['forge']!['web_port'], 3100);
  });
  // Harm: renting must remain unavailable until the verified Core adapter is bound.
  test('Scaleway preparation still refuses without opening SSH', () async {
    expect(
      await runHostCommand(
        ['up', '--host-name', 'orchard', '--public-key', sshKey, '--scaleway-project', 'fixture-project'],
        remote: remote,
        output: output,
        errors: errors,
      ),
      Exit.refused,
    );
    expect(remote.commands, isEmpty);
    expect(errors.toString(), contains('Core'));
  });
  // Harm: changing the chosen file after validation must not execute an unchecked collection as root.
  test('preparation uploads the checked bytes when the source changes during SSH', () async {
    final replacing = _ReplacingRemote(remote.lines, collection);
    remote = replacing;
    expect(await up(), Exit.done);
    expect(replacing.copied, [0, 128, 255, 10]);
  });
  // Harm: a local host account must not redirect privileged preparation writes through symlinks.
  for (final target in ['directory', 'collection.tar.gz', 'inventory.yml']) {
    test('preparation refuses a symlink at its $target upload path', () async {
      expect(await up(), Exit.done);
      final work = '${scratch.path}/remote-work';
      final outside = Directory('${scratch.path}/outside');
      await outside.create();
      if (target == 'directory') {
        await Link(work).create(outside.path);
      } else {
        await Directory(work).create();
        await Link('$work/$target').create('${outside.path}/untouched');
      }
      final command = remote.commands[1].replaceAll('/var/tmp/porelo-host', work);
      // Root ownership is the stand-in; symlinks are real filesystem entries.
      final result = await Process.run('bash', ['-c', "stat() { printf '%s' '0:700'; }\n$command"]);
      expect(result.exitCode, isNot(0), reason: 'An unsafe root upload destination must be refused.');
      expect(await File('${outside.path}/untouched').exists(), isFalse);
    });
  }
}

class _ReplacingRemote extends ScriptedRemote {
  _ReplacingRemote(super.lines, this.source);
  final File source;
  List<int>? copied;
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    if (command == 'true') await source.writeAsBytes([42]);
    return super.run(host, user, command, input: input, onLine: onLine);
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    copied = await File(from).readAsBytes();
    return super.copy(host, user, from, to);
  }
}
