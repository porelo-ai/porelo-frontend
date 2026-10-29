import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import '../support/host_admin.dart';

void main() {
  late Directory scratch;
  late List<List<String>> commands;
  late bool signing;
  late bool dirty;
  late bool pushFails;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('access-checkout-');
    commands = [];
    signing = true;
    dirty = false;
    pushFails = false;
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<Ran> git(
    String program,
    List<String> args, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    commands.add(List.of(args));
    expect(environment['GIT_TERMINAL_PROMPT'], '0');
    if (args.first == 'clone') {
      final destination = Directory(args.last);
      await Directory('${destination.path}/.git').create();
      await File('${destination.path}/access.yml').writeAsString('# Private settings\ndevelopers: {} # Keep people\n');
    }
    final out = switch (args.join(' ')) {
      'config --bool --get commit.gpgsign' => signing ? 'true\n' : '',
      'config --get user.signingkey' => signing ? 'own-agent-key\n' : '',
      'status --porcelain' => dirty ? ' M access.yml\n' : '',
      'config --get remote.origin.url' => 'https://example.org/team/access.git\n',
      'symbolic-ref --short refs/remotes/origin/HEAD' => 'origin/main\n',
      'symbolic-ref --short HEAD' => 'main\n',
      'rev-list --left-right --count HEAD...origin/main' => '0\t0\n',
      'diff --cached --quiet -- access.yml' => '',
      _ => '',
    };
    if (args.contains('log')) {
      return (
        code: 0,
        out: 'G\n${HostFiles.signingFingerprint(File('${scratch.path}/signer.pub').readAsStringSync())}\n',
        err: '',
      );
    }
    if (args.contains('push') && pushFails) return (code: 1, out: '', err: 'private credential fixture');
    if (args.contains('bundle')) await File(args[2]).writeAsString('bundle fixture');
    return (code: args.first == 'diff' ? 1 : 0, out: out, err: '');
  }

  Future<AccessCheckout> checkout() async {
    await File('${scratch.path}/signer.pub').writeAsString(hostValues()['ssh_host_key']! as String);
    return AccessCheckout(
      root: '${scratch.path}/access',
      project: 'demo',
      repository: 'https://example.org/team/access.git',
      signingKey: File('${scratch.path}/signer.pub'),
      run: git,
    );
  }

  // Harm: private machine settings enter the public repository, or leave without a trusted signature.
  test('only the private access file is edited signed pushed and bundled', () async {
    final access = await checkout();
    await access.open();
    await access.writeHost(PreparedHost.read(hostValues()), '#demo:matrix.orchard.porelo.internal');
    await access.commitPushAndBundle('${scratch.path}/access.bundle');
    final contents = File('${access.folder}/access.yml').readAsStringSync();
    expect(contents, contains('# Private settings'));
    expect(contents, contains('# Keep people'));
    final yaml = loadYaml(contents);
    expect(yaml['host'], Map.of(hostValues())..remove('homeserver'));
    expect(yaml['transports']['matrix'], {
      'homeserver': 'https://matrix.orchard.porelo.internal:8448',
      'room': '#demo:matrix.orchard.porelo.internal',
    });
    expect(commands.singleWhere((args) => args.first == 'commit'), contains('-S'));
    expect(commands.singleWhere((args) => args.first == 'push'), ['push', 'origin', 'HEAD:main']);
    expect(commands.expand((command) => command), isNot(contains('project.yml')));
    expect((await Directory(access.folder).stat()).mode & 0x1ff, 0x1c0);
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
    pushFails = true;
    await expectLater(
      access.commitPushAndBundle('${scratch.path}/access.bundle'),
      throwsA(isA<WorkspaceRefused>().having((e) => e.words, 'safe refusal', isNot(contains('fixture')))),
    );
    expect(commands.any((args) => args.contains('bundle')), isFalse);
  });

  // Harm: an unsigned access update fails verification only after it leaves this computer.
  test('missing git signing is refused before any access edit', () async {
    final access = await checkout();
    signing = false;
    await expectLater(
      access.open(),
      throwsA(isA<WorkspaceRefused>().having((e) => e.words, 'signing', contains('signing'))),
    );
    expect(commands.any((args) => args.contains('commit')), isFalse);
  });
}
