// The bring exercises OpenSSH's process boundary, bash upload scripts, and chmod.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/join_keys.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';
import 'package:porelo_frontend/src/app/project_workspace.dart';
import 'package:porelo_frontend/src/ui/project_bring_dialog.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/host_admin.dart';
import '../support/host_matrix_ca.dart';

class _SignedFiles extends HostFiles {
  _SignedFiles() : super(MemorySecrets());
  @override
  Future<({List<int> bytes, String projectYaml})> createProjectSetup({
    required String project,
    required String url,
    required String commit,
    required File signingKey,
  }) async => (
    bytes: utf8.encode(commit),
    projectYaml: 'name: demo\naccess: {repository: https://example.org/team/access.git}\nrepositories:\n  api: {upstream: https://example.org/team/api.git}\ncredentials: {search: brave-search}\n',
  );
}

class _Following extends FakeBackend {
  _Following({bool empty = false})
    : records = empty
          ? []
          : [
              const Followed(
                name: 'demo',
                url: 'https://example.org/project.git',
                commit: '0123456789012345678901234567890123456789',
              ),
            ],
      super(const []);
  final List<Followed> records;
  @override
  Future<List<Followed>> following() async => List.of(records);
}

class _OwnSsh implements Remote {
  _OwnSsh(this.home, this.target, {this.rejectRoom = false});
  final bool rejectRoom;
  final Directory home;
  final _Following target;
  final commands = <String>[];
  final users = <String>[];
  bool stop = true;
  final arguments = <List<String>>[];
  Future<Process> start(String program, List<String> args) async {
    arguments.add(List.of(args));
    final trust = args
        .singleWhere((arg) => arg.startsWith('UserKnownHostsFile='))
        .substring('UserKnownHostsFile='.length)
        .replaceAll('"', '');
    expect(File(trust).readAsStringSync(), '10.73.7.1 ${matrixHostValues()['ssh_host_key']}\n');
    expect(args, contains('StrictHostKeyChecking=yes'));
    final destination = args[args.length - 2];
    expect(destination, 'admin@10.73.7.1');
    final command = args.last;
    if (command == '/usr/bin/cat /etc/porelo-host/forge/ca.pem') {
      commands.add(command);
      users.add('admin');
      final process = HostProcess();
      const LineSplitter().convert(hostMatrixCa).forEach(process.raw);
      process.end(0);
      return process;
    }
    if (command.contains('ansible-playbook')) {
      final process = HostProcess();
      run('10.73.7.1', 'admin', command, onLine: process.raw).then((result) {
        if (result.stderr.isNotEmpty) process.words(result.stderr);
        process.end(result.exitCode);
      });
      return process;
    }
    commands.add(command);
    users.add('admin');
    return Process.start(
      '/bin/bash',
      ['--noprofile', '--norc', '-c', command],
      workingDirectory: home.path,
      environment: {'HOME': home.path},
    );
  }

  Future<ProcessResult> scp(String program, List<String> args) async {
    arguments.add(List.of(args));
    expect(args, contains('StrictHostKeyChecking=yes'));
    final destination = args.last;
    expect(destination, startsWith('admin@10.73.7.1:'));
    await copy('10.73.7.1', 'admin', args[args.length - 2], destination.substring(destination.indexOf(':') + 1));
    return ProcessResult(1, 0, '', '');
  }

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    commands.add(command);
    users.add(user);
    if (command.contains('ansible-playbook')) {
      if (stop) {
        onLine?.call(
          jsonEncode({
            'v': 1,
            'state': 'waiting',
            'needs': ['vault-new', 'keys', 'forge-central-token'],
          }),
        );
        stop = false;
        return const RemoteResult(2, '');
      }
      if (rejectRoom) {
        onLine?.call(
          jsonEncode({
            'v': 1,
            'task': 'Make the project room',
            'state': 'failed',
            'msg': 'porelo: the project has no Matrix peer; the room was not made.',
          }),
        );
        return const RemoteResult(2, '');
      }
      final project = RegExp(r'porelo_project=([A-Za-z0-9._-]+)').firstMatch(command)!.group(1)!;
      final place = '${home.path}/${HostAct.ownAccount.setupPlace(project: project)}';
      final machine = loadYaml(File('$place/machine.yml').readAsStringSync());
      target.records.add(
        Followed(
          name: machine['project']['name'] as String,
          url: machine['project']['url'] as String,
          commit: File('$place/project.bundle').readAsStringSync(),
        ),
      );
      onLine?.call(jsonEncode({'v': 1, 'task': 'Make the project room', 'state': 'ok', 'msg': ''}));
      return const RemoteResult(0, '');
    }
    final process = await Process.start(
      '/bin/bash',
      ['--noprofile', '--norc', '-c', command],
      workingDirectory: home.path,
      environment: {'HOME': home.path},
    );
    if (input != null) process.stdin.write(input);
    await process.stdin.close();
    final output = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onLine?.call(line));
    final errors = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    await output;
    return RemoteResult(code, await errors);
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    users.add(user);
    await File(from).copy(to);
    return const RemoteResult(0, '');
  }
}

void main() {
  // Harm: a project admin must not rent another server or run privileged setup.
  testWidgets('putting a project on an admitted server offers no renting', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    addTearDown(() {
      machines.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openHostDialog(
                context,
                project: 'demo',
                machines: machines,
                settings: settings,
                backend: FakeBackend(const []),
                start: (_, _) async => HostProcess()..end(0),
              ),
              child: const Text('Put project'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Put project'));
    await World.settle(tester);
    final wizard = tester.widget<Wizard>(find.byType(Wizard));
    expect(
      wizard.steps.map((step) => step.title),
      isNot(contains('Where it is rented')),
      reason: 'a project admin uses a server they were admitted to',
    );
    expect(wizard.steps.map((step) => step.title), contains('The project'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: bringing through root or repeating publication when feeding a stop changes the wrong account.
  for (final outcome in [
    'brought',
    'room-refused',
    'ca-missing',
    'ca-mismatch',
    'setup-exists',
    'vpn-new',
    'vpn-ca-mismatch',
  ]) {
    final rejectRoom = outcome == 'room-refused';
    final newVpn = outcome.startsWith('vpn-');
    final refusedCa = outcome.startsWith('ca-') || outcome == 'vpn-ca-mismatch';
    testWidgets(
      refusedCa
          ? 'the project bring refuses $outcome before editing or uploading access'
          : outcome == 'setup-exists'
          ? 'an interrupted bring retry preserves existing setup and publishes access once'
          : rejectRoom
          ? 'a room refusal stops the bring in Porelo’s words'
          : newVpn
          ? 'a first bring connects this machine and records the verified host before publishing'
          : 'the project dialog signs with own git uploads privately and resumes without sudo',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scratch = Directory.systemTemp.createTempSync('project-bring-widget-');
        final signing = File('${scratch.path}/signer.pub')..writeAsStringSync(hostValues()['ssh_host_key']! as String);
        final secrets = File('${scratch.path}/secrets.kdbx')..writeAsStringSync('encrypted fixture');
        final home = Directory('${scratch.path}/host-home')..createSync();
        final existing = Directory('${home.path}/.local/share/porelo-host/setup/demo');
        if (outcome == 'setup-exists') {
          existing.createSync(recursive: true);
          File('${existing.path}/keep').writeAsStringSync('interrupted bring');
        }
        final target = _Following(empty: true);
        final remote = _OwnSsh(home, target, rejectRoom: rejectRoom);
        final settings = Settings(MemorySettingsStore());
        await settings.rememberHostUp('garden', matrixHostRecord(host: 'garden'));
        if (!newVpn) {
          await settings.rememberHostUp(
            'orchard',
            outcome == 'ca-missing'
                ? HostUpRecord.fromStored({...matrixHostRecord().stored, 'forgeCa': null})!
                : matrixHostRecord(),
          );
        }
        final store = MemorySecrets();
        JoinPublicKeys? publicKeys;
        if (newVpn) {
          await store.write('porelo-host/ssh-orchard', base64Encode(List.filled(32, 3)));
          await store.write(HostFiles.keyName('orchard'), base64Encode(List.filled(32, 4)));
          publicKeys = await tester.runAsync(() => JoinKeys(store).publicKeys('orchard'));
        }
        final vpnCas = <String?>[];
        final backend = _Following();
        final machine = Machine(
          name: 'Admitted server',
          kind: 'host',
          host: 'admin@10.73.7.1',
          identity: '${scratch.path}/identity',
          hostProject: rejectRoom ? 'orchard' : 'old-host',
          socketPath: '/unused',
        );
        File(machine.identity).writeAsStringSync('identity fixture');
        final state = {'XDG_STATE_HOME': '${scratch.path}/state'};
        final trust = File('${poreloHostKnownHosts(environment: state)}.orchard');
        final machines = Machines(settings, reach: (_) => target, tunnels: FakeTunnels());
        await machines.load();
        addTearDown(() async {
          machines.dispose();
          settings.dispose();
          await tester.runAsync(() => scratch.delete(recursive: true));
        });
        final gitCommands = <List<String>>[];
        String? publishedAccess;
        final heads = <String, String>{};
        final staged = <String, String>{};
        final terminals = <FakeTerminal>[];
        Future<Ran> git(
          String program,
          List<String> args, {
          String? inDirectory,
          Map<String, String> environment = const {},
          String? input,
        }) async {
          gitCommands.add(List.of(args));
          expect(
            trust.readAsStringSync(),
            '10.73.7.1 ${matrixHostValues()['ssh_host_key']}\n',
            reason: 'trust must be pinned before any private Git operation',
          );
          if (args.first == 'clone') {
            await Directory('${args.last}/.git').create();
            await File('${args.last}/access.yml').writeAsString('developers: {} # keep\n');
            heads[args.last] = File('${args.last}/access.yml').readAsStringSync();
          }
          if (args.first == 'bundle') await File(args[2]).writeAsString('signed access bundle');
          if (args.first == 'push') publishedAccess = File('$inDirectory/access.yml').readAsStringSync();
          if (args.first == 'worktree' && args[1] == 'add') {
            await File('$inDirectory/access.yml').copy('${args[3]}/access.yml');
            heads[args[3]] = heads[inDirectory]!;
          }
          if (args.first == 'merge' && publishedAccess != null) {
            await File('$inDirectory/access.yml').writeAsString(publishedAccess!);
            heads[inDirectory!] = publishedAccess!;
          }
          if (args.first == 'add') {
            expect(args, ['add', '--', 'access.yml']);
            staged[inDirectory!] = File('$inDirectory/access.yml').readAsStringSync();
          }
          return (
            code: args.first == 'diff' && staged[inDirectory] != heads[inDirectory] ? 1 : 0,
            err: '',
            out: switch (args.join(' ')) {
              'config --bool --get commit.gpgsign' => 'true\n',
              'config --get user.signingkey' => 'own-key\n',
              'config --get remote.origin.url' => 'https://example.org/team/access.git\n',
              'symbolic-ref refs/remotes/origin/HEAD' => 'refs/remotes/origin/main\n',
              'symbolic-ref --short HEAD' => 'main\n',
              'rev-list --left-right --count HEAD...refs/remotes/origin/main' => '0\t0\n',
              'rev-parse --verify HEAD^{commit}' => '${'b' * 40}\n',
              _ => args.contains('log') ? 'G\n${HostFiles.signingFingerprint(signing.readAsStringSync())}\n' : '',
            },
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProjectBringDialog(
                project: 'demo',
                machines: machines,
                settings: settings,
                backend: backend,
                startSsh: remote.start,
                runScp: remote.scp,
                targetBackend: target,
                environment: state,
                runGit: git,
                hostFiles: _SignedFiles(),
                store: store,
                restoreIdentity: (host) async {
                  expect(host, 'orchard');
                  return machine.identity;
                },
                activateVpn: (host, keys, address, ca) async {
                  expect(host.values, {...matrixHostValues(), if (outcome == 'vpn-ca-mismatch') 'ca_sha256': '0' * 64});
                  expect(keys, publicKeys);
                  expect(address, '10.73.7.10');
                  expect(settings.hostUp('orchard'), isNull);
                  expect(gitCommands, isEmpty);
                  vpnCas.add(ca);
                  return true;
                },
                accessRoot: '${scratch.path}/access',
                openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                  final terminal = FakeTerminal([program, ...arguments]);
                  terminals.add(terminal);
                  return terminal;
                },
              ),
            ),
          ),
        );
        await World.settle(tester);
        expect(
          tester.widget<Wizard>(find.byType(Wizard)).steps.map((step) => step.title),
          isNot(contains('Where it is rented')),
        );
        expect(
          tester.widget<Wizard>(find.byType(Wizard)).actionSteps,
          hasLength(1),
          reason: 'the playbook makes the room; the interface makes no separate room call',
        );
        await tester.enterText(find.byKey(const Key('bring-signing-key')), signing.path);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('wizard-next')));
        await World.settle(tester);
        expect(
          find.byKey(const Key('bring-account')),
          findsOneWidget,
          reason: 'a project admin can bring without a preexisting watched machine',
        );
        await tester.enterText(find.byKey(const Key('bring-account')), 'admin');
        await tester.enterText(
          find.byKey(const Key('bring-host-values')),
          jsonEncode({
            ...matrixHostValues(),
            if (outcome == 'ca-mismatch' || outcome == 'vpn-ca-mismatch') 'ca_sha256': '0' * 64,
          }),
        );
        await World.settle(tester);
        if (!newVpn) await tester.enterText(find.byKey(const Key('bring-identity')), machine.identity);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('wizard-next')));
        await World.settle(tester);
        if (newVpn) {
          expect(settings.hostUp('orchard'), isNull);
          expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
          for (final invalid in ['10.73.7.1', '10.73.7.2', '10.73.8.10', '10.73.7.255']) {
            await tester.enterText(find.byKey(const Key('bring-vpn-address')), invalid);
            await World.settle(tester);
            expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
          }
          await tester.enterText(find.byKey(const Key('bring-vpn-address')), '10.73.7.10');
          await World.settle(tester);
        }
        await tester.tap(find.byKey(const Key('wizard-next')));
        await World.settle(tester);
        if (!refusedCa) {
          expect(
            tester
                .widgetList<EditableText>(
                  find.descendant(of: find.byKey(const Key('bring-room')), matching: find.byType(EditableText)),
                )
                .every((field) => field.readOnly),
            isTrue,
            reason: 'the room creator accepts only the alias derived for this project and host',
          );
          expect(
            tester.widget<SelectableText>(find.byKey(const Key('bring-room'))).data,
            '#porelo-demo:matrix.orchard.porelo.internal',
          );
        }
        await tester.tap(find.byKey(const Key('wizard-next')));
        await World.settle(tester);
        await tester.enterText(find.byKey(const Key('bring-secrets')), secrets.path);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('wizard-next')));
        await World.settle(tester);
        final start = tester.widget<FilledButton>(find.byKey(const Key('wizard-start'))).onPressed!;
        await tester.runAsync(() async {
          await Function.apply(start, const []);
        });
        await World.settle(tester);
        final action = tester.widget<Wizard>(find.byType(Wizard)).actionSteps.first;
        if (outcome == 'setup-exists') {
          for (var attempt = 0; attempt < 2; attempt++) {
            expect(tester.widget<Wizard>(find.byType(Wizard)).actionSteps.first.state(), WizardActionState.refused);
            expect(find.textContaining('The project setup folder already exists; it was preserved.'), findsWidgets);
            expect(File('${existing.path}/keep').readAsStringSync(), 'interrupted bring');
            expect(remote.commands.where((command) => command.contains('ansible-playbook')), isEmpty);
            expect(
              gitCommands.where((args) => args.first == 'push'),
              hasLength(1),
              reason: 'an interrupted bring retry must not republish identical access bytes',
            );
            if (attempt == 0) {
              await tester.runAsync(() async {
                await Function.apply(start, const []);
              });
              await World.settle(tester);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        if (refusedCa) {
          expect(action.state(), WizardActionState.refused);
          expect(gitCommands, isEmpty, reason: 'untrusted Matrix access must never be edited or published');
          expect(
            remote.commands,
            newVpn ? ['/usr/bin/cat /etc/porelo-host/forge/ca.pem'] : isEmpty,
            reason: 'an untrusted CA must stop before any host upload',
          );
          expect(Directory('${scratch.path}/access/demo').existsSync(), isFalse);
          if (newVpn) {
            expect(vpnCas, [null], reason: 'a mismatched CA must never reach the trust terminal');
            expect(find.textContaining('Expected SHA-256: ${'0' * 64}'), findsWidgets);
            expect(find.textContaining('Received SHA-256: $hostMatrixCaSha256'), findsWidgets);
            expect(settings.hostUp('orchard'), isNull);
          } else {
            expect(find.textContaining(outcome == 'ca-missing' ? 'missing' : 'ca_sha256'), findsWidgets);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        expect(vpnCas, newVpn ? [null, hostMatrixCa] : isEmpty);
        if (newVpn) {
          expect(settings.hostUp('orchard')!.vpnPeerAddress, '10.73.7.10/32');
          expect(settings.hostUp('orchard')!.forgeCa, hostMatrixCa);
        }
        expect(action.state(), WizardActionState.waiting);
        final yaml = loadYaml(File('${home.path}/.local/share/porelo-host/setup/demo/machine.yml').readAsStringSync());
        expect(yaml['access']['bundle'], 'access.bundle');
        expect(yaml['forge']['repositories'], [
          {'name': 'api', 'url': 'https://example.org/team/api.git'},
        ]);
        expect(yaml['keys'].single['name'], 'search');
        expect((yaml['keys'].single.nodes['name'] as YamlScalar).style, ScalarStyle.DOUBLE_QUOTED);
        // Publication is checked against real Git in the access tests; this stand-in retains its sent bytes.
        final access = loadYaml(publishedAccess!);
        expect(access['transports']['matrix'], {
          'homeserver': 'https://matrix.orchard.porelo.internal:8448',
          'room': '#porelo-demo:matrix.orchard.porelo.internal',
          'registration_token_file': '~/.config/porelo/matrix/host-registration-token',
          'ca_certificate': hostMatrixCa,
        });
        expect(remote.users, everyElement('admin'));
        final playbook = remote.commands.singleWhere((command) => command.contains('ansible-playbook'));
        expect(playbook, contains('ansible-playbook -c local porelo.host.bring -e porelo_project=demo'));
        expect(remote.commands, everyElement(isNot(contains('sudo'))));
        expect(
          remote.commands,
          everyElement(isNot(contains('porelo sync'))),
          reason: 'the playbook alone performs its final sync',
        );
        expect(gitCommands.where((args) => args.first == 'push'), hasLength(1));
        await tester.tap(find.byKey(const Key('bring-feed-stop')));
        await World.settle(tester);
        expect(
          terminals.single.command.join(' '),
          contains('porelo-host-stop --stdin vault-new keys forge-central-token'),
        );
        expect(terminals.single.command.join(' '), isNot(contains('sudo')));
        expect(terminals.single.command.last, contains('hosts/orchard/forge-ca-key'));
        expect(terminals.single.command.last, contains('hosts/orchard/forge-ca'));
        expect(
          terminals.single.command.last,
          isNot(contains("move_entry 'shared/forge-ca-key' 'hosts/demo/forge-ca-key'")),
        );
        terminals.single.endsWith(0);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('unlock-done')));
        await World.settle(tester);
        expect(
          tester.widget<Wizard>(find.byType(Wizard)).actionSteps.first.state(),
          rejectRoom ? WizardActionState.refused : WizardActionState.done,
        );
        expect(remote.commands.where((command) => command.contains('ansible-playbook')), hasLength(2));
        expect(
          gitCommands.where((args) => args.first == 'push'),
          hasLength(1),
          reason: 'resuming the stop must not republish access settings',
        );
        if (rejectRoom) {
          expect(find.textContaining('porelo: the project has no Matrix peer; the room was not made.'), findsWidgets);
          expect(settings.projectHost('demo'), isNull, reason: 'a refused bring must not enable removal on a new host');
        } else {
          expect(find.textContaining('Make the project room: ok'), findsOneWidget);
          expect(
            settings.projectHost('demo'),
            'orchard',
            reason: 'removal must use the confirmed host, even with a stale connection label',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
