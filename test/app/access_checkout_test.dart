// Private checkout and bundle protection invoke chmod on Linux.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_frontend/src/app/commit_signing.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

import '../support/fake_signer_policy.dart';
import '../support/host_admin.dart';

/// Signing that accepts every commit: these tests prove the checkout's order, the Git test proves its signatures.
class _Trusting extends CommitSigning {
  _Trusting(super.policy);

  @override
  Future<void> checkOwn(String folder, String revision, ProjectSigners signers, {required Directory scratchIn}) async {}

  @override
  Future<void> checkArrived(
    String project,
    String folder,
    String revision,
    ProjectSigners signers, {
    required Directory scratchIn,
  }) async {}
}

void main() {
  late Directory scratch;
  late List<List<String>> commands;
  late bool dirty;
  late bool pushFails;
  late bool bundleFails;
  late Map<String, String> heads;
  late Map<String, String> staged;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('access-checkout-');
    commands = [];
    dirty = false;
    pushFails = false;
    bundleFails = false;
    heads = {};
    staged = {};
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<Ran> git(
    String program,
    List<String> args, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    // Past the signing options a commit carries, as Git reads them.
    while (args.first == '-c') {
      args = args.sublist(2);
    }
    commands.add(List.of(args));
    expect(environment['GIT_TERMINAL_PROMPT'], '0');
    if (args.first == 'clone') {
      final destination = Directory(args.last);
      await Directory('${destination.path}/.git').create();
      await File('${destination.path}/access.yml').writeAsString('# Private settings\ndevelopers: {} # Keep people\n');
      heads[destination.path] = File('${destination.path}/access.yml').readAsStringSync();
    }
    if (args.first == 'worktree' && args[1] == 'add') {
      await File('$inDirectory/access.yml').copy('${args[3]}/access.yml');
      heads[args[3]] = heads[inDirectory]!;
    }
    if (args.first == 'add') {
      expect(args, ['add', '--', 'access.yml']);
      staged[inDirectory!] = File('$inDirectory/access.yml').readAsStringSync();
    }
    if (args.first == 'commit') {
      expect(staged[inDirectory], isNot(heads[inDirectory]), reason: 'a commit needs changed staged bytes');
      heads[inDirectory!] = staged[inDirectory]!;
    }
    final out = switch (args.join(' ')) {
      'status --porcelain' => dirty ? ' M access.yml\n' : '',
      'config --get remote.origin.url' => 'https://example.org/team/access.git\n',
      'symbolic-ref refs/remotes/origin/HEAD' => 'refs/remotes/origin/main\n',
      'symbolic-ref --short HEAD' => 'main\n',
      'rev-list --left-right --count HEAD...refs/remotes/origin/main' => '0\t0\n',
      'diff --cached --quiet -- access.yml' => '',
      'rev-parse --verify HEAD^{commit}' => '${'b' * 40}\n',
      'rev-parse --verify refs/remotes/origin/main^{commit}' => '${'b' * 40}\n',
      _ => '',
    };
    if (args.contains('push') && pushFails) return (code: 1, out: '', err: 'private credential fixture');
    if (args.first == 'bundle' && bundleFails) return (code: 1, out: '', err: 'local bundle failure');
    if (args.contains('bundle')) await File(args[2]).writeAsString('bundle fixture');
    return (code: args.first == 'diff' && staged[inDirectory] != heads[inDirectory] ? 1 : 0, out: out, err: '');
  }

  Future<AccessCheckout> checkout() async {
    final core = FakeSignerPolicy(
      login: 'alice',
      key: (hostValues()['ssh_host_key']! as String).trim(),
      allowedSigners: ['alice namespaces="git" ${(hostValues()['ssh_host_key']! as String).trim()}'],
    );
    return AccessCheckout(
      root: '${scratch.path}/access',
      project: 'demo',
      repository: 'https://example.org/team/access.git',
      signers: core,
      signing: _Trusting(core),
      run: git,
    );
  }

  // Harm: retrying an already published configuration must not sign or push an extra commit.
  test('unchanged access bytes create no commit or push', () async {
    final access = await checkout();
    await access.open();
    await access.commitPushAndBundle('${scratch.path}/access.bundle');
    expect(commands.where((args) => args.first == 'commit' || args.first == 'push'), isEmpty);
    expect(File('${scratch.path}/access.bundle').existsSync(), isTrue);
  });

  // Harm: overwriting a dirty checkout loses private, unpublished work.
  test('dirty access work is preserved before fetching or editing', () async {
    final access = await checkout();
    await access.open();
    dirty = true;
    commands.clear();
    await expectLater(access.open(), throwsA(isA<WorkspaceRefused>()));
    expect(commands.any((args) => args.first == 'fetch'), isFalse);
  });

  // Harm: a bundle nobody centrally holds is followed on the server.
  test('a refused push produces no bundle and reveals no git diagnostics', () async {
    final access = await checkout();
    await access.open();
    await access.edit((source) => '$source\n# Changed access\n');
    pushFails = true;
    await expectLater(
      access.commitPushAndBundle('${scratch.path}/access.bundle'),
      throwsA(isA<WorkspaceRefused>().having((e) => e.words, 'safe refusal', isNot(contains('fixture')))),
    );
    expect(commands.any((args) => args.contains('bundle')), isFalse);
  });

  // Harm: a published access change loses external application after a local bundle failure.
  test('publication is reported before a local bundle failure', () async {
    final access = await checkout();
    await access.open();
    await access.edit((source) => '$source\n# Changed access\n');
    bundleFails = true;
    String? published;
    await expectLater(
      access.commitPushAndBundle(
        '${scratch.path}/access.bundle',
        onPublished: (revision) {
          expect(commands.any((args) => args.first == 'push'), isTrue);
          published = revision;
        },
      ),
      throwsA(isA<WorkspaceRefused>()),
    );
    expect(published, 'b' * 40, reason: 'external application must survive a failure after the push');
    bundleFails = false;
    commands.clear();
    final bundle = '${scratch.path}/access.bundle';
    await access.bundlePublished(bundle, published!);
    expect(await File(bundle).readAsString(), 'bundle fixture');
    expect((await File(bundle).stat()).mode & 0x1ff, 0x180);
    expect(commands.where((args) => args.first == 'commit' || args.first == 'push'), isEmpty);
  });

  // Harm: Retry could bundle a newer revision instead of the exact published access change.
  test('rebundling refuses a checkout that no longer names the published commit', () async {
    final access = await checkout();
    await access.open();
    await access.close();
    commands.clear();
    final bundle = '${scratch.path}/access.bundle';
    await expectLater(access.bundlePublished(bundle, 'c' * 40), throwsA(isA<WorkspaceRefused>()));
    expect(await File(bundle).exists(), isFalse);
    expect(commands.where((args) => args.first == 'bundle'), isEmpty);
  });
}
