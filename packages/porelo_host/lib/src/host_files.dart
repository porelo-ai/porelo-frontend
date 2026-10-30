import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'host_file_writer.dart';
import 'host_act.dart';
import 'host_file_name.dart';
import 'ssh_public_key.dart';

export 'host_file_name.dart' show HostFilesRefused;

/// Builds and publishes bundles checked against verified project-admin signers.
class HostFiles {
  /// Uses an owner-only writer and the selected Git environment.
  HostFiles({
    HostFileWriter? writer,
    path.Context? pathContext,
    this.gitEnvironment = const {'GIT_TERMINAL_PROMPT': '0'},
  }) : _writer = writer ?? HostFileWriter(),
       _paths = pathContext ?? path.context;

  /// Extra git environment variables, inherited alongside the person's configuration.
  final Map<String, String> gitEnvironment;

  final path.Context _paths;

  /// The local destination of a validated host file in the selected folder.
  String destinationPath(String folder, String name, {bool key = false}) {
    checkBasename(name, windows: _paths.style == path.Style.windows);
    final root = _paths.join(_paths.normalize(folder), 'porelo-host');
    return key ? _paths.join(root, 'keys', name) : _paths.join(root, name);
  }

  final HostFileWriter _writer;

  /// Rejects traversal and option-like names on both supported desktops.
  static void checkName(String name) => checkHostFileName(name);

  /// Refuses unsafe own-account project names.
  static void checkProjectName(String name) => checkOwnAccountProjectName(name);

  /// Matches ssh-keygen's SHA-256 fingerprint after parsing the complete supported key.
  static String signingFingerprint(String publicKey) {
    try {
      return sshSigningFingerprint(publicKey);
    } on FormatException catch (error) {
      throw HostFilesRefused(error.message);
    }
  }

  /// Refuses Windows devices, alternate streams and ambiguous trailing characters.
  static void checkBasename(String name, {bool? windows}) {
    checkName(name);
    if (!(windows ?? Platform.isWindows)) return;
    final stem = name.split('.').first.trimRight().toUpperCase();
    if (name.contains(':') ||
        name.endsWith('.') ||
        name.endsWith(' ') ||
        RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(stem)) {
      throw const HostFilesRefused(
        'A key file name must not name a Windows device or stream, or end with a dot or space.',
      );
    }
  }

  /// The project bundle's fixed name in an own-account setup directory.
  static const projectBundleFileName = 'project.bundle';

  /// The access repository bundle's fixed name beside an own-account machine file.
  static const accessBundleFileName = 'access.bundle';

  /// Validates central migration URLs and derives their unique Forgejo names.
  ///
  /// Refusals name the field rather than repeating a URL that may contain a credential.
  static List<({String name, String url})> migrationRepositories(List<String> urls) {
    if (urls.isEmpty) throw const HostFilesRefused('forge.repositories must not be empty for a bring.');
    final names = <String>{};
    final repositories = <({String name, String url})>[];
    for (var index = 0; index < urls.length; index++) {
      final url = urls[index];
      final uri = Uri.tryParse(url);
      final segment = uri == null || uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final name = segment.endsWith('.git') ? segment.substring(0, segment.length - 4) : segment;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.authority.contains('@') ||
          RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(url) ||
          !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name) ||
          name == '.' ||
          name == '..' ||
          uri.path.split('/').last != segment) {
        throw HostFilesRefused(
          'forge.repositories[$index].url must be a central HTTPS URL with a plain repository name, no user, query or fragment.',
        );
      }
      if (!names.add(name)) throw HostFilesRefused('forge.repositories[$index].name duplicates another repository.');
      repositories.add((name: name, url: url));
    }
    return repositories;
  }

  /// Returns [project]'s absolute bundle URL for [act], using the checked host [home] for an own-account act.
  static String bundleUrl(String project, {HostAct act = HostAct.legacyUp, String? home}) {
    checkName(project);
    if (act != HostAct.ownAccount) return path.posix.join(act.setupPlace(), '$project.bundle');
    if (home == null || !_isPlainHostHome(home)) {
      throw const HostFilesRefused('The own-account bundle URL needs the checked absolute host home.');
    }
    return path.posix.join(home, act.setupPlace(project: project), projectBundleFileName);
  }

  static bool _isPlainHostHome(String home) =>
      path.posix.isAbsolute(home) &&
      home != '/' &&
      path.posix.normalize(home) == home &&
      !RegExp(r'[\r\n\x00]').hasMatch(home);

  /// Returns [project]'s access bundle beside its project bundle, relative to the person's host home.
  static String accessBundleUrl(String project) {
    checkName(project);
    return path.posix.join(HostAct.ownAccount.setupPlace(project: project), accessBundleFileName);
  }

  /// Builds only the daemon's verified revision, without reading daemon-owned files.
  Future<List<int>> createBundle({
    required String project,
    required String url,
    required String commit,
    required List<String> adminSigners,
  }) async => (await createProjectSetup(project: project, url: url, commit: commit, adminSigners: adminSigners)).bytes;

  /// Reads the signed project file and builds its bundle from the same verified revision.
  Future<({List<int> bytes, String projectYaml})> createProjectSetup({
    required String project,
    required String url,
    required String commit,
    required List<String> adminSigners,
  }) async {
    checkBasename('$project.bundle', windows: _writer.isWindows);
    if (!RegExp(r'^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$').hasMatch(commit)) {
      throw const HostFilesRefused('The drive: this project has no valid verified commit to put on a server.');
    }
    if (url.trim().isEmpty || url.startsWith('-') || url.contains('\x00')) {
      throw const HostFilesRefused('The drive: the followed repository address cannot be read by this computer.');
    }
    if (adminSigners.isEmpty) throw const HostFilesRefused('Verified project-admin signers are required.');
    final chosen = adminSigners.map(signingFingerprint).toSet();
    final scratch = await _writer.createPrivateTemporary(Directory.systemTemp);
    try {
      final repository = path.join(scratch.path, 'repository');
      await _bundleGit(scratch, [
        'clone',
        '--no-checkout',
        '--no-local',
        '--',
        url,
        repository,
      ], timeout: const Duration(minutes: 10));
      final cloned = Directory(repository);
      await _bundleGit(cloned, ['cat-file', '-e', '$commit^{commit}']);
      await _checkSigner(scratch, cloned, commit, adminSigners: adminSigners, chosen: chosen);
      await _bundleGit(cloned, ['update-ref', '--no-deref', 'HEAD', commit]);
      await _bundleGit(cloned, ['branch', '-f', 'main', commit]);
      await _bundleGit(cloned, ['symbolic-ref', 'HEAD', 'refs/heads/main']);
      final bundle = File(path.join(scratch.path, '$project.bundle'));
      await _bundleGit(cloned, ['bundle', 'create', bundle.path, 'HEAD', 'main']);
      return (
        bytes: await bundle.readAsBytes(),
        projectYaml: await _bundleGit(cloned, ['show', '$commit:project.yml']),
      );
    } finally {
      await scratch.delete(recursive: true);
    }
  }

  /// Holds the commit to the key the host checks it against, so a wrong key is refused before renting.
  Future<void> _checkSigner(
    Directory scratch,
    Directory cloned,
    String commit, {
    required List<String> adminSigners,
    required Set<String> chosen,
  }) async {
    final allowed = File(path.join(scratch.path, 'allowed_signers'));
    await allowed.writeAsString(adminSigners.map((key) => 'porelo namespaces="git" $key\n').join());
    final answer = (await _bundleGit(cloned, [
      '-c',
      'gpg.ssh.allowedSignersFile=${allowed.path}',
      'log',
      '-1',
      '--format=%G?%n%GF',
      commit,
    ])).split('\n');
    final status = answer.first.trim();
    final signer = answer.length > 1 ? answer[1].trim() : '';
    if (status == 'G' && chosen.contains(signer)) return;
    if (status == 'N') {
      throw const HostFilesRefused('The drive: the verified commit is not signed, so the host would refuse it.');
    }
    if (signer.isEmpty) {
      throw const HostFilesRefused(
        'The drive: the verified commit’s signature could not be checked; ssh-keygen must be installed.',
      );
    }
    throw HostFilesRefused(
      'The verified commit is signed by $signer, outside the verified project-admin signer set. No server was rented.',
    );
  }

  Future<String> _bundleGit(
    Directory directory,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    const refused = HostFilesRefused(
      'The drive: Git could not read the followed repository and its verified commit or create the project bundle.',
    );
    Process process;
    try {
      process = await Process.start('git', arguments, workingDirectory: directory.path, environment: gitEnvironment);
    } on ProcessException {
      throw refused;
    }
    final stdout = process.stdout.transform(utf8.decoder).join();
    final output = Future.wait([stdout, process.stderr.drain<void>()]);
    try {
      if (await process.exitCode.timeout(timeout) != 0) throw refused;
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      final limit = timeout.inMinutes >= 1 ? '${timeout.inMinutes} minutes' : '${timeout.inSeconds} seconds';
      // The command, past a leading `-c name=value`.
      final command = arguments.first == '-c' ? arguments[2] : arguments.first;
      throw HostFilesRefused('The drive: git $command did not answer within $limit. No server was rented.');
    } finally {
      await output;
    }
    return stdout;
  }

  /// Stages a complete bundle beside its target before replacing a regular file.
  ///
  /// [ownFolder] is this desktop's own folder for the host's files: made where missing, kept private, and reached
  /// through no link; a drive's folder must exist already. [act] selects the bundle's fixed own-account name.
  Future<void> publishBundle({
    required String project,
    required String folder,
    required List<int> bytes,
    bool ownFolder = false,
    HostAct act = HostAct.legacyUp,
  }) async {
    if (act == HostAct.ownAccount) checkProjectName(project);
    final name = act == HostAct.ownAccount ? projectBundleFileName : '$project.bundle';
    final target = File(destinationPath(folder, name));
    if (ownFolder) {
      await _own(folder);
    } else {
      await _directory(Directory(folder), create: false);
      await _directory(target.parent);
    }
    Future<void> checkTarget() async {
      final type = await FileSystemEntity.type(target.path, followLinks: false);
      if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.file) _conflict(target.path);
    }

    await checkTarget();
    final staging = await _writer.createPrivateTemporary(target.parent);
    try {
      final prepared = File(path.join(staging.path, 'contents'));
      await prepared.writeAsBytes(bytes, flush: true);
      await _writer.protect(prepared);
      await checkTarget();
      await prepared.rename(target.path);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  static Never _conflict(String path) => throw HostFilesRefused(
    '$path already exists and differs or is not a regular file. Remove it or choose another folder.',
  );

  /// Makes [folder] and its `porelo-host` where missing, each kept private, and refuses one reached through a link.
  Future<void> _own(String folder) async {
    final normalized = _paths.normalize(_paths.absolute(folder));
    final root = Directory(_paths.join(normalized, 'porelo-host'));
    final missing = <Directory>[];
    // Up to the first folder that is one: a link on the way is refused before anything is made. A folder above it,
    // such as a configuration folder the person links elsewhere, is theirs.
    // This desktop's folders: the one holding every project's (`hosts`), the project's, and its porelo-host. Each is
    // looked at from the top down, so a link at one is seen before any path through it is.
    final own = [_paths.dirname(normalized), normalized, root.path];
    for (final each in own) {
      final type = await FileSystemEntity.type(each, followLinks: false);
      if (type == FileSystemEntityType.notFound) break;
      if (type != FileSystemEntityType.directory) _conflict(each);
    }
    for (var each = root; ; each = each.parent) {
      final type = await FileSystemEntity.type(each.path, followLinks: false);
      if (type == FileSystemEntityType.directory) break;
      // This desktop's own folders are never a link; above them a link to a folder is the person's own choice.
      if (type == FileSystemEntityType.link && !own.contains(each.path) && await Directory(each.path).exists()) break;
      if (type != FileSystemEntityType.notFound) _conflict(each.path);
      missing.add(each);
      if (each.parent.path == each.path) break;
    }
    await root.create(recursive: true);
    for (final made in missing.reversed) {
      await _writer.protectDirectory(made);
    }
    await _writer.protectDirectory(Directory(normalized));
    await _writer.protectDirectory(root);
  }

  static Future<void> _directory(Directory directory, {bool create = true}) async {
    final type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.directory) _conflict(directory.path);
    if (create) await directory.create(recursive: true);
    if (!create && type != FileSystemEntityType.directory) _conflict(directory.path);
  }
}
