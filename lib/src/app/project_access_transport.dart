import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import 'desk.dart';
import 'identity.dart';
import 'machines.dart';
import 'project_access_contract.dart';
import 'project_copies.dart';
import 'registry.dart';

/// Builds the `Remote` a card machine's commands go through, sharing the card tunnel's connection.
typedef CardRemote = Remote Function(HostCardSsh card, String config);

/// Delivers a project's signed access to its host through the person's own card tunnel and account.
///
/// The tunnel is the card's own (`BatchMode=yes`, the host key pinned, the key offered from the person's agent, no
/// agent forwarding). The project's and the access repository's bundles, each at exactly the commit the change names,
/// are staged owner-only in `~/.local/share/porelo-host/setup/<project>/`, checked by their SHA-256 there and renamed
/// into place, where the host's `sync` reads them; then `sudo -n /usr/local/sbin/porelo-host-person sync <project>`
/// runs in the person's account and its one JSON line is read field by field.
class CardProjectAccessTransport implements ProjectAccessTransport {
  /// Takes the watched machines and their tunnels, the person's card, the private copies, and the remote seam.
  CardProjectAccessTransport({
    required this.machines,
    required this.identity,
    required this.copies,
    CardRemote? remote,
    String Function(String host)? endpoint,
  }) : _remote = remote ?? ((card, config) => OpenSsh.sharedHost(card: card, config: config)),
       _endpoint = endpoint ?? Machine.endpointFor;

  /// The host's sync helper, run through sudo as the sudoers rule names it.
  static const sync = '/usr/local/sbin/porelo-host-person';

  /// The watched machines, whose tunnels the card tunnel is raised through.
  final Machines machines;

  /// The person's card as Core's `identity show` answers it.
  final Future<IdentityCard> Function() identity;

  /// The private copies the bundles are made from.
  final ProjectCopies copies;

  final CardRemote _remote;
  final String Function(String host) _endpoint;
  final _connected = <String, Machine>{};

  @override
  Future<Machine> connect(ProjectAccessView view) async {
    final IdentityCard card;
    try {
      card = await identity();
    } on Exception {
      throw const RegistryRefusal('Your own key could not be read from your identity, so no host was connected.');
    }
    if (card.login != view.actor.login || card.fingerprint != view.actor.fingerprint) {
      throw const RegistryRefusal('Your card changed since the project was read. Read it again.');
    }
    if (card.whyKeyUnusable case final why?) throw RegistryRefusal(why);
    final host = view.host;
    final HostCardSsh hostCard;
    try {
      hostCard = HostCardSsh(
        name: host.name,
        address: host.address,
        sshPort: host.sshPort,
        hostKey: host.sshHostKey,
        login: card.login,
        publicKey: card.key,
        webPort: host.services['forge']!['web_port']!,
        gitPort: host.services['forge']!['git_port']!,
        matrixPort: host.services['matrix']!['port']!,
      );
    } on HostFilesRefused catch (error) {
      throw RegistryRefusal(error.message);
    }
    // A machine watched for this host with another card or key gives its tunnel and files up to this card, as a join
    // does; it publishes them again when it is raised.
    for (final old in machines.all) {
      if (old.hostCard case final other? when other.name == hostCard.name && other != hostCard) {
        await machines.tunnels.dropAndUnpublish(old);
      }
    }
    // The machine this card already reaches here, joined or registered, is raised as it is watched; the change names
    // the host it was raised for either way.
    final watched = machines.all.where((machine) => machine.hostCard == hostCard).firstOrNull;
    final raised =
        watched ??
        Machine(
          name: hostCard.name,
          kind: 'host',
          host: hostCard.name,
          socketPath: _endpoint(hostCard.name),
          remoteSocket: hostCard.daemonSocket,
          hostProject: hostCard.name,
          hostCard: hostCard,
          sshConfig: hostCard.configPath(
            environment: machines.tunnels.configEnvironment ?? desk.environment,
            windows: desk.isWindows,
          ),
        );
    if (!await machines.tunnels.raiseFor(raised)) {
      final why =
          raised.whyNotReachableHere ??
          machines.tunnels.of(raised)?.problem ??
          'The tunnel to ${hostCard.name} could not be opened.';
      if (watched == null) await machines.tunnels.dropAndUnpublish(raised);
      _connected.remove(hostCard.name);
      throw RegistryRefusal(why);
    }
    final machine = raised.hostProject == hostCard.name
        ? raised
        : Machine(
            name: raised.name,
            kind: raised.kind,
            host: raised.host,
            socketPath: raised.socketPath,
            remoteSocket: raised.remoteSocket,
            distribution: raised.distribution,
            identity: raised.identity,
            hostProject: hostCard.name,
            hostCard: hostCard,
            sshConfig: raised.sshConfig,
          );
    _connected[hostCard.name] = machine;
    return machine;
  }

  ({Remote remote, HostCardSsh card}) _through(ProjectAccessChange change) {
    final machine = _connected[change.host];
    final card = machine?.hostCard;
    if (machine == null || card == null || card.name != change.host) {
      throw RegistryRefusal('The tunnel to ${change.host} is not open. Retry.');
    }
    return (remote: _remote(card, machine.sshConfig), card: card);
  }

  /// The setup folder, relative to the account's home, where the host's sync looks for [project]'s bundles.
  static String setupFolder(String project) => HostAct.ownAccount.setupPlace(project: project);

  @override
  Future<void> upload(ProjectAccessChange change, String accessRevision) async {
    final (:remote, :card) = _through(change);
    // The id names a folder the host removes and recreates: only the form a receipt holds is ever put in a path.
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(change.id)) throw const RegistryRefusal('Invalid project request ID.');
    final project = change.project;
    final folder = setupFolder(project);
    final staging = '$folder/.incoming-${change.id}';
    final scratch = await HostFileWriter().createPrivateTemporary(Directory(copies.folder(project)));
    try {
      final bundles = {
        HostFiles.projectBundleFileName: (copies.project(project), change.projectRevision),
        HostFiles.accessBundleFileName: (copies.access(project), accessRevision),
      };
      final digests = StringBuffer();
      for (final MapEntry(key: name, value: (copy, revision)) in bundles.entries) {
        final bundle = path.join(scratch.path, name);
        await copies.bundle(copy, revision, bundle, scratch: scratch.path);
        digests.write('${sha256.convert(await File(bundle).readAsBytes())}  $name\n');
      }
      final made = await remote.run(card.name, '', _reserve(folder, staging));
      if (made.exitCode != 0) throw RegistryRefusal(_said(made, 'The host refused a private folder for the bundles.'));
      for (final name in bundles.keys) {
        final copied = await remote.copy(card.name, '', path.join(scratch.path, name), '$staging/$name');
        if (copied.exitCode != 0) {
          await remote.run(card.name, '', _clean(staging));
          throw RegistryRefusal(_said(copied, 'The bundles could not be copied to the host.'));
        }
      }
      final placed = await remote.run(card.name, '', _place(folder, staging, bundles.keys), input: '$digests');
      if (placed.exitCode != 0) {
        await remote.run(card.name, '', _clean(staging));
        throw RegistryRefusal(_said(placed, 'The bundles did not arrive on the host as they were sent.'));
      }
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

  /// Each folder down to [folder], refusing a link and making what is missing owner-only; from the setup folder on, one
  /// that was there already is made owner-only too, so no other account reads or swaps a bundle placed in it.
  static String _checkedFolders(String folder) {
    final parts = folder.split('/');
    // The folder is the setup folder's own folder for the project, `.local/share/porelo-host/setup/<project>`.
    final setup = parts.length - 1;
    return [
      for (var count = 1; count <= parts.length; count++)
        'd=${quoteForAShell(parts.take(count).join('/'))}; '
            'if [ -L "\$d" ]; then echo "\$d is a link; nothing was placed." >&2; exit 1; fi; '
            '[ -d "\$d" ] || /usr/bin/mkdir -m 0700 -- "\$d"'
            '${count >= setup ? '; /usr/bin/chmod 0700 -- "\$d"' : ''}',
    ].join('\n');
  }

  static String _reserve(String folder, String staging) => [
    'set -eu',
    'umask 077',
    r'cd -- "$HOME"',
    _checkedFolders(folder),
    'if [ -e ${quoteForAShell(staging)} ] || [ -L ${quoteForAShell(staging)} ]; then '
        '/usr/bin/rm -rf -- ${quoteForAShell(staging)}; fi',
    '/usr/bin/mkdir -m 0700 -- ${quoteForAShell(staging)}',
  ].join('\n');

  static String _place(String folder, String staging, Iterable<String> names) => [
    'set -eu',
    'umask 077',
    r'cd -- "$HOME"',
    'if [ -L ${quoteForAShell(staging)} ] || [ ! -d ${quoteForAShell(staging)} ]; then exit 1; fi',
    '(cd -- ${quoteForAShell(staging)} && /usr/bin/sha256sum --quiet --strict -c -)',
    for (final name in names) ...[
      '/usr/bin/chmod 0600 -- ${quoteForAShell('$staging/$name')}',
      // A rename within the folder: sync reads either the whole earlier bundle or the whole new one.
      '/usr/bin/mv -fT -- ${quoteForAShell('$staging/$name')} ${quoteForAShell('$folder/$name')}',
    ],
    '/usr/bin/rmdir -- ${quoteForAShell(staging)}',
  ].join('\n');

  static String _clean(String staging) =>
      'cd -- "\$HOME" && if [ ! -L ${quoteForAShell(staging)} ]; then /usr/bin/rm -rf -- ${quoteForAShell(staging)}; fi';

  @override
  Future<ProjectAccessStatus> apply(ProjectAccessChange change, String accessRevision) async {
    final (:remote, :card) = _through(change);
    final lines = <String>[];
    final ran = await remote.run(
      card.name,
      '',
      inTheLoginShell('/usr/bin/sudo -n $sync sync ${quoteForAShell(change.project)}'),
      input: '',
      onLine: lines.add,
    );
    if (ran.exitCode != 0) throw RegistryRefusal(_said(ran, 'The host did not take the project\'s bundles.'));
    final answer = _answer(lines);
    // The person a change adds, or for a registration the admin it registers, refused by the host is no success.
    final person = change.action == 'register' ? change.actor : change.person?.login;
    if (person != null) {
      for (final refused in answer.refused) {
        if (refused.startsWith('$person: ')) throw RegistryRefusal('The host refused $refused.');
      }
    }
    return ProjectAccessStatus(
      host: card.name,
      project: answer.project,
      projectRevision: answer.commit,
      accessRevision: answer.accessCommit,
      // The answer names whom this sync added; a person it added is active in the project.
      people: {for (final login in answer.added) login: 'active'},
    );
  }

  static ({String project, String commit, String accessCommit, List<String> added, List<String> refused}) _answer(
    List<String> lines,
  ) {
    const unreadable = RegistryRefusal('The host\'s answer to the sync could not be read.');
    final said = lines.where((line) => line.trim().isNotEmpty).toList();
    if (said.isEmpty) throw unreadable;
    final Object? json;
    try {
      json = jsonDecode(said.last);
    } on FormatException {
      throw unreadable;
    }
    if (json is! Map) throw unreadable;
    List<String> strings(Object? value) {
      if (value is! List || value.any((item) => item is! String)) throw unreadable;
      return List.unmodifiable(value.cast<String>());
    }

    final project = json['project'];
    final commit = json['commit'];
    final accessCommit = json['access_commit'];
    if (project is! String || commit is! String || accessCommit is! String || json['unchanged'] is! bool) {
      throw unreadable;
    }
    strings(json['dropped']);
    return (
      project: project,
      commit: commit,
      accessCommit: accessCommit,
      added: strings(json['added']),
      refused: strings(json['refused']),
    );
  }

  /// The host's own words: its last line on standard error without the helper's prefix, or [otherwise].
  static String _said(RemoteResult result, String otherwise) {
    if (result.exitCode == 255) return 'The host could not be reached over SSH. Retry.';
    final lines = const LineSplitter()
        .convert(result.stderr)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    if (lines.isEmpty) return otherwise;
    final last = lines.last;
    const prefix = 'porelo-host-person: ';
    return last.startsWith(prefix) ? 'The host refused: ${last.substring(prefix.length)}' : last;
  }
}
