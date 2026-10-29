// Private checkout and bundle protection invoke chmod on Linux.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import '../support/host_admin.dart';
import '../support/host_matrix_ca.dart';

void main() {
  late Directory scratch;
  late List<List<String>> commands;
  late bool signing;
  late bool dirty;
  late bool pushFails;
  late Map<String, String> heads;
  late Map<String, String> staged;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('access-checkout-');
    commands = [];
    signing = true;
    dirty = false;
    pushFails = false;
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
      'config --bool --get commit.gpgsign' => signing ? 'true\n' : '',
      'config --get user.signingkey' => signing ? 'own-agent-key\n' : '',
      'status --porcelain' => dirty ? ' M access.yml\n' : '',
      'config --get remote.origin.url' => 'https://example.org/team/access.git\n',
      'symbolic-ref refs/remotes/origin/HEAD' => 'refs/remotes/origin/main\n',
      'symbolic-ref --short HEAD' => 'main\n',
      'rev-list --left-right --count HEAD...refs/remotes/origin/main' => '0\t0\n',
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
    return (code: args.first == 'diff' && staged[inDirectory] != heads[inDirectory] ? 1 : 0, out: out, err: '');
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

  String? matrixTransport;
  for (final folder in (Platform.environment['PATH'] ?? '').split(Platform.isWindows ? ';' : ':')) {
    final candidate = File('$folder/porelo-message-transport-matrix');
    if (candidate.existsSync() && (candidate.statSync().mode & 0x49) != 0) {
      matrixTransport = candidate.absolute.path;
      break;
    }
  }
  // Harm: signed access settings can pass local checks but still be refused by the installed transport.
  test(
    'the written Matrix block is accepted by the installed transport settings check',
    () async {
      final access = await checkout();
      await access.open();
      await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
      final written = loadYaml(await File('${access.folder}/access.yml').readAsString());
      final ran = await runHere(matrixTransport!, ['settings'], input: jsonEncode(written['transports']['matrix']));
      expect(ran.code, 0, reason: ran.err);
      expect(
        jsonDecode(ran.out)['refused'],
        <Object?>[],
        reason: 'the actual transport must accept the written settings',
      );
    },
    skip: matrixTransport == null
        ? 'porelo-message-transport-matrix is not on PATH; the settings contract check needs the installed transport'
        : Platform.environment['PORELO_MATRIX_SETTINGS_TEST'] != '1'
        ? 'set PORELO_MATRIX_SETTINGS_TEST=1 to check the written block with the installed transport'
        : null,
  );

  // Harm: a digest alone can bless malformed DER or multiple certificates as the host's trust.
  for (final bad in ['missing', 'chain', 'not a certificate', 'two DER certificates', 'digest mismatch']) {
    test('invalid host CA ($bad) leaves access bytes untouched', () async {
      final access = await checkout();
      await access.open();
      final file = File('${access.folder}/access.yml');
      final before = await file.readAsBytes();
      final der = base64Decode(hostMatrixCa.split('\n').where((line) => !line.startsWith('-----')).join());
      final bytes = bad == 'two DER certificates' ? [...der, ...der] : [0x30, 0x03, 0x02, 0x01, 0x01];
      final pem = switch (bad) {
        'missing' => null,
        'chain' => '$hostMatrixCa$hostMatrixCa',
        'digest mismatch' => hostMatrixCa,
        _ =>
          '-----BEGIN CERTIFICATE-----\n${base64Encode(bytes).replaceAllMapped(RegExp('.{1,64}'), (m) => '${m[0]}\n')}-----END CERTIFICATE-----\n',
      };
      final values = {
        ...matrixHostValues(),
        'ca_sha256': bad == 'digest mismatch' ? '0' * 64 : sha256.convert(bytes).toString(),
      };
      commands.clear();
      await expectLater(access.writeHost(PreparedHost.read(values), pem), throwsA(isA<WorkspaceRefused>()));
      expect(await file.readAsBytes(), before, reason: 'refusal must precede any access edit');
      expect(commands, isEmpty);
    });
  }

  // Harm: private machine settings enter the public repository, or leave without a trusted signature.
  test('only the private access file is edited signed pushed and bundled', () async {
    final access = await checkout();
    await access.open();
    await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
    final contents = File('${access.folder}/access.yml').readAsStringSync();
    final mode = (await Directory(access.folder).stat()).mode & 0x1ff;
    await access.commitPushAndBundle('${scratch.path}/access.bundle');
    expect(contents, contains('# Private settings'));
    expect(contents, contains('# Keep people'));
    final yaml = loadYaml(contents);
    expect(yaml['host'], Map.of(matrixHostValues())..remove('homeserver'));
    expect(yaml['transports']['matrix'], {
      'homeserver': 'https://matrix.orchard.porelo.internal:8448',
      'room': '#porelo-demo:matrix.orchard.porelo.internal',
      'registration_token_file': '~/.config/porelo/matrix/host-registration-token',
      'ca_certificate': hostMatrixCa,
    });
    expect((yaml['transports']['matrix'].nodes['ca_certificate'] as YamlScalar).style, ScalarStyle.LITERAL);
    expect(commands.singleWhere((args) => args.first == 'commit'), contains('-S'));
    expect(commands.singleWhere((args) => args.first == 'push'), ['push', 'origin', 'HEAD:main']);
    expect(commands.expand((command) => command), isNot(contains('project.yml')));
    expect(mode, 0x1c0);
    expect(File('${scratch.path}/access.bundle').existsSync(), isTrue);
  });

  // Harm: obsolete keys make Matrix refuse a signed block; reformatting a CA can corrupt its trust.
  for (final newline in [true, false]) {
    test('the exact Matrix block preserves comments and PEM bytes (final newline: $newline)', () async {
      final access = await checkout();
      await access.open();
      final file = File('${access.folder}/access.yml');
      await file.writeAsString('''# Private settings
developers: {} # Keep people
transports:
  # Matrix trust
  matrix:
    homeserver: https://old.example.org # Keep server explanation
    room: '#old:old.example.org' # Keep room explanation
    tls_verify: false # Keep verification rationale
    ca_file: /old/ca.pem # Keep earlier CA rationale
    unknown_key:
      # Keep nested rationale
      nested: obsolete # Keep nested value rationale
  other: {keep: yes} # Keep other transports
''');
      final pem = newline ? hostMatrixCa : hostMatrixCa.trimRight();
      await access.writeHost(PreparedHost.read(matrixHostValues()), pem);
      final contents = await file.readAsString();
      final matrix = loadYaml(contents)['transports']['matrix'] as YamlMap;
      expect(matrix.keys.toSet(), {'homeserver', 'room', 'registration_token_file', 'ca_certificate'});
      expect(matrix['ca_certificate'], pem, reason: 'the signed YAML must reproduce the exact PEM bytes');
      expect((matrix.nodes['ca_certificate'] as YamlScalar).style, ScalarStyle.LITERAL);
      expect(matrix['room'], '#porelo-demo:matrix.orchard.porelo.internal');
      for (final comment in [
        '# Private settings',
        '# Keep people',
        '# Matrix trust',
        '# Keep server explanation',
        '# Keep room explanation',
        '# Keep other transports',
        '# Keep verification rationale',
        '# Keep earlier CA rationale',
        '# Keep nested rationale',
        '# Keep nested value rationale',
      ]) {
        expect(contents, contains(comment));
      }
      expect(loadYaml(contents)['transports']['other']['keep'], 'yes');
    });
  }

  // Harm: an earlier flow mapping must not force the certificate back into an escaped string.
  test('an existing flow mapping becomes a Matrix block with a literal CA', () async {
    final access = await checkout();
    await access.open();
    final file = File('${access.folder}/access.yml');
    await file.writeAsString('''transports: {matrix: {homeserver: https://old.example.org, # Keep trust explanation
room: '#old:old.example.org', tls_verify: false}} # Keep transport note
''');
    await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
    final contents = await file.readAsString();
    final matrix = loadYaml(contents)['transports']['matrix'] as YamlMap;
    expect(matrix['ca_certificate'], hostMatrixCa);
    expect((matrix.nodes['ca_certificate'] as YamlScalar).style, ScalarStyle.LITERAL);
    expect(contents, contains('# Keep transport note'));
    expect(contents, contains('# Keep trust explanation'));
  });

  // Harm: a valid existing flow document must not block bringing a project or lose private settings.
  for (final populated in [false, true]) {
    test('a flow document becomes a literal Matrix block (populated: $populated)', () async {
      final access = await checkout();
      await access.open();
      final file = File('${access.folder}/access.yml');
      await file.writeAsString(
        populated
            ? "{developers: {}, transports: {matrix: {tls_verify: false # Keep draft rationale\n}}} # Keep root note\n"
            : '{}\n',
      );
      await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
      final contents = await file.readAsString();
      final yaml = loadYaml(contents);
      final matrix = yaml['transports']['matrix'] as YamlMap;
      expect(matrix.keys.toSet(), {'homeserver', 'room', 'registration_token_file', 'ca_certificate'});
      expect(matrix['ca_certificate'], hostMatrixCa);
      expect((matrix.nodes['ca_certificate'] as YamlScalar).style, ScalarStyle.LITERAL);
      if (populated) {
        expect(yaml['developers'], isEmpty);
        expect(contents, contains('# Keep draft rationale'));
        expect(contents, contains('# Keep root note'));
      }
    });
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
    await access.writeHost(PreparedHost.read(matrixHostValues()), hostMatrixCa);
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
