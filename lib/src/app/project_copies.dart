import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import 'access_checkout.dart' show privateDirectory;
import 'bring_project_file.dart';
import 'commit_signing.dart' show isolatedGit;
import 'registry.dart' show RegistryRefusal;
import 'run_here.dart';

/// Private bare copies of a followed project's repository and its access repository, which Core's `project verify`
/// reads and the host's bundles are made from.
///
/// Every git runs with none of the person's or the system's Git configuration; a remote is reached as git reaches it
/// for the person, through their own SSH agent, and no credential is ever part of a command line.
class ProjectCopies {
  /// Keeps the copies under [root], a private directory of this desktop's.
  ProjectCopies({required this.root, RunHere? run}) : _run = run ?? runHere;

  /// The private directory holding one folder per project.
  final String root;

  final RunHere _run;

  /// The project's private folder, where its copies lie and Core is run.
  String folder(String project) {
    checkAdminName(project);
    return path.join(root, project);
  }

  /// The bare copy of the project's repository.
  String project(String project) => path.join(folder(project), 'project.git');

  /// The bare copy of the project's access repository.
  String access(String project) => path.join(folder(project), 'access.git');

  /// Brings the copy at [copy] up to every branch of [url], cloning it first where there is none, and points its
  /// `HEAD` at the branch the remote's `HEAD` names.
  ///
  /// A copy whose `origin` names another address, or more than one, is refused rather than fetched into.
  Future<void> fetch(String copy, String url) async {
    BringProjectFile.checkSource(url);
    await privateDirectory(Directory(root));
    await privateDirectory(Directory(path.dirname(copy)));
    final type = await FileSystemEntity.type(copy, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await _git(['clone', '--bare', '--no-tags', '--', url, copy], words: 'Git could not copy $url.');
      return;
    }
    if (type != FileSystemEntityType.directory) {
      throw RegistryRefusal('The private copy at $copy is not a plain directory; it was left as it is.');
    }
    final origin = await _git(['config', '--get-all', 'remote.origin.url'], inside: copy, words: _unreadable(copy));
    if (origin != '$url\n') {
      throw RegistryRefusal('The private copy at $copy names another repository than $url; it was left as it is.');
    }
    await _git(
      ['fetch', '--no-tags', '--prune', 'origin', '+refs/heads/*:refs/heads/*'],
      inside: copy,
      words: 'Git could not fetch $url.',
    );
    // A fetch never moves a bare copy's HEAD: a copy made while the repository was empty, or a renamed default branch,
    // would read no commit or an old one.
    final remoteHead = await _git(
      ['ls-remote', '--symref', 'origin', 'HEAD'],
      inside: copy,
      words: 'Git could not read $url.',
    );
    for (final line in remoteHead.split('\n')) {
      final match = RegExp(r'^ref: (refs/heads/[A-Za-z0-9._/-]+)\tHEAD$').firstMatch(line);
      if (match == null) continue;
      await _git(['symbolic-ref', 'HEAD', match.group(1)!], inside: copy, words: _unreadable(copy));
      break;
    }
  }

  /// The blob [name] at [revision] of [repository], byte for byte as git stores it.
  Future<String> blob(String repository, String revision, String name) => _git(
    ['cat-file', 'blob', '$revision:$name'],
    inside: repository,
    words: 'Git could not read $name at $revision.',
  );

  /// The file [name] at [revision] of [copy], as git stores it.
  Future<String> show(String copy, String revision, String name) =>
      _git(['show', '$revision:$name'], inside: copy, words: 'Git could not read $name at $revision.');

  /// The commit [copy]'s default branch names, or null when it has none yet.
  Future<String?> head(String copy) async {
    final result = await _ran(['rev-parse', '--verify', '--quiet', 'HEAD^{commit}'], inside: copy);
    if (result.code != 0) return null;
    return _commit(result.out.trim(), copy);
  }

  /// Whether [revision] is a commit [copy]'s default branch holds.
  Future<bool> holds(String copy, String revision) async {
    final known = await _ran(['cat-file', '-e', '$revision^{commit}'], inside: copy);
    if (known.code != 0) return false;
    final ancestor = await _ran(['merge-base', '--is-ancestor', revision, 'HEAD'], inside: copy);
    return switch (ancestor.code) {
      0 => true,
      1 => false,
      _ => throw RegistryRefusal(_unreadable(copy)),
    };
  }

  /// Every commit of [copy]'s default branch, among its last 1000 first parents and newest first, carrying the
  /// `Porelo-Change-Id` trailer [id] Core writes for a filing.
  Future<List<String>> changeCommits(String copy, String id) async {
    // A repository still holding no commit has none under any id, and git cannot list an unborn HEAD.
    if (await head(copy) == null) return const [];
    final listed = await _git(
      [
        'log',
        '--first-parent',
        '-n',
        '1000',
        '--format=%H %(trailers:key=Porelo-Change-Id,valueonly,separator=%x2C)',
        'HEAD',
      ],
      inside: copy,
      words: _unreadable(copy),
    );
    return [
      for (final line in listed.split('\n'))
        if (line.trim().split(' ') case [final commit, final ids] when ids.split(',').contains(id))
          _commit(commit, copy),
    ];
  }

  /// The parents of [revision], in order.
  Future<List<String>> parents(String copy, String revision) async {
    final said = await _git(
      ['rev-list', '--parents', '-n', '1', '$revision^{commit}'],
      inside: copy,
      words: _unreadable(copy),
    );
    final commits = said.trim().split(' ');
    return [for (final commit in commits.skip(1)) _commit(commit, copy)];
  }

  /// Whether [older] is [newer] or one of its ancestors.
  Future<bool> descends(String copy, String newer, String older) async {
    final ancestor = await _ran(['merge-base', '--is-ancestor', older, newer], inside: copy);
    return switch (ancestor.code) {
      0 => true,
      1 => false,
      _ => throw RegistryRefusal(_unreadable(copy)),
    };
  }

  /// The fingerprint of the key whose signature on [revision] verifies against [allowedSigners], an allowed-signers
  /// file of the keys that may have signed it; null when none does, or [krl] revokes it.
  Future<String?> signer(String copy, String revision, {required String allowedSigners, String? krl}) async {
    final said = await _ran([
      '-c',
      'gpg.ssh.allowedSignersFile=$allowedSigners',
      if (krl != null) ...['-c', 'gpg.ssh.revocationFile=$krl'],
      'log',
      '-1',
      '--no-show-signature',
      '--format=%G? %GF',
      '$revision^{commit}',
    ], inside: copy);
    if (said.code != 0) return null;
    final verdict = said.out.trim().split(' ');
    return verdict.length == 2 && verdict.first == 'G' ? verdict.last : null;
  }

  /// The `Porelo-Change-Id` trailers [revision] carries, as written.
  Future<List<String>> changeIds(String copy, String revision) async {
    final said = await _git(
      ['log', '-1', '--format=%(trailers:key=Porelo-Change-Id,valueonly,separator=%x2C)', revision],
      inside: copy,
      words: _unreadable(copy),
    );
    return [
      for (final id in said.trim().split(','))
        if (id.isNotEmpty) id,
    ];
  }

  /// Writes a bundle of [copy] at exactly [revision] to [bundle], its tip as `main` and as `HEAD`, never a newer one.
  ///
  /// It is made in a scratch clone under [scratch], so the copy's own branches stay as they are.
  Future<void> bundle(String copy, String revision, String bundle, {required String scratch}) async {
    final clone = path.join(scratch, '${path.basename(bundle)}.git');
    final words = 'Git could not bundle $revision.';
    await _git(['clone', '--bare', '--no-local', '--no-tags', '--', copy, clone], words: words);
    await _git(['update-ref', 'refs/heads/main', '$revision^{commit}'], inside: clone, words: words);
    await _git(['symbolic-ref', 'HEAD', 'refs/heads/main'], inside: clone, words: words);
    await _git(['bundle', 'create', bundle, 'HEAD', 'main'], inside: clone, words: words);
  }

  static String _unreadable(String copy) => 'Git could not read the private copy at $copy.';

  String _commit(String value, String copy) {
    if (!RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(value)) throw RegistryRefusal(_unreadable(copy));
    return value;
  }

  Future<Ran> _ran(List<String> arguments, {String? inside}) async {
    try {
      return await _run('git', arguments, inDirectory: inside, environment: isolatedGit);
    } on Exception {
      throw const RegistryRefusal('Git could not be run on this computer.');
    }
  }

  Future<String> _git(List<String> arguments, {String? inside, required String words}) async {
    final result = await _ran(arguments, inside: inside);
    if (result.code != 0) throw RegistryRefusal(words);
    return result.out;
  }
}
