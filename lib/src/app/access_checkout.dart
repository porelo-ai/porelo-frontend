import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart';

import 'commit_signing.dart';
import 'run_here.dart';
import 'signer_policy.dart';

/// The person's private access checkout, signed with their key through their agent and accepted as Core says.
class AccessCheckout {
  /// Names the signed project's access repository and Core's signer policy for it.
  AccessCheckout({
    required this.root,
    required this.project,
    required this.repository,
    required this.signers,
    RunHere? run,
    HostFileWriter? writer,
    CommitSigning? signing,
  }) : _run = run ?? runHere,
       _writer = writer ?? HostFileWriter(),
       _signing = signing ?? CommitSigning(signers, run: run);

  /// The private directory containing the per-project checkouts.
  final String root;

  /// The project's safe directory name.
  final String project;

  /// The credential-free repository address from the verified project file.
  final String repository;

  /// Core's signer policy: who signs a commit made here, and which commits are accepted; none refuses everything.
  final SignerPolicy? signers;
  final RunHere _run;
  final HostFileWriter _writer;
  final CommitSigning _signing;
  String? _branch;
  ProjectSigners? _signers;
  Directory? _work;

  String get _cache => path.join(root, project);

  /// The checkout, outside the public project repository and support records.
  String get folder {
    HostFiles.checkBasename(project);
    return _work?.path ?? _cache;
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
    await close();
    _branch = null;
    _signers = null;
    checkRepository(repository);
    // Core's signers come first: without them nothing is cloned, moved or signed.
    final signers = await _signing.signersFor(project);
    await privateDirectory(Directory(root), writer: _writer);
    final directory = Directory(folder);
    final type = await FileSystemEntity.type(folder, followLinks: false);
    final fresh = type == FileSystemEntityType.notFound;
    if (fresh) {
      await privateDirectory(directory, writer: _writer);
    } else if (type != FileSystemEntityType.directory ||
        await FileSystemEntity.type('$folder/.git', followLinks: false) != FileSystemEntityType.directory) {
      throw const WorkspaceRefused('The access checkout must be a plain Git directory, without links.');
    }
    try {
      if (fresh) await _git(['clone', '--no-tags', '--', repository, folder], inCheckout: false);
      await _verifyAndAdvance(directory, signers);
    } catch (_) {
      // A fresh clone holds nothing of the person's, so one that failed any check leaves nothing behind.
      if (fresh && await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
    final work = await _writer.createPrivateTemporary(Directory(root));
    try {
      await _git(['worktree', 'add', '--detach', work.path, 'HEAD']);
      _work = work;
    } on Exception {
      if (await work.exists()) await work.delete(recursive: true);
      rethrow;
    }
  }

  /// Checks the clean checkout, its origin and its signing, then fast-forwards it to the verified origin commit.
  Future<void> _verifyAndAdvance(Directory directory, ProjectSigners signers) async {
    await _writer.protectDirectory(directory);
    if ((await _git(['status', '--porcelain'])).out.isNotEmpty) {
      throw const WorkspaceRefused(
        'The access checkout has unpublished changes. Keep or publish them with your own Git before continuing.',
      );
    }
    if ((await _git(['config', '--get', 'remote.origin.url'])).out.trim() != repository) {
      throw const WorkspaceRefused('The access checkout origin differs from access.repository.');
    }
    // The full ref name, as a tag named like origin/<branch> would shadow the short one.
    final branch = (await _git(['symbolic-ref', 'refs/remotes/origin/HEAD'])).out.trim();
    if (!RegExp(r'^refs/remotes/origin/[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(branch) || branch.contains('..')) {
      throw const WorkspaceRefused('The access repository has no safe default branch.');
    }
    _branch = branch.substring('refs/remotes/origin/'.length);
    if ((await _git(['symbolic-ref', '--short', 'HEAD'])).out.trim() != _branch) {
      throw const WorkspaceRefused(
        'The access checkout must be on its default branch. Its current branch was preserved.',
      );
    }
    await _git(['fetch', '--no-tags', 'origin']);
    final ahead = (await _git(['rev-list', '--left-right', '--count', 'HEAD...$branch'])).out
        .trim()
        .split(RegExp(r'\s+'));
    if (ahead.length != 2 || int.tryParse(ahead[0]) != 0 || int.tryParse(ahead[1]) == null) {
      throw const WorkspaceRefused(
        'The access checkout has commits its origin does not hold. Publish or drop them with your own Git first.',
      );
    }
    // The origin's commit is accepted as Core says before the checkout moves to it, so an untrusted one never lands
    // here: by Core's verdict from when it arrived, or, where Core recorded none, as arriving now.
    final tip = (await _git(['rev-parse', '--verify', '$branch^{commit}'])).out.trim();
    await _signing.checkArrived(project, folder, tip, signers, scratchIn: Directory(root));
    await _git(['merge', '--ff-only', tip]);
    _signers = signers;
    await _plainAccessFile();
  }

  /// Discards only this attempt's private worktree, leaving the persistent checkout untouched.
  Future<void> close() async {
    final work = _work;
    if (work == null) return;
    _work = null;
    await _git(['worktree', 'remove', '--force', work.path]);
    if (await work.exists()) await work.delete(recursive: true);
  }

  Future<File> _plainAccessFile() async {
    final file = File('$folder/access.yml');
    if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) {
      throw const WorkspaceRefused('access.yml must be a plain file in the private access checkout.');
    }
    await _writer.protect(file);
    return file;
  }

  /// Reads the verified attempt's private access file.
  Future<String> read() async => (await _plainAccessFile()).readAsString();

  /// Reads the checked commit whose access settings the host must confirm.
  Future<String> revision() async {
    final revision = (await _git(['rev-parse', '--verify', 'HEAD^{commit}'])).out.trim();
    if (!RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(revision)) {
      throw const WorkspaceRefused('Git did not report a valid access commit.');
    }
    return revision;
  }

  /// Applies a checked edit atomically inside the verified private worktree.
  Future<void> edit(String Function(String source) change) async {
    if (_branch == null || _work == null) throw const WorkspaceRefused('Open and verify the access checkout first.');
    final file = await _plainAccessFile();
    final written = change(await file.readAsString());
    final temporary = await _writer.createPrivateTemporary(Directory(folder));
    try {
      final prepared = File('${temporary.path}/access.yml');
      await _writer.write(prepared, utf8.encode(written));
      await _plainAccessFile();
      await prepared.rename(file.path);
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  /// Signs with the person's key through their agent, checks it against Core's lines, pushes, and only then creates the
  /// bundle.
  ///
  /// The persistent checkout moves to the published commit only after the push, and the bundle carries it both as
  /// the default branch and as HEAD, so a follow finds it by either.
  /// [onPublished] records publication before local worktree or bundle cleanup can fail.
  Future<void> commitPushAndBundle(
    String bundle, {
    String message = 'Update verified project access',
    void Function(String revision)? onPublished,
  }) async {
    final branch = _branch;
    final signers = _signers;
    if (branch == null || signers == null || _work == null) {
      throw const WorkspaceRefused('Open and verify the access checkout first.');
    }
    final String published;
    try {
      await _git(['add', '--', 'access.yml']);
      final changed = await _git(['diff', '--cached', '--quiet', '--', 'access.yml'], optional: true);
      if (changed.code == 1) {
        await _git([
          ...CommitSigning.signingOptions(signers, login: signers.login),
          'commit',
          '-S',
          '-m',
          message,
          '--',
          'access.yml',
        ]);
        // Signed with the person's key and accepted by Core's lines now, or nothing leaves this computer.
        await _signing.checkOwn(folder, 'HEAD', signers, scratchIn: Directory(root));
      } else if (changed.code != 0) {
        throw const WorkspaceRefused('Git could not check the staged access settings.');
      }
      published = await revision();
      if (changed.code == 1) await _git(['push', 'origin', 'HEAD:$branch']);
      onPublished?.call(published);
    } finally {
      await close();
    }
    await _git(['merge', '--ff-only', published]);
    await bundlePublished(bundle, published);
  }

  /// Rebuilds the bundle only while the checkout still names [published].
  Future<void> bundlePublished(String bundle, String published) async {
    final branch = _branch;
    if (branch == null || await revision() != published) {
      throw const WorkspaceRefused('The access checkout no longer names the published access commit.');
    }
    if (await File(bundle).exists()) await File(bundle).delete();
    await _git(['bundle', 'create', bundle, 'refs/heads/$branch', 'HEAD']);
    await _writer.protect(File(bundle));
  }

  Future<Ran> _git(List<String> arguments, {bool optional = false, bool inCheckout = true}) async {
    final Ran result;
    try {
      result = await _run(
        'git',
        arguments,
        inDirectory: inCheckout ? folder : null,
        // None of the person's or the system's Git configuration chooses how a commit is signed or checked.
        environment: isolatedGit,
      );
    } on Exception {
      throw const WorkspaceRefused('Git could not run for the private access checkout.');
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
