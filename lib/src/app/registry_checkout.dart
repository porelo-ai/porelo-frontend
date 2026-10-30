import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import 'access_checkout.dart';
import 'run_here.dart';

/// The person's private checkout of the organisation's registry repository, fetched with their own access.
///
/// Git reaches the repository through the person's own configuration: their SSH agent for a `git@`
/// address, or the credential helper their Git names for an `https` one. Nothing here asks for, holds or
/// passes on a credential, and Git is never allowed to prompt for one.
///
/// It only moves the checkout to what the repository holds; whether that state is accepted is Core's
/// answer, kept apart from it by `Registry`.
class RegistryCheckout {
  /// Constructor taking the private root folder and the credential-free repository address.
  RegistryCheckout({required this.root, required this.repository, RunHere? run, HostFileWriter? writer})
    : _run = run ?? runHere,
      _writer = writer ?? HostFileWriter();

  /// The private folder holding the checkouts, one per address.
  final String root;

  /// The credential-free address of the registry repository.
  final String repository;

  final RunHere _run;
  final HostFileWriter _writer;
  String? _branch;

  /// The checkout, named for its address, so another address never meets this one's history.
  String get folder =>
      path.join(root, 'registry-${sha256.convert(utf8.encode(repository)).toString().substring(0, 16)}');

  /// Refuses an address with credentials or unsafe Git source syntax, without repeating it.
  static void checkRepository(String repository) {
    try {
      AccessCheckout.checkRepository(repository);
    } on WorkspaceRefused {
      throw const WorkspaceRefused(
        'The registry repository must be a git@ or https address without a user name, password or token.',
      );
    }
  }

  /// Clones privately or fast-forwards the clean checkout to the repository's default branch.
  ///
  /// Answers the fetched commit. A refused clone leaves nothing behind; a refused fetch leaves the checkout
  /// where it was. Never resets: a checkout holding changes or commits the repository lacks is refused.
  Future<String> fetch() async {
    _branch = null;
    checkRepository(repository);
    await privateDirectory(Directory(root), writer: _writer);
    final type = await FileSystemEntity.type(folder, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await _clone();
    } else if (type != FileSystemEntityType.directory ||
        await FileSystemEntity.type(path.join(folder, '.git'), followLinks: false) != FileSystemEntityType.directory) {
      throw const WorkspaceRefused('The registry checkout must be a plain Git directory, without links.');
    }
    await _writer.protectDirectory(Directory(folder));
    await _checkClean();
    await _git(['fetch', '--no-tags', '--prune', 'origin'], refusal: _fetchRefused);
    final branch = await _defaultBranch();
    await _checkNothingUnpublished(branch);
    await _git(['merge', '--ff-only', 'refs/remotes/origin/$branch']);
    _branch = branch;
    return _revision();
  }

  /// Pushes the commit Core signed in the checkout to the repository's default branch.
  Future<void> publish() async {
    final branch = _branch;
    if (branch == null) throw const WorkspaceRefused('Fetch the registry before publishing a change to it.');
    await _git([
      'push',
      'origin',
      'HEAD:refs/heads/$branch',
    ], refusal: 'Git could not publish the registry change with your access. It stays in the private checkout.');
  }

  static const _fetchRefused =
      'Git could not fetch the registry repository with your access: your SSH agent for a git@ address, or '
      'your forge token for an https one. Try it in a terminal with your own Git. The registry shown is unchanged.';

  Future<void> _clone() async {
    final directory = Directory(folder);
    await privateDirectory(directory, writer: _writer);
    try {
      await _git(['clone', '--no-tags', '--', repository, folder], inCheckout: false, refusal: _fetchRefused);
    } on WorkspaceRefused {
      // A fresh clone holds nothing of the person's, so a refused one leaves nothing for the next try to meet.
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> _checkClean() async {
    if ((await _git(['status', '--porcelain'])).out.isNotEmpty) {
      throw const WorkspaceRefused('The registry checkout has unpublished changes. Nothing was fetched.');
    }
    if ((await _git(['config', '--get', 'remote.origin.url'])).out.trim() != repository) {
      throw const WorkspaceRefused('The registry checkout fetches from another address than the one chosen.');
    }
  }

  Future<String> _defaultBranch() async {
    // The full ref name, as a tag named like origin/<branch> would shadow the short one.
    final ref = (await _git(['symbolic-ref', 'refs/remotes/origin/HEAD'])).out.trim();
    if (!RegExp(r'^refs/remotes/origin/[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(ref) || ref.contains('..')) {
      throw const WorkspaceRefused('The registry repository has no safe default branch.');
    }
    final branch = ref.substring('refs/remotes/origin/'.length);
    if ((await _git(['symbolic-ref', '--short', 'HEAD'])).out.trim() != branch) {
      throw const WorkspaceRefused('The registry checkout must be on its default branch.');
    }
    return branch;
  }

  Future<void> _checkNothingUnpublished(String branch) async {
    final counts = (await _git(['rev-list', '--left-right', '--count', 'HEAD...refs/remotes/origin/$branch'])).out
        .trim()
        .split(RegExp(r'\s+'));
    if (counts.length != 2 || int.tryParse(counts[0]) != 0 || int.tryParse(counts[1]) == null) {
      throw const WorkspaceRefused(
        'The registry checkout holds a commit the repository does not. Publish or drop it with your own Git first.',
      );
    }
  }

  Future<String> _revision() async {
    final revision = (await _git(['rev-parse', '--verify', 'HEAD^{commit}'])).out.trim();
    if (!RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(revision)) {
      throw const WorkspaceRefused('Git did not report a valid registry commit.');
    }
    return revision;
  }

  Future<Ran> _git(
    List<String> arguments, {
    bool inCheckout = true,
    String refusal = 'Git refused an operation on the private registry checkout. Nothing private was recorded.',
  }) async {
    final Ran result;
    try {
      result = await _run(
        'git',
        arguments,
        inDirectory: inCheckout ? folder : null,
        environment: const {'GIT_TERMINAL_PROMPT': '0'},
      );
    } on Exception {
      throw const WorkspaceRefused('Git could not run for the private registry checkout.');
    }
    if (result.code != 0) throw WorkspaceRefused(refusal);
    return result;
  }
}
