import 'dart:io';

import 'machines.dart';
import 'desk.dart';
import 'forge.dart';

/// What one git or ssh command answered.
typedef Ran = ({int code, String out, String err});

/// Runs one program on this computer. Injectable, so the rules are judged without a real git.
typedef RunHere = Future<Ran> Function(
  String program,
  List<String> arguments, {
  String? inDirectory,
  Map<String, String> environment,
  String? input,
});

/// The default: the program itself, with this computer's environment plus [environment].
Future<Ran> runHere(
  String program,
  List<String> arguments, {
  String? inDirectory,
  Map<String, String> environment = const <String, String>{},
  String? input,
}) async {
  final process = await Process.start(program, arguments, workingDirectory: inDirectory, environment: environment);
  if (input != null) process.stdin.write(input);
  await process.stdin.close();
  final out = process.stdout.transform(const SystemEncoding().decoder).join();
  final err = process.stderr.transform(const SystemEncoding().decoder).join();
  return (code: await process.exitCode, out: await out, err: await err);
}

/// Why something on this computer did not happen, in words.
class WorkspaceRefused implements Exception {
  /// Constructor taking the sentence.
  const WorkspaceRefused(this.words);

  /// Why, in a sentence a person can act on.
  final String words;

  @override
  String toString() => words;
}

/// A key in the person's ssh agent, which signs a commit to the project's configuration.
class SigningKey {
  /// The public key, as the agent lists it: `ssh-ed25519 AAAA… comment`.
  final String publicKey;

  /// Its fingerprint, `SHA256:…`: what every machine's `follow --signed-by` pins.
  final String fingerprint;

  /// The comment, which is how a person tells two keys apart.
  final String comment;

  /// Whether git signs the person's commits with it already (`user.signingkey`).
  final bool gitSigns;

  /// What the person called it at their forge, where the forge lists it as one they sign with;
  /// null where it does not, which makes it *another key*.
  final String? atTheForge;

  /// Constructor taking every field.
  const SigningKey({
    required this.publicKey,
    required this.fingerprint,
    required this.comment,
    this.gitSigns = false,
    this.atTheForge,
  });

  /// How a person tells it apart: its comment, and whether the forge lists it as theirs.
  String get words => atTheForge != null
      ? '${comment.isEmpty ? fingerprint : comment}: your signing key at the forge${atTheForge!.isEmpty ? '' : ', "$atTheForge"'}'
      : (comment.isEmpty ? fingerprint : comment);

  /// The key itself, `ssh-ed25519 AAAA…`, without its comment: how two are compared.
  String get keyPart => publicKey.trim().split(RegExp(r'\s+')).take(2).join(' ');

  /// The same key, said to be the one git signs with.
  SigningKey get signedWithByGit => SigningKey(
    publicKey: publicKey,
    fingerprint: fingerprint,
    comment: comment,
    gitSigns: true,
    atTheForge: atTheForge,
  );

  /// The same key, said to be listed at the forge as [title].
  SigningKey listedAs(String title) => SigningKey(
    publicKey: publicKey,
    fingerprint: fingerprint,
    comment: comment,
    gitSigns: gitSigns,
    atTheForge: title,
  );
}

/// The keys [forge] lists as [login]'s signing keys; none where there is no forge, no login, or
/// the forge cannot be asked: the person then chooses, as before.
Future<List<ForgeSigningKey>> signingKeysAt(Forge? forge, String login) async {
  if (forge == null || login.isEmpty) return const <ForgeSigningKey>[];
  try {
    return await forge.signingKeys(login);
  } on Object {
    return const <ForgeSigningKey>[];
  }
}

/// [keys] in the order to offer them, each marked where [atTheForge] lists it as the person's: theirs
/// at the forge first, then the one git signs with, then any other. The one to choose without asking
/// is the first of the forge's, or the one git signs with, or the only one.
({List<SigningKey> keys, SigningKey? chosen}) orderSigningKeys(
  List<SigningKey> keys,
  List<ForgeSigningKey> atTheForge,
) {
  final marked = <SigningKey>[
    for (final each in keys)
      if (atTheForge.where((listed) => listed.keyPart == each.keyPart).firstOrNull case final listed?)
        each.listedAs(listed.title)
      else
        each,
  ];
  final ordered = <SigningKey>[
    ...marked.where((each) => each.atTheForge != null),
    ...marked.where((each) => each.atTheForge == null && each.gitSigns),
    ...marked.where((each) => each.atTheForge == null && !each.gitSigns),
  ];
  final chosen = ordered.isEmpty
      ? null
      : (ordered.first.atTheForge != null || ordered.first.gitSigns || ordered.length == 1 ? ordered.first : null);
  return (keys: ordered, chosen: chosen);
}

/// A project's repository cloned on the person's own computer, where its configuration is changed.
///
/// **Git work on `project.yml` happens here and never on a machine**: it is signed
/// with the person's key, through their agent, and pushed with their login. **The forge token never
/// appears on a command line**: git asks for it through an askpass program that reads it from the
/// environment of that one git process.
class ProjectWorkspace {
  /// Constructor taking the repository, the token that reaches it, where working folders live, and
  /// how programs are run.
  ProjectWorkspace(this.repository, this._token, {required this.root, RunHere? run, String? sshDirectory})
    : _run = run ?? runHere,
      sshDirectory = sshDirectory ?? desk.join(<String>[desk.home, '.ssh']);

  /// Where the keys this interface made for machines are kept, `porelo-<machine>` each.
  final String sshDirectory;

  /// The repository on the forge.
  final ForgeRepository repository;

  final String _token;
  final RunHere _run;

  /// Where the working folders are kept, one per repository.
  final String root;

  /// This repository's working folder, always under [root]: a name that is not `owner/name` never
  /// becomes a path here.
  String get folder {
    if (!GitHub.isFullName(repository.fullName)) {
      throw ForgeRefused('"${repository.fullName}" is not a repository name, so it gets no folder here.');
    }
    return '$root/${repository.fullName}';
  }

  /// The file edited here.
  String get projectFile => '$folder/project.yml';

  /// Clones it, or brings an existing clone up to the forge's default branch.
  Future<void> open() async {
    if (await Directory('$folder/.git').exists()) {
      await _git(<String>['fetch', 'origin', repository.defaultBranch], withToken: true);
      await _git(<String>['checkout', '-B', repository.defaultBranch, 'origin/${repository.defaultBranch}']);
      return;
    }
    await Directory(folder).parent.create(recursive: true);
    await _git(
      <String>['clone', '--branch', repository.defaultBranch, repository.httpsUrl, folder],
      withToken: true,
      inFolder: false,
    );
  }

  /// What `project.yml` holds now, or null where there is none yet.
  Future<String?> read() async {
    final file = File(projectFile);
    return await file.exists() ? file.readAsString() : null;
  }

  /// Writes [text] as `project.yml`, without committing it.
  Future<void> write(String text) => File(projectFile).writeAsString(text);

  /// What [name], a file at the repository's root, holds, or null where there is none.
  Future<String?> readFile(String name) async {
    final file = File('$folder/$name');
    return await file.exists() ? file.readAsString() : null;
  }

  /// Writes [text] as [name] at the repository's root, without committing it.
  Future<void> writeFile(String name, String text) => File('$folder/$name').writeAsString(text);

  /// Takes pending work [name] from a machine's gate, as the bundle it handed out, into this clone
  /// at `refs/porelo/incoming/<name>`, and answers what it changes against the default branch.
  Future<String> takeBundle(List<int> bundle, String name) async {
    final here = await Directory.systemTemp.createTemp('porelo-bundle-');
    try {
      final file = File('${here.path}/pending.bundle');
      await file.writeAsBytes(bundle);
      final ref = 'refs/porelo/incoming/$name';
      await _git(<String>['fetch', file.path, '$ref:$ref']);
      return (await _git(<String>['diff', 'HEAD...$ref'])).out;
    } finally {
      await here.delete(recursive: true);
    }
  }

  /// Merges pending work [name] onto the default branch as a commit **signed with [key]**, and
  /// pushes it: what a machine that only reads the project's repository cannot do itself.
  Future<String> mergeAndPush(String name, String message, SigningKey key, {required String login}) async {
    final named = await _run('git', <String>['config', 'user.email'], inDirectory: folder);
    await _git(<String>[
      '-c',
      'gpg.format=ssh',
      '-c',
      'user.signingkey=key::${key.publicKey}',
      if (named.out.trim().isEmpty) ...<String>[
        '-c',
        'user.name=$login',
        '-c',
        'user.email=$login@users.noreply.github.com',
      ],
      'merge',
      '--no-ff',
      '-S',
      '-m',
      message,
      'refs/porelo/incoming/$name',
    ]);
    final commit = (await _git(<String>['rev-parse', 'HEAD'])).out.trim();
    await _git(<String>['push', 'origin', 'HEAD:${repository.defaultBranch}'], withToken: true);
    return commit;
  }

  /// What would be committed, as `git diff` shows it, against the last commit.
  Future<String> diff() async {
    await _git(<String>['add', '--intent-to-add', 'project.yml']);
    return (await _git(<String>['diff', '--', 'project.yml'])).out;
  }

  /// The keys in the person's ssh agent they can sign with, each with its fingerprint: **the one git
  /// signs their commits with first**, and **never a key this interface made to log into a machine**
  /// (`~/.ssh/porelo-<machine>`), which a desktop keyring loads into the agent all the same.
  Future<List<SigningKey>> signingKeys() async {
    final all = await _agentKeys();
    final machines = _machineKeys();
    final own = <SigningKey>[
      for (final each in all)
        if (!machines.contains(each.keyPart)) each,
    ];
    if (own.isEmpty) {
      throw const WorkspaceRefused(
        'Your ssh agent holds only the keys this computer made to log into '
        'machines. Add your own key with ssh-add, and it can sign.',
      );
    }
    final git = await _gitSigningKey();
    return <SigningKey>[
      for (final each in own)
        if (each.keyPart == git) each.signedWithByGit,
      for (final each in own)
        if (each.keyPart != git) each,
    ];
  }

  /// The key parts of the keys this interface made for machines.
  Set<String> _machineKeys() {
    final directory = Directory(sshDirectory);
    if (!directory.existsSync()) return const <String>{};
    return <String>{
      for (final file in directory.listSync().whereType<File>())
        if (file.uri.pathSegments.last.startsWith('porelo-') && file.path.endsWith('.pub'))
          file.readAsStringSync().trim().split(RegExp(r'\s+')).take(2).join(' '),
    };
  }

  /// The key part of the key git signs with, from `user.signingkey`: written as the key itself
  /// (`key::ssh-ed25519 AAAA…`) or as the file holding it. Null where git names none.
  Future<String?> _gitSigningKey() async {
    final said = (await _run('git', <String>['config', '--global', '--get', 'user.signingkey'])).out.trim();
    if (said.isEmpty) return null;
    if (said.startsWith('key::')) return said.substring(5).trim().split(RegExp(r'\s+')).take(2).join(' ');
    final path = desk.expandHome(said);
    for (final candidate in <String>[path, '$path.pub']) {
      final file = File(candidate);
      if (file.existsSync()) {
        final text = file.readAsStringSync().trim();
        if (text.startsWith('ssh-')) return text.split(RegExp(r'\s+')).take(2).join(' ');
      }
    }
    return null;
  }

  /// Every key the person's ssh agent holds, each with its fingerprint.
  Future<List<SigningKey>> _agentKeys() async {
    final listed = await _run(openSsh('ssh-add'), <String>['-L']);
    if (listed.code != 0) {
      throw WorkspaceRefused(
        listed.out.contains('no identities') || listed.err.contains('no identities')
            ? 'Your ssh agent holds no key. Add one with ssh-add, and it can sign.'
            : 'Your ssh agent could not be asked: ${listed.err.trim().isEmpty ? listed.out.trim() : listed.err.trim()}',
      );
    }
    final keys = <SigningKey>[];
    for (final line in listed.out.split('\n').map((each) => each.trim()).where((each) => each.isNotEmpty)) {
      final printed = await _run(openSsh('ssh-keygen'), <String>['-lf', '-'], input: '$line\n');
      final fields = printed.out.trim().split(' ');
      final parts = line.split(' ');
      keys.add(
        SigningKey(
          publicKey: line,
          fingerprint: fields.length > 1 ? fields[1] : '',
          comment: parts.length > 2 ? parts.sublist(2).join(' ') : '',
        ),
      );
    }
    return keys;
  }

  /// Commits `project.yml`, **signed with [key] through the person's agent**, and pushes it straight
  /// to the default branch: a merge made by the forge would be signed by the
  /// forge's key, which every machine refuses. Answers the commit.
  Future<String> commitAndPush(
    String message,
    SigningKey key, {
    required String login,
    List<String> files = const <String>['project.yml'],
  }) async {
    await _git(<String>['add', ...files]);
    final named = await _run('git', <String>['config', 'user.email'], inDirectory: folder);
    // A commit made here whose push failed (a token without the right to write) is
    // made again over itself, with the key and words of now, rather than refused as nothing to commit.
    final staged = await _run('git', <String>['diff', '--cached', '--quiet', '--', ...files], inDirectory: folder);
    final ahead = await _run('git', <String>[
      'rev-list',
      '--count',
      'origin/${repository.defaultBranch}..HEAD',
    ], inDirectory: folder);
    final again = staged.code == 0 && (int.tryParse(ahead.out.trim()) ?? 0) > 0;
    await _git(<String>[
      '-c', 'gpg.format=ssh',
      '-c', 'user.signingkey=key::${key.publicKey}',
      // The person's own name and address where git knows them; the forge's no-reply address where not.
      if (named.out.trim().isEmpty) ...<String>[
        '-c',
        'user.name=$login',
        '-c',
        'user.email=$login@users.noreply.github.com',
      ],
      'commit', '-S', if (again) '--amend', '-m', message, if (!again) ...<String>['--', ...files],
    ]);
    final commit = (await _git(<String>['rev-parse', 'HEAD'])).out.trim();
    await _git(<String>['push', 'origin', 'HEAD:${repository.defaultBranch}'], withToken: true);
    return commit;
  }

  Future<Ran> _git(List<String> arguments, {bool withToken = false, bool inFolder = true}) async {
    Directory? asking;
    final environment = <String, String>{'GIT_TERMINAL_PROMPT': '0'};
    try {
      if (withToken) {
        // An askpass program private to this one git process: the token reaches git through its
        // environment, never an argument another user of this computer could read.
        asking = await Directory.systemTemp.createTemp('porelo-askpass-');
        final program = File('${asking.path}/askpass');
        await program.writeAsString(
          '#!/bin/sh\ncase "\$1" in\n  Username*) echo x-access-token ;;\n  *) printf \'%s\\n\' "\$PORELO_FORGE_TOKEN" ;;\nesac\n',
        );
        // Windows has no chmod; a temporary folder there is the person's own already.
        if (!desk.isWindows) await _run('chmod', <String>['700', asking.path, program.path]);
        environment['GIT_ASKPASS'] = program.path;
        environment['PORELO_FORGE_TOKEN'] = _token;
      }
      final ran = await _run('git', arguments, inDirectory: inFolder ? folder : null, environment: environment);
      if (ran.code != 0) {
        final said = ran.err.trim().isEmpty ? ran.out.trim() : ran.err.trim();
        // A push the token may not make: which right, for which repository, and where it is given.
        if (arguments.contains('push') &&
            (said.contains('returned error: 403') || said.contains('Permission to') || said.contains('Write access'))) {
          throw WorkspaceRefused(
            'This token may not push to ${repository.fullName}: it lacks Contents: Read and '
            'write there. Give it that at GitHub → Settings → Developer settings → Fine-grained tokens → this '
            'token → Repository permissions. (git: $said)',
          );
        }
        // Git's own words, never the token: git does not print what askpass answered.
        throw WorkspaceRefused(
          'git ${arguments.firstWhere((each) => !each.startsWith('-') && !each.contains('='), orElse: () => '')} '
          'did not work: $said',
        );
      }
      return ran;
    } finally {
      await asking?.delete(recursive: true);
    }
  }
}
