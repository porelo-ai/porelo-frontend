import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';
import 'package:porelo_frontend/src/app/project_workspace.dart';
import 'package:porelo_frontend/src/ui/project_bring_dialog.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/host_admin.dart';

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
    final runs = HostRuns(machines);
    addTearDown(() {
      runs.dispose();
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
                hostRuns: runs,
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
  for (final rejectRoom in [false, true]) {
    testWidgets(
      rejectRoom
          ? 'a room refusal stops the bring in Porelo’s words'
          : 'the project dialog signs with own git uploads privately and resumes without sudo',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scratch = Directory.systemTemp.createTempSync('project-bring-widget-');
        final signing = File('${scratch.path}/signer.pub')..writeAsStringSync(hostValues()['ssh_host_key']! as String);
        final secrets = File('${scratch.path}/secrets.kdbx')..writeAsStringSync('encrypted fixture');
        final home = Directory('${scratch.path}/host-home')..createSync();
        final target = _Following(empty: true);
        final remote = _OwnSsh(home, target, rejectRoom: rejectRoom);
        final settings = Settings(MemorySettingsStore());
        final backend = _Following();
        final machine = Machine(
          name: 'Admitted server',
          kind: 'host',
          host: 'admin@10.73.7.1',
          identity: '${scratch.path}/identity',
          hostProject: rejectRoom ? 'orchard' : 'old-host',
          socketPath: '/unused',
        );
        await settings.rememberMachines([machine]);
        final machines = Machines(settings, reach: (_) => target, tunnels: FakeTunnels());
        await machines.load();
        addTearDown(() async {
          machines.dispose();
          settings.dispose();
          await tester.runAsync(() => scratch.delete(recursive: true));
        });
        final gitCommands = <List<String>>[];
        final terminals = <FakeTerminal>[];
        Future<Ran> git(
          String program,
          List<String> args, {
          String? inDirectory,
          Map<String, String> environment = const {},
          String? input,
        }) async {
          gitCommands.add(List.of(args));
          if (args.first == 'clone') {
            await Directory('${args.last}/.git').create();
            await File('${args.last}/access.yml').writeAsString('developers: {} # keep\n');
          }
          if (args.first == 'bundle') await File(args[2]).writeAsString('signed access bundle');
          return (
            code: args.first == 'diff' ? 1 : 0,
            err: '',
            out: switch (args.join(' ')) {
              'config --bool --get commit.gpgsign' => 'true\n',
              'config --get user.signingkey' => 'own-key\n',
              'config --get remote.origin.url' => 'https://example.org/team/access.git\n',
              'symbolic-ref --short refs/remotes/origin/HEAD' => 'origin/main\n',
              'symbolic-ref --short HEAD' => 'main\n',
              'rev-list --left-right --count HEAD...origin/main' => '0\t0\n',
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
                remote: remote,
                runGit: git,
                hostFiles: _SignedFiles(),
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
        expect(find.byKey(const Key('bring-host')), findsOneWidget);
        expect(tester.widget<DropdownButton<Machine>>(find.byKey(const Key('bring-host'))).value, machine);
        await tester.enterText(find.byKey(const Key('bring-host-values')), jsonEncode(hostValues()));
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('wizard-next')));
        await World.settle(tester);
        expect(
          tester.widget<TextField>(find.byKey(const Key('bring-room'))).controller!.text,
          '#porelo-demo:matrix.orchard.porelo.internal',
        );
        await tester.enterText(find.byKey(const Key('bring-room')), '#missing-homeserver');
        await World.settle(tester);
        expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
        await tester.enterText(find.byKey(const Key('bring-room')), '#custom-demo:matrix.orchard.porelo.internal');
        await World.settle(tester);
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
        expect(action.state(), WizardActionState.waiting);
        final yaml = loadYaml(File('${home.path}/.local/share/porelo-host/setup/demo/machine.yml').readAsStringSync());
        expect(yaml['access']['bundle'], 'access.bundle');
        expect(yaml['forge']['repositories'], [
          {'name': 'api', 'url': 'https://example.org/team/api.git'},
        ]);
        expect(yaml['keys'].single['name'], 'search');
        final access = loadYaml(File('${scratch.path}/access/demo/access.yml').readAsStringSync());
        expect(access['transports']['matrix'], {
          'homeserver': 'https://matrix.orchard.porelo.internal:8448',
          'room': '#custom-demo:matrix.orchard.porelo.internal',
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
