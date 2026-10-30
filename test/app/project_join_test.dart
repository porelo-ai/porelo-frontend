// Private bundles and pinned SSH state use Linux chmod and own-account Bash uploads.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/join_keys.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/project_join_dialog.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import '../features/support/world.dart';
import '../support/host_admin.dart';
import '../support/host_matrix_ca.dart';

class JoinFiles extends HostFiles {
  JoinFiles() : super(MemorySecrets());
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

class JoinBackend extends FakeBackend {
  JoinBackend() : super(const []);
  @override
  Future<List<Followed>> following() async => [
    Followed(
      name: 'demo',
      url: 'https://example.org/team/project.git',
      commit: 'a' * 40,
      signers: [HostFiles.signingFingerprint(hostValues()['ssh_host_key']! as String)],
    ),
  ];
}

class JoinRemote implements Remote {
  JoinRemote(this.home);
  final Directory home;
  final commands = <String>[];
  final users = <String>[];
  final hosts = <String>[];
  void Function(String host, String command)? beforeRun;
  String ca = hostMatrixCa;
  bool wait = false;
  int playbookCode = 0;
  int copies = 0;
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    beforeRun?.call(host, command);
    commands.add(command);
    users.add(user);
    hosts.add(host);
    if (command == '/usr/bin/cat /etc/porelo-host/forge/ca.pem') {
      const LineSplitter().convert(ca).forEach((line) => onLine?.call(line));
      return const RemoteResult(0, '');
    }
    if (command == '/usr/bin/id -u') {
      onLine?.call('1001');
      return const RemoteResult(0, '');
    }
    if (command.contains('ansible-playbook')) {
      if (wait) {
        onLine?.call('{"v":1,"state":"waiting","needs":["vault-new","keys","forge-central-token"]}');
      }
      return RemoteResult(wait ? 2 : playbookCode, playbookCode == 0 ? '' : 'The host refuses this account.');
    }
    final process = await Process.start(
      '/bin/bash',
      ['--noprofile', '--norc', '-c', command],
      environment: {'HOME': home.path},
      workingDirectory: home.path,
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
    copies++;
    await File(from).copy(to);
    return const RemoteResult(0, '');
  }
}

void main() {
  late Directory scratch;
  late MemorySecrets store;
  late JoinKeys keys;
  late JoinPublicKeys public;
  late JoinRemote remote;
  late List<List<String>> commands;
  late List<String> changes;
  late Map<String, Object?> answer;
  late Map<String, Object?> accessDocument;
  RunHere? actualGit;
  late bool cloneAllowed;
  late bool passwordAccepted;
  Future<Ran> Function()? verify;
  late ProjectJoin join;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('developer-join-');
    store = MemorySecrets();
    keys = JoinKeys(store);
    public = await keys.publicKeys('orchard', create: true);
    remote = JoinRemote(scratch);
    commands = [];
    changes = [];
    cloneAllowed = true;
    passwordAccepted = true;
    verify = null;
    actualGit = null;
    answer = {
      'project': 'demo',
      'commit': 'a' * 40,
      'access_commit': 'b' * 40,
      'signer': hostValues()['ssh_host_key'],
      'signers': [hostValues()['ssh_host_key']],
      'host': Map.of(matrixHostValues())..remove('homeserver'),
      'developers': {
        'dev': {
          'laptops': [
            {'ssh_public_key': public.ssh, 'wireguard_public_key': public.wireguard, 'vpn_address': '10.73.7.10'},
          ],
        },
      },
      'transports': {
        'matrix': {'homeserver': 'https://matrix.orchard.porelo.internal:8448'},
      },
    };
    accessDocument = jsonDecode(
      jsonEncode({
        for (final field in ['host', 'developers', 'transports']) field: answer[field],
      }),
    ) as Map<String, Object?>;
    ((accessDocument['transports'] as Map)['matrix'] as Map)['ca_certificate'] = hostMatrixCa;
    final signer = File('${scratch.path}/signer.pub');
    await signer.writeAsString(hostValues()['ssh_host_key']! as String);
    join = ProjectJoin(
      project: 'demo',
      backend: JoinBackend(),
      targetBackend: JoinBackend(),
      files: JoinFiles(),
      signingKey: signer,
      keys: keys,
      root: '${scratch.path}/joins',
      secretsFile: '${scratch.path}/secrets.kdbx',
      environment: {
        'HOME': scratch.path,
        'XDG_STATE_HOME': '${scratch.path}/state',
        'XDG_RUNTIME_DIR': '${scratch.path}/runtime',
      },
      activateVpn: (access, keys, address, ca) async {
        changes.add('vpn:$address');
        expect(ca, hostMatrixCa);
        return true;
      },
      restoreIdentity: (host) async {
        changes.add('identity');
        final file = File('${scratch.path}/runtime/porelo-join-orchard/identity');
        await file.parent.create(recursive: true);
        await file.writeAsString('runtime identity fixture');
        return file.path;
      },
      setForgePassword: (machine, knownHosts) async {
        changes.add('forge-password');
        return passwordAccepted;
      },
      remoteFor: (knownHosts, identity) => remote,
      run: (program, arguments, {inDirectory, environment = const {}, input}) async {
        commands.add([program, ...arguments]);
        if (program == 'porelo') return verify == null ? (code: 0, out: jsonEncode(answer), err: '') : await verify!();
        if (actualGit != null) {
          return actualGit!(program, arguments, inDirectory: inDirectory, environment: environment, input: input);
        }
        if (arguments.first == 'clone' && !cloneAllowed) return (code: 128, out: '', err: 'private Git diagnostic');
        if (arguments.first == 'clone') await Directory(arguments.last).create();
        if (arguments.first == 'bundle') await File(arguments[2]).writeAsString('access bundle');
        final out = switch (arguments.first) {
          'symbolic-ref' => 'origin/trunk\n',
          'rev-parse' => '${'b' * 40}\n',
          'show' => jsonEncode(accessDocument),
          _ => '',
        };
        return (code: 0, out: out, err: '');
      },
    );
  });
  tearDown(() async {
    join.dispose();
    await scratch.delete(recursive: true);
  });

  Map<String, String> laptopFiles() {
    final found = <String, String>{};
    for (final area in ['joins', 'state', 'runtime']) {
      final folder = Directory('${scratch.path}/$area');
      if (!folder.existsSync()) continue;
      found[area] = '${folder.statSync().mode}';
      for (final entity in folder.listSync(recursive: true, followLinks: false)) {
        final relative = entity.path.substring(scratch.path.length + 1);
        found[relative] = entity is File
            ? sha256.convert(entity.readAsBytesSync()).toString()
            : '${entity.statSync().mode}';
      }
    }
    return found;
  }

  // Harm: a UI retry must not bypass a missing local verifier and open privileged setup.
  testWidgets('the join wizard stops before laptop changes when Porelo is missing', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => JoinBackend(), tunnels: FakeTunnels());
    addTearDown(() {
      machines.dispose();
      settings.dispose();
    });
    final secrets = File('${scratch.path}/secrets.kdbx')..writeAsStringSync('encrypted fixture');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectJoinDialog(
            project: 'demo',
            backend: JoinBackend(),
            machines: machines,
            settings: settings,
            store: store,
            files: JoinFiles(),
            root: '${scratch.path}/widget-join',
            run: (program, arguments, {inDirectory, environment = const {}, input}) async {
              if (program == 'porelo') throw const ProcessException('porelo', [], 'missing', 2);
              if (arguments.first == 'clone') await Directory(arguments.last).create();
              if (arguments.first == 'bundle') await File(arguments[2]).writeAsString('access bundle');
              return (
                code: 0,
                out: switch (arguments.first) {
                  'symbolic-ref' => 'origin/trunk\n',
                  'rev-parse' => '${'b' * 40}\n',
                  _ => '',
                },
                err: '',
              );
            },
            activateVpn: (_, _, _, _) async {
              changes.add('root');
              return true;
            },
            setForgePassword: (_, _) async {
              changes.add('forge-password');
              return true;
            },
            restoreIdentity: (_) async {
              changes.add('identity');
              return '${scratch.path}/identity';
            },
          ),
        ),
      ),
    );
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('join-signing-key')), '${scratch.path}/signer.pub');
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('wizard-next')));
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('join-secrets')), secrets.path);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('wizard-next')));
    await World.settle(tester);
    final start = tester.widget<FilledButton>(find.byKey(const Key('wizard-start'))).onPressed!;
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.runAsync(() async => Function.apply(start, const []));
      await World.settle(tester);
      expect(find.text('Install Porelo on this computer'), findsOneWidget);
      expect(tester.widget<Wizard>(find.byType(Wizard)).actionSteps.single.state(), WizardActionState.refused);
      expect(changes, isEmpty);
      expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: unverified access must never change laptop keys, VPN, certificate trust, or host setup.
  test('no laptop step runs before project verify answers and a refusal leaves it untouched', () async {
    final entered = Completer<void>();
    final reply = Completer<Ran>();
    verify = () {
      entered.complete();
      return reply.future;
    };
    final joining = join.join();
    await entered.future;
    try {
      expect(
        laptopFiles(),
        isEmpty,
        reason: 'root, XDG_STATE_HOME, and XDG_RUNTIME_DIR must remain untouched until verification answers',
      );
      expect(changes, isEmpty);
      expect(remote.commands, isEmpty);
    } finally {
      reply.complete((code: 65, out: '', err: 'not_signed'));
      await joining;
    }
    expect(join.problem, contains('Porelo refused'));
    expect(changes, isEmpty);
    expect(remote.commands, isEmpty);
    expect(laptopFiles(), isEmpty);
  });

  // Harm: a substituted host CA could authorize an attacker through system-wide root trust.
  test('a CA with a different SHA-256 is refused before the root step with both fingerprints', () async {
    (answer['host'] as Map)['ca_sha256'] = '0' * 64;
    await join.join();
    expect(
      laptopFiles(),
      isEmpty,
      reason: 'a wrong signed CA must not create persistent join state or export an identity',
    );
    expect(changes.where((step) => step.startsWith('vpn:')), isEmpty);
    expect(join.problem, contains('0' * 64));
    expect(join.problem, contains(hostMatrixCaSha256));
    expect(remote.copies, 0);
    expect(remote.commands, isEmpty);
  });

  // Harm: authorized SSH keys cannot authenticate before the listed laptop VPN address is in use.
  test('the CA comes from the verified access commit and all SSH waits for the VPN', () async {
    final premature = <String>[];
    remote.beforeRun = (host, command) {
      if (!changes.contains('vpn:10.73.7.10')) premature.add('$host: $command');
    };
    await join.join();
    expect(premature, isEmpty, reason: 'SSH must wait for the listed VPN address');
    expect(remote.hosts.toSet(), {'10.73.7.1'});
    expect(join.joined, isTrue, reason: join.problem);
    expect(commands.singleWhere((command) => command.length > 1 && command[1] == 'show'), [
      'git',
      'show',
      '${'b' * 40}:access.yml',
    ]);
    expect(remote.commands.any((command) => command.contains('/etc/porelo-host/forge/ca.pem')), isFalse);
  });

  // Harm: a CA omitted from verified access must not be replaced by an unverified network certificate.
  test('missing access-file CA refuses without any laptop setup or SSH', () async {
    ((accessDocument['transports'] as Map)['matrix'] as Map).remove('ca_certificate');
    await join.join();
    expect(join.joined, isFalse);
    expect(join.problem, contains('CA'));
    expect(laptopFiles(), isEmpty);
    expect(changes, isEmpty);
    expect(remote.commands, isEmpty);
  });

  // Harm: the host must receive the same access history under both HEAD and its default branch.
  test('the real access bundle carries HEAD and the origin default branch at the verified commit', () async {
    final source = Directory('${scratch.path}/access-source')..createSync();
    Future<Ran> git(List<String> args, {String? directory}) => runHere(
      'git',
      ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', ...args],
      inDirectory: directory ?? source.path,
      environment: const {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TERMINAL_PROMPT': '0'},
    );
    expect((await git(['init', '--initial-branch=trunk'])).code, 0);
    await File('${source.path}/access.yml').writeAsString(jsonEncode(accessDocument));
    expect((await git(['add', 'access.yml'])).code, 0);
    expect((await git(['commit', '-m', 'Access fixture'])).code, 0);
    final commit = (await git(['rev-parse', 'HEAD'])).out.trim();
    answer['access_commit'] = commit;
    actualGit = (program, args, {inDirectory, environment = const {}, input}) => git([
      for (final arg in args) arg == 'https://example.org/team/access.git' ? source.path : arg,
    ], directory: inDirectory);
    await join.join();
    expect(join.joined, isTrue, reason: join.problem);
    final bundle = '${scratch.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}/access.bundle';
    final listed = await git(['bundle', 'list-heads', bundle]);
    expect(listed.code, 0);
    expect(const LineSplitter().convert(listed.out).toSet(), {'$commit HEAD', '$commit refs/heads/trunk'});
  });

  // Harm: a different clone tip would send access history that Porelo did not verify.
  test('an access commit different from the clone tip refuses before laptop setup', () async {
    answer['access_commit'] = 'c' * 40;
    await join.join();
    expect(join.joined, isFalse);
    expect(join.problem, contains('commit'));
    expect(laptopFiles(), isEmpty);
    expect(changes, isEmpty);
    expect(remote.commands, isEmpty);
  });

  // Harm: later SSH must trust exactly the signed host key at its VPN address.
  test('the written host trust file contains exactly the VPN address and signed SSH key', () async {
    await join.join();
    expect(join.joined, isTrue, reason: join.problem);
    final file = File('${poreloHostKnownHosts(environment: {'XDG_STATE_HOME': '${scratch.path}/state'})}.orchard');
    expect(await file.readAsString(), '10.73.7.1 ${hostValues()['ssh_host_key']}\n');
  });

  // Harm: a missing checker must not silently downgrade trust or run host setup.
  test('a missing local Porelo stops the join before laptop changes', () async {
    verify = () => throw const ProcessException('porelo', [], 'missing', 2);
    await join.join();
    expect(join.problem, 'Install Porelo on this computer');
    expect(changes, isEmpty);
    expect(remote.commands, isEmpty);
  });

  // Harm: without repository read access, no laptop setup or alternate trust may be attempted.
  test('denied access names the repository and invitation without changing the laptop', () async {
    cloneAllowed = false;
    await join.join();
    expect(join.problem, contains('https://example.org/team/access.git'));
    expect(join.problem, contains('GitHub’s invitation'));
    expect(join.problem, isNot(contains('private Git diagnostic')));
    expect(changes, isEmpty);
    expect(commands.where((command) => command.first == 'porelo'), isEmpty);
    expect(remote.commands, isEmpty);
  });

  // Harm: an access-history rollback must remain anchored to the previously joined revision.
  test('verification receives the retained access commit and refusal preserves it', () async {
    final record = File('${scratch.path}/joins/demo/joined.json');
    await record.parent.create(recursive: true);
    final contents = jsonEncode({
      'repository': 'https://example.org/team/access.git',
      'commit': 'a' * 40,
      'access_commit': 'c' * 40,
    });
    await record.writeAsString(contents);
    verify = () async => (code: 65, out: '', err: 'rewritten');
    await join.join();
    final verification = commands.singleWhere((command) => command.first == 'porelo');
    expect(verification[verification.indexOf('--access-since') + 1], 'c' * 40);
    expect(await record.readAsString(), contents);
    expect(changes, isEmpty);
  });

  // Harm: a canceled or refused password feed must not start a join with an unknown lasting password.
  test('a refused lasting password feed stops before upload and playbook', () async {
    passwordAccepted = false;
    await join.join();
    expect(join.problem, contains('lasting forge password was not set'));
    expect(remote.copies, 0);
    expect(remote.commands.where((command) => command.contains('ansible-playbook')), isEmpty);
    expect(File('${scratch.path}/joins/demo/joined.json').existsSync(), isFalse);
  });

  // Harm: removal or mismatched keys must not admit another laptop or offer an account repair.
  test('a dropped laptop is refused without setup or key creation', () async {
    answer['developers'] = <String, Object?>{};
    final before = Map.of(store.values);
    await join.join();
    expect(join.problem, contains('host refuses this laptop'));
    expect(changes, isEmpty);
    expect(remote.commands, isEmpty);
    expect(store.values, before);
  });

  // Harm: a join must target the developer account, omit admin forge migration, and retain its trust anchor.
  test('a listed laptop uploads an own-account join without forge migration and retains its access commit', () async {
    await join.join();
    expect(join.problem, isNull);
    expect(join.joined, isTrue, reason: join.accountRun?.problem);
    final watched = join.accountRun!.machine;
    expect(watched.whyNotReachableOn(windows: false), isNull);
    expect(watched.needsATunnel, isTrue);
    expect(watched.remoteSocket, '/run/user/1001/porelo/porelod.sock');
    expect(watched.socketPath, isNotEmpty);
    expect(watched.loginSshOptions, contains('UserKnownHostsFile="${poreloHostKnownHosts()}.orchard"'));
    expect(changes, ['identity', 'vpn:10.73.7.10', 'forge-password']);
    expect(remote.users.toSet(), {'dev'});
    expect(
      remote.commands.where((command) => command.contains('ansible-playbook')).single,
      contains('ansible-playbook -c local porelo.host.join -e porelo_project=demo'),
    );
    final setup = '${scratch.path}/${HostAct.ownAccount.setupPlace(project: 'demo')}';
    final machine = loadYaml(await File('$setup/machine.yml').readAsString()) as Map;
    expect(machine.containsKey('forge'), isFalse);
    expect(machine['access'], {'bundle': 'access.bundle'});
    expect(File('$setup/project.bundle').existsSync(), isTrue);
    expect(File('$setup/access.bundle').existsSync(), isTrue);
    expect(jsonDecode(await File('${scratch.path}/joins/demo/joined.json').readAsString())['access_commit'], 'b' * 40);
    expect(commands.where((command) => command.first == 'git').expand((command) => command), isNot(contains('push')));
  });

  // Harm: pinning must not follow a planted link and overwrite another local file.
  test('a linked host trust file is refused without changing its target', () async {
    final trust =
        '${poreloHostKnownHosts(environment: {'HOME': scratch.path, 'XDG_STATE_HOME': '${scratch.path}/state'})}.orchard';
    await Directory(File(trust).parent.path).create(recursive: true);
    final target = File('${scratch.path}/keep')..writeAsStringSync('keep this file');
    await Link(trust).create(target.path);
    await join.join();
    expect(await target.readAsString(), 'keep this file');
    expect(join.problem, contains('plain file'));
    expect(remote.copies, 0);
  });

  // Harm: retrying a stop must not repeat an upload or run the bring playbook in a developer account.
  test('the own-account stop resumes only its join playbook after a successful feed', () async {
    remote.wait = true;
    await join.join();
    final runner = join.accountRun!;
    expect(runner.stopCommand, isNotNull);
    expect(
      runner.stopCommand!.last,
      contains('/usr/local/bin/porelo-host-stop --stdin vault-new keys forge-central-token'),
    );
    expect(runner.stopCommand!.last, isNot(contains('/usr/bin/sudo')));
    final copies = remote.copies;
    runner.stopFed(1);
    await runner.resume();
    expect(runner.needs, isNotEmpty);
    runner.stopFed(0);
    remote.wait = false;
    await runner.resume();
    await join.rememberJoined();
    expect(runner.brought, isTrue);
    expect(remote.copies, copies);
    expect(remote.commands.where((command) => command.contains('porelo.host.join')), hasLength(2));
  });
}
