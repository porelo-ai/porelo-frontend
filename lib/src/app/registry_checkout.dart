import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
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
  String? _filingBase;

  /// The checkout, named for its address, so another address never meets this one's history.
  String get folder =>
      path.join(root, 'registry-${crypto.sha256.convert(utf8.encode(repository)).toString().substring(0, 16)}');

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
    _filingBase = null;
    checkRepository(repository);
    await privateDirectory(Directory(root), writer: _writer);
    final type = await FileSystemEntity.type(folder, followLinks: false);
    final fresh = type == FileSystemEntityType.notFound;
    if (!fresh &&
        (type != FileSystemEntityType.directory ||
            await FileSystemEntity.type(path.join(folder, '.git'), followLinks: false) !=
                FileSystemEntityType.directory)) {
      throw const WorkspaceRefused('The registry checkout must be a plain Git directory, without links.');
    }
    try {
      if (fresh) await _clone();
      await _writer.protectDirectory(Directory(folder));
      await _checkClean();
      await _git(['fetch', '--no-tags', '--prune', 'origin'], refusal: _fetchRefused);
      final branch = await _defaultBranch();
      await _checkNothingUnpublished(branch);
      await _git(['merge', '--ff-only', 'refs/remotes/origin/$branch']);
      final revision = await _revision();
      _branch = branch;
      return revision;
    } on Exception {
      // Only a checkout created by this attempt has no work of the person's to preserve.
      if (fresh && await Directory(folder).exists()) await Directory(folder).delete(recursive: true);
      rethrow;
    }
  }

  /// Checks for changes and unpublished commits before Core writes, remembering the checked base.
  Future<void> prepareFiling() async {
    _filingBase = null;
    final branch = _branch;
    if (branch == null) throw const WorkspaceRefused('Fetch the registry before changing it.');
    await _checkClean();
    if (await _defaultBranch() != branch) {
      throw const WorkspaceRefused('The registry default branch changed. Refresh it before making a change.');
    }
    await _checkNothingUnpublished(branch);
    _filingBase = await _revision();
  }

  /// Checks the checkout before Core files again under a request whose answer was lost, which may have made its commit.
  ///
  /// Beside a checkout with nothing unpublished, accepts exactly one commit on [base], the published tip, that changes
  /// only [file], as a plain file holding [content]'s UTF-8 bytes: the one that request made. Any other unpublished
  /// commit is refused as [prepareFiling] refuses it, before Core runs.
  Future<void> prepareRetry({required String base, required String file, required String content}) async {
    _filingBase = null;
    if (!_commit.hasMatch(base)) throw const WorkspaceRefused('Core did not name a valid registry commit.');
    await _checkClean();
    final branch = await _defaultBranch();
    if (await _madeUnder(branch: branch, base: base, file: file, content: content)) return;
    await _checkNothingUnpublished(branch);
  }

  /// Whether the checkout is one commit on [base], the published tip of [branch], that changes only [file], as a plain
  /// file holding [content]'s UTF-8 bytes.
  Future<bool> _madeUnder({
    required String branch,
    required String base,
    required String file,
    required String content,
  }) async {
    if (await _published(branch) != base) return false;
    final parents = (await _git(['rev-list', '--parents', '-n', '1', 'HEAD'])).out.trim().split(RegExp(r'\s+'));
    if (parents.length != 2 || parents[1] != base) return false;
    // Names as Git holds them, ended by NUL: a name with a space at its end is another file.
    final changed = (await _git(['diff', '--name-only', '-z', '--no-renames', base, 'HEAD'])).out.split('\x00')
      ..removeLast();
    if (changed.length != 1 || changed.single != file) return false;
    // A link or a program whose text is the content is not the file Core was asked to write.
    final entry = (await _git(['--literal-pathspecs', 'ls-tree', '-z', 'HEAD', '--', file])).out.split('\x00');
    final blob = RegExp(r'^100644 blob ([0-9a-f]{40}|[0-9a-f]{64})\t(.*)$').firstMatch(entry.first);
    if (entry.length != 2 || entry.last.isNotEmpty || blob == null || blob.group(2) != file) return false;
    return blob.group(1) == _blobId(utf8.encode(content), sha256: blob.group(1)!.length == 64);
  }

  /// Git's id of a blob holding [bytes]: compared by id, the content never passes through an encoding or a filter.
  static String _blobId(List<int> bytes, {required bool sha256}) {
    final object = [...utf8.encode('blob ${bytes.length}\x00'), ...bytes];
    return (sha256 ? crypto.sha256 : crypto.sha1).convert(object).toString();
  }

  /// The tip of [branch] as the repository last answered it.
  Future<String> _published(String branch) async =>
      (await _git(['rev-parse', '--verify', 'refs/remotes/origin/$branch^{commit}'])).out.trim();

  /// Publishes only [revision], Core's single new commit above the base checked by [prepareFiling].
  Future<void> publish(String revision) async {
    final branch = _branch;
    final base = _filingBase;
    _filingBase = null;
    if (branch == null || base == null) {
      throw const WorkspaceRefused('Check the registry checkout before publishing a change to it.');
    }
    if (!RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(revision)) {
      throw const WorkspaceRefused('Core did not name a valid registry commit.');
    }
    await _checkClean();
    if (await _defaultBranch() != branch || await _revision() != revision) {
      throw const WorkspaceRefused('The registry checkout changed outside this filing. Nothing was published.');
    }
    final parents = (await _git(['rev-list', '--parents', '-n', '1', revision])).out.trim().split(RegExp(r'\s+'));
    if (parents.length != 2 || parents[0] != revision || parents[1] != base) {
      throw const WorkspaceRefused('The registry change includes other commits. Nothing was published.');
    }
    await _git([
      'push',
      'origin',
      '$revision:refs/heads/$branch',
    ], refusal: 'Git could not publish the registry change with your access. It stays in the private checkout.');
  }

  /// Pushes [revision], a commit made earlier under request [id] that a push did not take, without any filing state.
  ///
  /// [revision] must be the request's own: its `Porelo-Change-Id` trailer [id], its one parent the kept [base] or the
  /// commit Core read last, [lastRead], and its change [file] alone; or such a commit whose parent is Core's removal of
  /// [file] before filing it again, carrying `Porelo-Change-Step: [id]` on one of those, taken whole. Nothing is taken
  /// from any other commit. Done without a push when the published branch, fetched first, holds [revision] on its
  /// first-parent line, the only one Core reads: its push went through before its answer was read, or by hand; a commit
  /// of the checkout above it is refused, as it would go with the next push. Otherwise refused unless the checkout is
  /// clean, on its default branch, at [revision], and the commit it was made on is the published tip: pushed on any
  /// other, an unreviewed commit would go with it.
  Future<void> publishMade(
    String revision, {
    required String base,
    required String id,
    required String file,
    String? lastRead,
  }) async {
    if (!_commit.hasMatch(revision) ||
        !_commit.hasMatch(base) ||
        lastRead != null && !_commit.hasMatch(lastRead) ||
        !RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(id)) {
      throw const WorkspaceRefused('Core did not name a valid registry commit.');
    }
    if (revision == base || revision == lastRead) throw const WorkspaceRefused(_notOnItsBase);
    await _checkClean();
    final branch = await _defaultBranch();
    await _git(['fetch', '--no-tags', '--prune', 'origin'], refusal: _fetchRefused);
    final madeOn = await _ownMadeOn(revision, id: id, file: file, bases: {base, ?lastRead});
    if (madeOn == null) throw const WorkspaceRefused(_notOnItsBase);
    if (await _onFirstParentLine(branch, revision)) {
      await _checkNothingUnpublished(branch);
      return;
    }
    if (await _published(branch) != madeOn) {
      throw const WorkspaceRefused(
        'The registry moved past the commit this change was made on. Nothing was published.',
      );
    }
    if (await _revision() != revision) {
      throw const WorkspaceRefused('The registry checkout is not at the commit Core made. Nothing was published.');
    }
    await _git([
      'push',
      'origin',
      '$revision:refs/heads/$branch',
    ], refusal: 'Git could not publish the registry change with your access. It stays in the private checkout.');
  }

  /// The commit [revision] was made on, one of [bases], when it is request [id]'s own change of [file] alone, directly
  /// or above Core's removal of [file] made for that request; null for any other commit.
  Future<String?> _ownMadeOn(
    String revision, {
    required String id,
    required String file,
    required Set<String> bases,
  }) async {
    final parent = await _ownChange(revision, trailer: 'Porelo-Change-Id: $id', file: file);
    if (parent == null) return null;
    if (bases.contains(parent)) return parent;
    final before = await _ownChange(parent, trailer: 'Porelo-Change-Step: $id', file: file);
    return before != null && bases.contains(before) ? before : null;
  }

  /// The one parent of [commit] when its message carries [trailer] exactly once, no other Porelo change line, and its
  /// change is [file] alone; null otherwise.
  Future<String?> _ownChange(String commit, {required String trailer, required String file}) async {
    final parents = (await _git([
      'rev-list',
      '--parents',
      '-n',
      '1',
      commit,
    ], refusal: _notOnItsBase)).out.trim().split(RegExp(r'\s+'));
    if (parents.length != 2 || parents[0] != commit) return null;
    final raw = (await _git(['cat-file', 'commit', commit], refusal: _notOnItsBase)).out;
    final body = raw.indexOf('\n\n');
    if (body < 0) return null;
    final changeLines = [
      for (final line in const LineSplitter().convert(raw.substring(body + 2)))
        if (line.startsWith('Porelo-Change-Id:') || line.startsWith('Porelo-Change-Step:')) line,
    ];
    if (changeLines.length != 1 || changeLines.single != trailer) return null;
    // Names as Git holds them, ended by NUL: a name with a space at its end is another file.
    final changed = (await _git(['diff', '--name-only', '-z', '--no-renames', parents[1], commit])).out.split('\x00')
      ..removeLast();
    if (changed.length != 1 || changed.single != file) return null;
    return parents[1];
  }

  static const _notOnItsBase = 'The registry change includes other commits. Nothing was published.';

  /// Whether the published [branch] holds [revision] on its first-parent line: a commit merged in as another parent is
  /// one Core never reads.
  Future<bool> _onFirstParentLine(String branch, String revision) async {
    final line = (await _git(['rev-list', '--first-parent', 'refs/remotes/origin/$branch'])).out;
    return const LineSplitter().convert(line).any((each) => each.trim() == revision);
  }

  static final _commit = RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$');

  static const _fetchRefused =
      'Git could not fetch the registry repository with your access: your SSH agent for a git@ address, or '
      'your forge token for an https one. Try it in a terminal with your own Git.';

  Future<void> _clone() async {
    final directory = Directory(folder);
    await privateDirectory(directory, writer: _writer);
    await _git(['clone', '--no-tags', '--', repository, folder], inCheckout: false, refusal: _fetchRefused);
  }

  Future<void> _checkClean() async {
    if ((await _git(['status', '--porcelain'])).out.isNotEmpty) {
      throw const WorkspaceRefused(
        'The registry checkout has unpublished changes. Resolve them with your own Git first.',
      );
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
      // The checkout holds the repository's own bytes, which a file made from it and its commit are compared by.
      result = await _run(
        'git',
        ['-c', 'core.autocrlf=false', ...arguments],
        inDirectory: inCheckout ? folder : null,
        environment: {
          'GIT_TERMINAL_PROMPT': '0',
          'GIT_ASKPASS': '',
          'SSH_ASKPASS': '',
          'GCM_INTERACTIVE': 'never',
          'GIT_SSH_COMMAND': Platform.environment['GIT_SSH_COMMAND'] ?? 'ssh -o BatchMode=yes',
        },
      );
    } on Exception {
      throw const WorkspaceRefused('Git could not run for the private registry checkout.');
    }
    if (result.code != 0) throw WorkspaceRefused(refusal);
    return result;
  }
}
