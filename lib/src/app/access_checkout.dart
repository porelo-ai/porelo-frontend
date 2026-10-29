import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'run_here.dart';
import 'host_matrix_settings.dart';

/// The person's private access checkout, signed and pushed through their own Git configuration.
class AccessCheckout {
  /// Names the signed project's access repository and the public key trusted for this bring.
  AccessCheckout({
    required this.root,
    required this.project,
    required this.repository,
    required this.signingKey,
    RunHere? run,
    HostFileWriter? writer,
  }) : _run = run ?? runHere,
       _writer = writer ?? HostFileWriter();

  /// The private directory containing the per-project checkouts.
  final String root;

  /// The project's safe directory name.
  final String project;

  /// The credential-free repository address from the verified project file.
  final String repository;

  /// The public key that must verify access commits before they leave this computer.
  final File signingKey;
  final RunHere _run;
  final HostFileWriter _writer;
  String? _branch;
  String? _allowedSigners;
  String? _fingerprint;

  /// The checkout, outside the public project repository and support records.
  String get folder {
    HostFiles.checkBasename(project);
    return path.join(root, project);
  }

  /// Rejects credentials and unsafe Git source syntax without repeating the input.
  static void checkRepository(String repository) {
    final uri = Uri.tryParse(repository);
    final https = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;
    final ssh = RegExp(r'^git@[A-Za-z0-9][A-Za-z0-9.-]*:[A-Za-z0-9_./-]+$').hasMatch(repository);
    if ((!https && !ssh) ||
        (https && (uri.hasQuery || uri.hasFragment)) ||
        RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(repository)) {
      throw const WorkspaceRefused('access.repository must be a credential-free HTTPS or git SSH repository.');
    }
  }

  /// Clones privately or fast-forwards a clean checkout; never resets unpublished work.
  Future<void> open() async {
    checkRepository(repository);
    await privateDirectory(Directory(root), writer: _writer);
    final directory = Directory(folder);
    final type = await FileSystemEntity.type(folder, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await privateDirectory(directory, writer: _writer);
      await _git(['clone', '--', repository, folder], inCheckout: false);
    } else if (type != FileSystemEntityType.directory ||
        await FileSystemEntity.type('$folder/.git', followLinks: false) != FileSystemEntityType.directory) {
      throw const WorkspaceRefused('The access checkout must be a plain Git directory, without links.');
    }
    await _writer.protectDirectory(directory);
    if ((await _git(['status', '--porcelain'])).out.isNotEmpty) {
      throw const WorkspaceRefused(
        'The access checkout has unpublished changes. Keep or publish them with your own Git before continuing.',
      );
    }
    if ((await _git(['config', '--get', 'remote.origin.url'])).out.trim() != repository) {
      throw const WorkspaceRefused('The access checkout origin differs from access.repository.');
    }
    final signing = await _git(['config', '--bool', '--get', 'commit.gpgsign'], optional: true);
    final key = await _git(['config', '--get', 'user.signingkey'], optional: true);
    if (signing.code != 0 || signing.out.trim() != 'true' || key.code != 0 || key.out.trim().isEmpty) {
      throw const WorkspaceRefused(
        'Set up your own Git commit signing (commit.gpgsign and user.signingkey) before bringing this project.',
      );
    }
    final branch = (await _git(['symbolic-ref', '--short', 'refs/remotes/origin/HEAD'])).out.trim();
    if (!RegExp(r'^origin/[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(branch) || branch.contains('..')) {
      throw const WorkspaceRefused('The access repository has no safe default branch.');
    }
    _branch = branch.substring('origin/'.length);
    if ((await _git(['symbolic-ref', '--short', 'HEAD'])).out.trim() != _branch) {
      throw const WorkspaceRefused(
        'The access checkout must be on its default branch. Its current branch was preserved.',
      );
    }
    final ahead = (await _git(['rev-list', '--left-right', '--count', 'HEAD...$branch'])).out
        .trim()
        .split(RegExp(r'\s+'));
    if (ahead.length != 2 || int.tryParse(ahead[0]) != 0 || int.tryParse(ahead[1]) == null) {
      throw const WorkspaceRefused(
        'The access checkout has unpublished commits. Publish them with your own Git before continuing.',
      );
    }
    await _git(['fetch', 'origin']);
    await _git(['merge', '--ff-only', branch]);
    _fingerprint = HostFiles.signingFingerprint(await signingKey.readAsString());
    _allowedSigners = '$folder/.git/porelo-bring-signers';
    final public = (await signingKey.readAsString()).trim().split(RegExp(r'\s+')).take(2).join(' ');
    await File(_allowedSigners!).writeAsString('porelo namespaces="git" $public\n');
    await _verifyHead();
    await _plainAccessFile();
  }

  Future<void> _verifyHead() async {
    final signature = (await _git([
      '-c',
      'gpg.ssh.allowedSignersFile=$_allowedSigners',
      'log',
      '-1',
      '--format=%G?%n%GF',
      'HEAD',
    ])).out.trim().split('\n');
    if (signature.length != 2 || signature[0] != 'G' || signature[1] != _fingerprint) {
      throw const WorkspaceRefused(
        'The access commit must be signed by the chosen project signing key. Nothing was pushed.',
      );
    }
  }

  Future<File> _plainAccessFile() async {
    final file = File('$folder/access.yml');
    if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) {
      throw const WorkspaceRefused('access.yml must be a plain file in the private access checkout.');
    }
    await _writer.protect(file);
    return file;
  }

  /// Updates public host values and Matrix settings while preserving comments and other settings.
  Future<void> writeHost(PreparedHost host, String? caCertificate) async {
    if (_branch == null) throw const WorkspaceRefused('Open and verify the access checkout first.');
    checkHostMatrixCa(host, caCertificate);
    final file = await _plainAccessFile();
    final original = await file.readAsString();
    final YamlEditor editor;
    final List<String> comments;
    try {
      final root = loadYamlNode(original);
      if (root is! YamlMap) throw const FormatException();
      comments = _yamlComments(original, root);
      editor = YamlEditor(original);
      void mapping(List<String> parts) {
        final value = editor.parseAt(parts, orElse: () => wrapAsYamlNode(null)).value;
        if (value == null) {
          editor.update(parts, <String, Object?>{});
        } else if (value is! Map) {
          throw const FormatException();
        }
      }

      mapping(['host']);
      for (final entry in host.values.entries.where((entry) => entry.key != 'homeserver')) {
        editor.update(['host', entry.key], entry.value);
      }
      mapping(['transports']);
      mapping(['transports', 'matrix']);
      final matrix = editor.parseAt(['transports', 'matrix']).value as Map;
      for (final key in matrix.keys.toList()) {
        if (!const {'homeserver', 'room', 'registration_token_file', 'ca_certificate'}.contains(key)) {
          editor.remove(['transports', 'matrix', key]);
        }
      }
      editor.update(['transports', 'matrix', 'homeserver'], 'https://${host.values['homeserver']}:8448');
      editor.update(['transports', 'matrix', 'room'], hostProjectRoom(project, host));
      editor.update([
        'transports',
        'matrix',
        'registration_token_file',
      ], '~/.config/porelo/matrix/host-registration-token');
      _blockMatrixMappings(editor);
    } on Exception {
      throw const WorkspaceRefused(
        'access.yml must contain mappings for host and transports.matrix. Its contents were not changed.',
      );
    }
    final temporary = await _writer.createPrivateTemporary(Directory(folder));
    try {
      final prepared = File('${temporary.path}/access.yml');
      final yaml = _keepComments(_withLiteralCertificate(editor, caCertificate!), comments);
      await _writer.write(prepared, utf8.encode(yaml));
      await _plainAccessFile();
      await prepared.rename(file.path);
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  void _blockMatrixMappings(YamlEditor editor) {
    for (final parts in [
      const <String>[],
      const ['transports'],
      const ['transports', 'matrix'],
    ]) {
      final node = editor.parseAt(parts) as YamlMap;
      if (node.style != CollectionStyle.FLOW) continue;
      editor.update(parts, wrapAsYamlNode(_plainYaml(node), collectionStyle: CollectionStyle.BLOCK));
    }
  }

  String _keepComments(String yaml, List<String> original) {
    final remaining = <String, int>{};
    for (final comment in _yamlComments(yaml, loadYamlNode(yaml))) {
      remaining.update(comment, (count) => count + 1, ifAbsent: () => 1);
    }
    final missing = <String>[];
    for (final comment in original) {
      final count = remaining[comment] ?? 0;
      if (count == 0) {
        missing.add(comment);
      } else {
        remaining[comment] = count - 1;
      }
    }
    if (missing.isEmpty) return yaml;
    final start = YamlEditor(yaml).parseAt(['transports', 'matrix']).span.start;
    final indent = ' ' * start.column;
    return yaml.replaceRange(start.offset, start.offset, '${missing.join('\n$indent')}\n$indent');
  }

  List<String> _yamlComments(String yaml, YamlNode node) {
    final scalars = <(int, int)>[];
    void visit(YamlNode child) {
      if (child is YamlScalar) {
        scalars.add((child.span.start.offset, child.span.end.offset));
      } else if (child is YamlMap) {
        for (final entry in child.nodes.entries) {
          visit(entry.key as YamlNode);
          visit(entry.value);
        }
      } else if (child is YamlList) {
        child.nodes.forEach(visit);
      }
    }

    visit(node);
    final comments = <String>[];
    for (var at = 0; at < yaml.length; at++) {
      if (yaml[at] != '#' || scalars.any((span) => at >= span.$1 && at < span.$2)) continue;
      final newline = yaml.indexOf('\n', at);
      final end = newline < 0 ? yaml.length : newline;
      comments.add(yaml.substring(at, end).trimRight());
      at = end;
    }
    return comments;
  }

  Object? _plainYaml(Object? value) => switch (value) {
    Map() => {for (final entry in value.entries) _plainYaml(entry.key): _plainYaml(entry.value)},
    List() => [for (final item in value) _plainYaml(item)],
    _ => value,
  };

  String _withLiteralCertificate(YamlEditor editor, String pem) {
    const at = ['transports', 'matrix', 'ca_certificate'];
    // yaml_edit falls back to quoted strings for trailing newlines, so keep only the chomp adjustment here.
    editor.update(at, wrapAsYamlNode(pem.trimRight(), scalarStyle: ScalarStyle.LITERAL));
    final node = editor.parseAt(at) as YamlScalar;
    var yaml = editor.toString();
    final start = node.span.start.offset;
    if (node.style != ScalarStyle.LITERAL || !yaml.substring(start).startsWith('|-')) {
      throw const WorkspaceRefused('The host CA could not be kept as a literal YAML certificate.');
    }
    if (pem.endsWith('\n')) yaml = yaml.replaceRange(start, start + 2, '|');
    if (loadYaml(yaml)['transports']['matrix']['ca_certificate'] != pem) {
      throw const WorkspaceRefused('The host CA did not read back byte for byte. No access settings were changed.');
    }
    return yaml;
  }

  /// Signs through the person's Git, verifies the signer, pushes, and only then creates the bundle.
  Future<void> commitPushAndBundle(String bundle) async {
    if (_branch == null) throw const WorkspaceRefused('Open and verify the access checkout first.');
    await _git(['add', '--', 'access.yml']);
    final changed = await _git(['diff', '--cached', '--quiet', '--', 'access.yml'], optional: true);
    if (changed.code == 1) {
      await _git(['commit', '-S', '-m', 'Set project host and Matrix access', '--', 'access.yml']);
    } else if (changed.code != 0) {
      throw const WorkspaceRefused('Git could not check the staged access settings.');
    }
    await _verifyHead();
    await _git(['push', 'origin', 'HEAD:$_branch']);
    await _git(['bundle', 'create', bundle, 'HEAD', _branch!]);
    await _writer.protect(File(bundle));
  }

  Future<Ran> _git(List<String> arguments, {bool optional = false, bool inCheckout = true}) async {
    final Ran result;
    try {
      result = await _run(
        'git',
        arguments,
        inDirectory: inCheckout ? folder : null,
        environment: const {'GIT_TERMINAL_PROMPT': '0'},
      );
    } on Exception {
      throw const WorkspaceRefused(
        'Git could not run for the private access checkout. Check your own Git credentials and signing setup.',
      );
    }
    if (result.code != 0 && !optional) {
      throw const WorkspaceRefused(
        'Git refused the private access operation. Check the checkout with your own Git; no private diagnostic was recorded.',
      );
    }
    return result;
  }
}

/// Creates a private directory after refusing linked ancestors, without changing existing parents' modes.
Future<void> privateDirectory(Directory directory, {HostFileWriter? writer}) async {
  final absolute = path.absolute(directory.path);
  final ancestors = <String>[];
  var current = absolute;
  while (true) {
    ancestors.add(current);
    final parent = path.dirname(current);
    if (current == parent) break;
    current = parent;
  }
  for (final ancestor in ancestors.reversed) {
    final type = await FileSystemEntity.type(ancestor, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      // Private from creation: project history never enters a directory made with the process umask.
      final result = await Process.run('/usr/bin/mkdir', ['-m', '700', '--', ancestor]);
      if (result.exitCode != 0) throw const WorkspaceRefused('The private access directory could not be created.');
    } else if (type != FileSystemEntityType.directory) {
      throw const WorkspaceRefused('The private access directory has a linked or non-directory ancestor.');
    }
  }
  await (writer ?? HostFileWriter()).protectDirectory(Directory(absolute));
}
