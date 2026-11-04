import 'dart:convert';
import 'dart:io';

import 'organization_source.dart';
import 'run_here.dart';

/// How far a host has come with one project it was told to carry, in the words of its `org status`.
class HostProjectProgress {
  /// Keeps the host's word on [project].
  const HostProjectProgress({
    required this.project,
    required this.state,
    this.why,
    this.since,
    this.hasNoAddress = false,
  });

  /// The project.
  final String project;

  /// `pending`, `carried`, `waiting-for-token`, `held`, `refused`, or a word of a later host.
  final String state;

  /// Why it stands so, where the host said: for `held`, the repositories with unpushed commits; for `refused`, what it
  /// refused.
  final String? why;

  /// Since when, where the host said.
  final String? since;

  /// Whether the host took no address for it. It names this state as waiting for a token, which cannot help then: the
  /// project's admin has to open it or file its address anew.
  final bool hasNoAddress;

  /// Whether the host waits for the host admin's central token for it.
  bool get waitsForToken => state == 'waiting-for-token' && !hasNoAddress;

  /// The same word, knowing the host took no address for it.
  HostProjectProgress withNoAddress() =>
      HostProjectProgress(project: project, state: state, why: why, since: since, hasNoAddress: true);
}

/// A person locked on a host, whose account goes by itself on [purgeOn].
class HostLockedPerson {
  /// Keeps who, and the day.
  const HostLockedPerson({required this.login, required this.purgeOn});

  /// Their login.
  final String login;

  /// The day their account is deleted.
  final String purgeOn;
}

/// What a host itself says of how far it has come, which only a host admin can ask.
class HostProgress {
  /// Keeps one answer of the host's.
  const HostProgress({this.projects = const [], this.locked = const [], this.waitsForToken = false, this.refused});

  /// This answer, with [without] known as having no address on the host.
  HostProgress withNoAddress(Set<String> without) => HostProgress(
    projects: [
      for (final project in projects)
        if (without.contains(project.project)) project.withNoAddress() else project,
    ],
    locked: locked,
    waitsForToken: waitsForToken,
    refused: refused,
  );

  /// Reads `org status` or `org refresh`; what this build does not know is passed over, and a part of an older host's
  /// answer that is absent says nothing.
  factory HostProgress.read(String answer) {
    const incomplete = OrganizationRefused('The machine answered incompletely.');
    final Object? read;
    try {
      read = jsonDecode(answer.trim());
    } on FormatException {
      throw incomplete;
    }
    if (read is! Map) throw incomplete;
    final answered = read;
    List<Map<Object?, Object?>> maps(String field) => [
      if (answered[field] case final List<Object?> list)
        for (final entry in list)
          if (entry is Map) entry,
    ];
    return HostProgress(
      waitsForToken: answered['organization'] == 'waiting-for-token',
      refused: answered['refused'] is String ? answered['refused']! as String : null,
      projects: [
        for (final project in maps('projects'))
          if (project case {'project': final String name, 'state': final String state})
            HostProjectProgress(
              project: name,
              state: state,
              why: project['why'] is String ? project['why']! as String : null,
              since: project['since'] is String ? project['since']! as String : null,
            ),
      ],
      locked: [
        for (final person in maps('persons'))
          if (person case {'login': final String login, 'purge_on': final String day})
            HostLockedPerson(login: login, purgeOn: day),
      ],
    );
  }

  /// The projects the host says anything of.
  final List<HostProjectProgress> projects;

  /// The persons locked there, each with the day their account goes.
  final List<HostLockedPerson> locked;

  /// Whether the host itself waits for its first token, before it can read the organization.
  final bool waitsForToken;

  /// The words of what the host's last fetch refused, or null. What it took before stays in force.
  ///
  /// Never to be read as a removal: a removal and a commit nobody allowed look the same, so a host admin judges it.
  final String? refused;

  /// The host's word on [project], or null.
  HostProjectProgress? of(String project) => projects.where((each) => each.project == project).firstOrNull;

  /// Whether anything waits for the host admin's central token.
  bool get wantsToken => waitsForToken || projects.any((project) => project.waitsForToken);
}

/// How one project on a machine stands with the central forge, as its follow last read it; only a prompt, as the
/// push still decides.
class CentralState {
  /// Keeps what the machine answered, an empty [repositories] where it could not say.
  const CentralState({this.readAt, this.repositories = const []});

  /// Reads the machine's answer; anything else than its contract's shape cannot say, and never reads as up to date.
  factory CentralState.fromAnswer(String answer) {
    try {
      final read = jsonDecode(answer);
      if (read is! Map) return const CentralState();
      final rows = read['repositories'];
      return CentralState(
        readAt: read['read_at'] is String ? DateTime.tryParse(read['read_at'] as String) : null,
        repositories: [
          if (rows is List)
            for (final row in rows)
              if (row is Map)
                (
                  state: row['state'] is String ? row['state'] as String : '',
                  commits: row['commits'] is int ? row['commits'] as int : 0,
                ),
        ],
      );
    } on FormatException {
      return const CentralState();
    }
  }

  /// When the machine's follow read, normally up to five minutes ago.
  final DateTime? readAt;

  /// Each repository's state: `ahead`, `up-to-date`, `moved-on`; anything else cannot say.
  final List<({String state, int commits})> repositories;

  /// How many approved commits are not at the central forge.
  int get ahead => repositories.fold(0, (sum, row) => row.state == 'ahead' ? sum + row.commits : sum);

  /// Whether a push would be refused.
  bool get movedOn => repositories.any((row) => row.state == 'moved-on');

  /// Whether a repository's state, or all of them, cannot be said.
  bool get cannotSay =>
      repositories.isEmpty ||
      repositories.any((row) => row.state != 'ahead' && row.state != 'up-to-date' && row.state != 'moved-on');

  /// Whether to offer the push beside the row.
  bool get offersPush => ahead > 0 && !movedOn;

  /// What the row says, with [forge] the central forge's name.
  String words(String forge) {
    if (movedOn) return '$forge has moved on: a push would be refused';
    if (ahead > 0) {
      final commits = ahead == 1 ? '1 approved commit' : '$ahead approved commits';
      return '$commits not yet at $forge${cannotSay ? ', and cannot say for the rest' : ''}';
    }
    return cannotSay ? 'cannot say how it stands with $forge' : 'up to date with $forge';
  }
}

/// What a machine's refusal of a person's root login means: each follow sets who reaches root.
String notTheAdminsKey(String host) =>
    '$host did not take your key as root: it is not a key of this machine\'s admins now.';

/// Asks a host how it stands, as root, through the pinned config of the person's connection.
class SshHostProgress {
  /// Runs ssh through [run].
  SshHostProgress({RunHere? run}) : _run = run ?? runHere;

  final RunHere _run;

  /// The host's read-only answer.
  static const statusVerb = '/usr/local/sbin/porelo-host-person org status';

  /// Makes the host fetch now, with nothing on its standard input: a token goes only by the terminal.
  static const refreshVerb = '/usr/local/sbin/porelo-host-person org refresh';

  /// What the host keeps of a project, and whether it took an address for it. Read-only.
  static String projectFileVerb(String project) => 'cat /etc/porelo-host/organization/projects/$project.json';

  /// How [project] stands with the central forge, as the machine's follow wrote it. Read-only, with no token or root.
  static String centralVerb(String project) => '/usr/local/sbin/porelo-host-push --central $project';

  /// The name of a project whose file can be asked for in a remote command.
  static final _plainName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  /// What the host [host], reached through [config], says of itself.
  Future<HostProgress> status(String config, String host) async =>
      _withAddresses(config, host, await _ask(config, host, statusVerb));

  /// What [host] says of [project] and the central forge; an answer it refuses or a call that fails cannot say.
  Future<CentralState> central(String config, String host, String project) async {
    if (!_plainName.hasMatch(project)) return const CentralState();
    final Ran answer;
    try {
      answer = await _ssh(config, host, centralVerb(project));
    } on ProcessException {
      return const CentralState();
    } on WorkspaceRefused {
      return const CentralState();
    }
    return answer.code == 0 ? CentralState.fromAnswer(answer.out) : const CentralState();
  }

  /// Asks [host] to fetch now, and what it says then.
  Future<HostProgress> refresh(String config, String host) async =>
      _withAddresses(config, host, await _ask(config, host, refreshVerb));

  /// Tells a real wait for the token from a project the host took no address for; `org status` says both alike.
  Future<HostProgress> _withAddresses(String config, String host, HostProgress progress) async {
    final without = <String>{};
    for (final project in progress.projects) {
      if (project.waitsForToken && _plainName.hasMatch(project.project)) {
        if (await _hasNoAddress(config, host, project.project)) without.add(project.project);
      }
    }
    return without.isEmpty ? progress : progress.withNoAddress(without);
  }

  /// True only where the host's file says so: what cannot be read leaves the host's own word standing.
  Future<bool> _hasNoAddress(String config, String host, String project) async {
    final Ran answer;
    try {
      answer = await _ssh(config, host, projectFileVerb(project));
    } on ProcessException {
      return false;
    } on WorkspaceRefused {
      return false;
    }
    if (answer.code != 0) return false;
    try {
      final read = jsonDecode(answer.out);
      return read is Map && read.containsKey('address') && read['address'] == null;
    } on FormatException {
      return false;
    }
  }

  Future<Ran> _ssh(String config, String host, String verb) => _run('ssh', [
    '-F',
    config,
    '-T',
    '-o',
    'BatchMode=yes',
    '-o',
    'ForwardAgent=no',
    '-o',
    'ControlMaster=no',
    '-o',
    'ControlPath=none',
    '-o',
    'ProxyCommand=none',
    'root@$host',
    verb,
  ], input: '');

  Future<HostProgress> _ask(String config, String host, String verb) async {
    final Ran answer;
    try {
      answer = await _ssh(config, host, verb);
    } on ProcessException {
      throw const OrganizationRefused('SSH could not run on this computer.');
    } on WorkspaceRefused catch (refused) {
      throw OrganizationRefused(refused.words);
    }
    if (answer.code != 0) {
      // Each follow sets who reaches root, so a key the host does not take is not its admin's now, and no fault.
      if (answer.err.contains('Permission denied')) {
        throw OrganizationRefused(notTheAdminsKey(host));
      }
      final said = answer.err.trim().split('\n').last.trim();
      throw OrganizationRefused(said.isEmpty ? 'The machine refused this, and did not say why.' : said);
    }
    return HostProgress.read(answer.out);
  }
}
