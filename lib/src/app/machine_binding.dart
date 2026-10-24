import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:yaml/yaml.dart';
import 'package:porelo_host/porelo_host.dart' show forgeAddress;

import 'forge_connection.dart';

import 'fleet_backend.dart';
import 'forge.dart';
import 'project_workspace.dart';
import 'quiet_after_dispose.dart';

/// Why a machine was not bound, in words a person can act on.
class BindingRefused implements Exception {
  /// Constructor taking the sentence.
  const BindingRefused(this.words);

  /// Why, in a sentence a person can act on.
  final String words;

  @override
  String toString() => words;
}

/// What a project's configuration says of itself, as far as binding a machine needs it.
class ProjectShape {
  /// Its name, which every machine follows it by.
  final String name;

  /// Its work repositories: each name to its upstream.
  final Map<String, String> repositories;

  /// Constructor taking both.
  const ProjectShape({required this.name, required this.repositories});

  /// Reads it from [text], a `project.yml`. Refused, in words, where it has no name.
  factory ProjectShape.of(String text) {
    final Object? read;
    try {
      read = loadYaml(text);
    } on YamlException catch (ex) {
      throw WorkspaceRefused('project.yml cannot be read: ${ex.message}');
    }
    final project = read is YamlMap ? read['project'] : null;
    final name = project is YamlMap ? project['name'] : null;
    if (name is! String || name.isEmpty) throw const WorkspaceRefused('project.yml names no project.');
    final repositories = read is YamlMap ? read['repositories'] : null;
    return ProjectShape(
      name: name,
      repositories: <String, String>{
        if (repositories is YamlMap)
          for (final entry in repositories.entries)
            if (entry.value case final YamlMap each when each['upstream'] is String)
              '${entry.key}': each['upstream'] as String,
      },
    );
  }
}

/// `owner/name` on github.com for an upstream git reaches it by, or null for anything else.
String? onGitHub(String upstream) {
  final match = RegExp(r'^(?:git@github\.com:|ssh://git@github\.com/|https://github\.com/)([^/]+/[^/]+?)(?:\.git)?/?$')
      .firstMatch(upstream.trim());
  return match?.group(1);
}

/// The key part of a public key, `ssh-ed25519 AAAA…`, without its comment: how two are compared.
String keyPart(String publicKey) => publicKey.trim().split(RegExp(r'\s+')).take(2).join(' ');

/// [text], an `machine-signers` file, without [line] and the comment naming [machine] above it; null
/// where it does not hold the line.
///
/// Matched by its key, `<type> <key>`, not the whole line: a person may have added options to it.
String? withoutSigner(String text, String line, String machine) {
  final words = line.trim().split(RegExp(r'\s+'));
  if (words.length < 2) return null;
  final key = words.sublist(words.length - 2).join(' ');
  bool isIt(String each) {
    final w = each.trim().split(RegExp(r'\s+'));
    return w.length >= 2 && w.sublist(w.length - 2).join(' ') == key;
  }

  final lines = text.split('\n');
  if (!lines.any(isIt)) return null;
  return <String>[
    for (var i = 0; i < lines.length; i++)
      if (!isIt(lines[i]) && !(lines[i].trim() == '# $machine' && i + 1 < lines.length && isIt(lines[i + 1]))) lines[i],
  ].join('\n');
}

/// Binding one machine to a project, and removing it again.
///
/// The machine follows over https with the person's token in its vault, pinned to their signing
/// key. Its message key is added to machine-signers in a commit signed on this computer.
class MachineBinding extends ChangeNotifier with QuietAfterDispose {
  /// Constructor taking the forge, the project's clone here, and the machine.
  MachineBinding(this.forge, this.workspace, this._machine, {required this.machineName, required this.login});

  /// The forge the project's repositories are on, reached with the token in use.
  Forge forge;

  /// The project's own repository, cloned on this computer.
  ProjectWorkspace workspace;

  /// Goes on with a token changed while this is open: the next step is taken with it, and what
  /// stopped the last one is put away, to be found again only if it still stops it.
  void useToken(Forge forge, ProjectWorkspace workspace) {
    this.forge = forge;
    this.workspace = workspace;
    problem = null;
    notifyListeners();
  }

  final FleetBackend _machine;

  /// The machine, as the person calls it.
  final String machineName;

  /// The forge login a signed commit is pushed with.
  final String login;

  /// What was done, in order, in words.
  final List<String> done = <String>[];

  /// The fingerprint the machine pinned, once it follows: compared with the person's, never typed.
  String? pinned;

  /// The follow's answer where it waits on a host key a person decides about; null otherwise.
  Followed? hostKey;

  /// The host key fingerprints the forge publishes for itself; empty where it could not be asked.
  List<String> published = const <String>[];

  /// The key the host offered that the forge publishes too: the one a person can trust here
  /// without comparing by eye. Null where none matches, or the host's key changed.
  HostKey? get publishedOffer => hostKey?.outcome != 'UNKNOWN_HOST_KEY'
      ? null
      : hostKey?.hostKeys.where((each) => published.contains(each.fingerprint)).firstOrNull;

  Future<List<String>> _published() async {
    try {
      return await forge.hostKeyFingerprints();
    } on Object {
      return const <String>[];
    }
  }

  /// Trusts the host key the forge publishes, then binds again: what was done before is not done
  /// twice.
  Future<void> trustPublishedAndBind(
    SigningKey person, {
    List<ForgeSigningKey> signers = const <ForgeSigningKey>[],
  }) async {
    final offer = publishedOffer;
    final host = hostKey?.host ?? '';
    if (offer == null || host.isEmpty) return;
    await _doing(() async {
      final trusted = await _machine.trustHostKey(host, offer.fingerprint);
      if (!trusted.recorded) {
        problem = trusted.detail.isEmpty ? 'Nothing was recorded.' : trusted.detail;
        return;
      }
      _say(
        '$machineName trusts ${trusted.type.isEmpty ? '' : '${trusted.type} '}${offer.fingerprint} for $host, as ${forge.name} publishes it.',
      );
    });
    if (problem == null) await bind(person, signers: signers);
  }

  /// Every key the follow pinned, where it pinned several.
  List<String> pinnedAll = const <String>[];

  /// Says where a work repository holds a `project.yml` of its own: here it is only worked in, and
  /// its file means nothing to this project (walk 8: `porelo-test-1` still held one from an earlier
  /// test, and nothing said so).
  Future<void> _sayWhereItIsAProjectItself(String fullName, String project) async {
    try {
      if (await forge.hasProjectFile(await forge.repository(fullName))) {
        _say(
          '$fullName holds a project.yml of its own. As a work repository of $project it is only worked '
          'in; its own project.yml is not read here.',
        );
      }
    } on Object {
      // Not knowing is no reason to stop a binding.
    }
  }

  Future<bool> _takesSeveralSigners() async {
    try {
      final contract = await _machine.contract();
      return RegExp(r'method Follow\((.*?)\)\s*->', dotAll: true).firstMatch(contract)?.group(1)?.contains('signers') ??
          false;
    } on Object {
      return false;
    }
  }

  /// The project, once bound: what starting work on the machine opens on.
  String? bound;

  /// Why the last step did not happen, or null.
  String? problem;

  /// Whether a step is running.
  bool busy = false;

  /// Whether the machine's Porelo can be bound from here at all, read off its contract **before**
  /// anything is asked of it: a follow pinned to the person's key. Null where it could not be read.
  Future<bool?> canBeBound() async {
    try {
      final contract = await _machine.contract();
      bool takes(String method, String parameter) =>
          RegExp('method $method\\((.*?)\\)\\s*->', dotAll: true).firstMatch(contract)?.group(1)?.contains(parameter) ??
          false;
      return takes('Follow', 'signedBy');
    } on FeatureNotSupported {
      return false;
    } on VarlinkException {
      return null;
    } on VarlinkDisconnected {
      return null;
    }
  }

  /// The forge host whose token belongs in the machine's vault.
  String get tokenHost => forgeAddress(hostOf(workspace.repository.httpsUrl) ?? '');

  /// Reads only credential names, never a value, from the machine's vault listing.
  Future<bool> hasToken() async {
    final state = await _machine.credentials();
    if (!state.readable) throw const BindingRefused('The machine’s vault cannot be read. Open it first.');
    return state.credentials.any((each) => each.name == 'git.token.$tokenHost');
  }

  /// Binds only after the vault confirms the terminal command's entry by name.
  Future<void> bind(
    SigningKey person, {
    List<ForgeSigningKey> signers = const <ForgeSigningKey>[],
    Future<void> Function()? storeToken,
  }) => _doing(() async {
    if (!await hasToken()) {
      await storeToken?.call();
      if (!await hasToken()) throw BindingRefused('No git.token.$tokenHost is listed in the machine’s vault.');
    }
    await _bind(person, signers);
  });

  Future<void> _bind(SigningKey person, List<ForgeSigningKey> signers) async {
    final shape = ProjectShape.of(await workspace.read() ?? '');
    final several = signers.isNotEmpty && await _takesSeveralSigners();
    final followed = several
        ? await _machine.follow(
            shape.name,
            workspace.repository.httpsUrl,
            signers: <String>[for (final each in signers) each.keyPart],
          )
        : await _machine.follow(shape.name, workspace.repository.httpsUrl, signedBy: keyPart(person.publicKey));
    if (const <String>{'UNKNOWN_HOST_KEY', 'HOST_KEY_CHANGED'}.contains(followed.outcome)) {
      // The machine has never met the forge's host, or met another key there: the person
      // decides, by what the forge publishes, before anything is pinned or registered further.
      hostKey = followed;
      published = await _published();
      _say(
        followed.outcome == 'HOST_KEY_CHANGED'
            ? '$machineName met another key at ${followed.host} than the one it remembers.'
            : '$machineName has never met ${followed.host}.',
      );
      return;
    }
    hostKey = null;
    // A refused first follow leaves no project to register a message signer for.
    if (!followed.recorded && followed.commit.isEmpty) {
      throw BindingRefused(
        '$machineName did not follow ${shape.name}: '
        '${followed.detail.isNotEmpty ? followed.detail : followed.outcome}. Nothing of it is on $machineName.',
      );
    }
    pinnedAll = followed.pinned;
    pinned = followed.pinned.isNotEmpty ? followed.pinned.first : followed.signer;
    _say(
      several
          ? '$machineName follows ${shape.name}, pinned to your ${followed.pinned.length} signing keys at ${forge.name}.'
          : '$machineName follows ${shape.name}, pinned to ${followed.signer.isEmpty ? 'your key' : followed.signer}.',
    );
    for (final upstream in shape.repositories.values) {
      final there = fullNameOf(upstream);
      if (hostOf(upstream) == tokenHost && there != null) {
        await _sayWhereItIsAProjectItself(there, shape.name);
      }
    }
    final signer = await _machine.messageKey();
    final lines = (await workspace.readFile('machine-signers') ?? '').split('\n');
    if (lines.any((each) => each.trim() == signer.line.trim())) {
      _say('$machineName is in machine-signers already.');
    } else {
      final kept = lines.where((each) => each.isNotEmpty).toList();
      await workspace.writeFile('machine-signers', '${<String>[...kept, '# $machineName', signer.line].join('\n')}\n');
      await workspace.commitAndPush(
        'Let $machineName sign messages in ${shape.name}',
        person,
        login: login,
        files: const <String>['machine-signers'],
      );
      _say('$machineName’s message key is in machine-signers, committed signed and pushed.');
    }
    bound = shape.name;
  }

  /// Stops following and removes its machine-signers line, leaving forge access alone.
  Future<void> remove(SigningKey person) => _doing(() async {
    final shape = ProjectShape.of(await workspace.read() ?? '');
    final forgotten = await _machine.unfollow(shape.name, force: true);
    if (forgotten.detail.isNotEmpty) _say(forgotten.detail);
    for (final kept in forgotten.keeps) {
      _say(kept);
    }
    for (final key in forgotten.keys) {
      _say(key.title);
    }
    final signer = forgotten.signer;
    final text = await workspace.readFile('machine-signers');
    final kept = signer == null || text == null ? null : withoutSigner(text, signer.line, machineName);
    if (kept != null) {
      await workspace.writeFile('machine-signers', kept);
      await workspace.commitAndPush(
        'Take $machineName out of ${shape.name}',
        person,
        login: login,
        files: const <String>['machine-signers'],
      );
      _say('$machineName’s line is out of machine-signers, committed signed and pushed.');
    }
    _say('$machineName no longer follows ${shape.name}.');
    bound = null;
  });

  /// Every line of the project's `machine-signers`, with the comment naming it where there is one.
  List<({String? name, String line})>? signers;

  /// Reads machine-signers without contacting the machine, so a lost machine can be removed.
  Future<void> survey() => _doing(() async {
    final lines = (await workspace.readFile('machine-signers') ?? '').split('\n');
    signers = <({String? name, String line})>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim().isNotEmpty && !lines[i].trim().startsWith('#'))
          (
            name: i > 0 && lines[i - 1].trim().startsWith('#') ? lines[i - 1].trim().substring(1).trim() : null,
            line: lines[i].trim(),
          ),
    ];
  });

  /// Takes [line] out of `machine-signers`, with the comment naming it, as a commit signed with [person].
  Future<void> removeSigner(String line, SigningKey person) => _doing(() async {
    final lines = (await workspace.readFile('machine-signers') ?? '').split('\n');
    final kept = <String>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim() != line &&
            !(lines[i].trim().startsWith('#') && i + 1 < lines.length && lines[i + 1].trim() == line))
          lines[i],
    ];
    await workspace.writeFile('machine-signers', kept.join('\n'));
    await workspace.commitAndPush(
      'Take a signer out of machine-signers',
      person,
      login: login,
      files: const <String>['machine-signers'],
    );
    signers = <({String? name, String line})>[
      for (final each in signers ?? const <({String? name, String line})>[])
        if (each.line != line) each,
    ];
    _say('Took ${line.split(' ').first} out of machine-signers, committed signed and pushed.');
  });

  /// Configuration changes waiting at the machine's gate for the project's own repository, or null
  /// before they were asked for. A person merges them here, signed, and the machine is told they landed.
  List<PendingPush>? changes;

  /// The change being looked at, and what it would change against the default branch.
  String? reviewing;

  /// What [reviewing] would change against the default branch, as a diff.
  String reviewDiff = '';

  /// Asks the machine what waits at its gate for the project's own repository.
  Future<void> loadChanges() => _doing(() async {
    final shape = ProjectShape.of(await workspace.read() ?? '');
    final project = (await _machine.projects()).where((each) => each.name == shape.name).firstOrNull;
    if (project == null) {
      changes = const <PendingPush>[];
      _say('$machineName does not follow ${shape.name}, so nothing waits there for it.');
      return;
    }
    // Asked by the project's name, as every gate call takes it.
    changes = (await _machine.gateOf(project.name)).pending;
  });

  /// Takes [change] from the gate into the clone here, to be read before it is merged.
  Future<void> review(PendingPush change) => _doing(() async {
    final shape = ProjectShape.of(await workspace.read() ?? '');
    final handed = await _machine.pendingBundle(shape.name, change.name, branch: workspace.repository.defaultBranch);
    reviewDiff = await workspace.takeBundle(handed.bundle, change.name);
    reviewing = change.name;
  });

  /// Merges [change], once reviewed, signed with [person], pushes it, and tells the machine it landed.
  Future<void> merge(PendingPush change, SigningKey person) async {
    if (reviewing != change.name) return;
    await _doing(() async {
      final shape = ProjectShape.of(await workspace.read() ?? '');
      final branch = workspace.repository.defaultBranch;
      await workspace.mergeAndPush(change.name, 'Take “${change.subject}” from $machineName', person, login: login);
      final told = await _machine.landed(shape.name, change.name, branch: branch);
      _say(
        told.landed
            ? 'Merged “${change.subject}” signed, pushed to $branch, and cleared at $machineName’s gate.'
            : 'Merged “${change.subject}” signed and pushed; $machineName says: ${told.detail}',
      );
      reviewing = null;
      reviewDiff = '';
      changes = <PendingPush>[
        for (final each in changes ?? const <PendingPush>[])
          if (each.name != change.name || !told.landed) each,
      ];
    });
  }

  void _say(String words) {
    done.add(words);
    notifyListeners();
  }

  Future<void> _doing(Future<void> Function() action) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await action();
    } on FormatException catch (error) {
      problem = error.message;
    } on ForgeRefused catch (refused) {
      problem = refused.words;
    } on BindingRefused catch (refused) {
      problem = refused.words;
    } on WorkspaceRefused catch (refused) {
      problem = refused.words;
    } on FeatureNotSupported {
      problem = '$machineName cannot be bound from here: its Porelo is older than that.';
    } on VarlinkException catch (refusal) {
      problem = refusal.simpleName == 'BundleTooLarge'
          ? 'It is too large to review here (${refusal.parameters['bytes']} bytes, at most '
                '${refusal.parameters['limit']}); take it at $machineName’s own terminal.'
          : '$machineName refused it: ${refusal.parameters['message'] ?? refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with $machineName: ${ex.message}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
