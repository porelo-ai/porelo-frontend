import 'dart:convert';
import 'dart:io';

import 'package:porelo_frontend/client.dart' show Repository;
import 'package:porelo_host/porelo_host.dart' show missingPoreloHost, poreloHostCommand;

import 'machines.dart' show openSsh;
import 'organization_source.dart';
import 'run_here.dart';

/// How a taken repository stands with its central forge in the host's latest answer.
class HostRepositoryCentral {
  /// Keeps the host's state and its optional count or reason.
  const HostRepositoryCentral({this.state = 'cannot-say', this.commits, this.why});

  /// Reads a central state, treating missing or malformed fields as cannot say.
  factory HostRepositoryCentral.read(Object? answer) => switch (answer) {
    // Ahead by none, an empty reason or an empty state says nothing, and reads as cannot say.
    {'state': 'ahead', 'commits': final int commits} when commits > 0 => HostRepositoryCentral(
      state: 'ahead',
      commits: commits,
    ),
    {'state': 'cannot-say', 'why': final String why} when why.trim().isNotEmpty => HostRepositoryCentral(why: why),
    {'state': final String state} when state.trim().isNotEmpty && !{'ahead', 'cannot-say'}.contains(state) =>
      HostRepositoryCentral(state: state),
    _ => const HostRepositoryCentral(),
  };

  /// The host's central state, including words from later hosts.
  final String state;

  /// The number of commits ahead, where the host gave a valid count.
  final int? commits;

  /// The host's reason for being unable to say, where it gave one.
  final String? why;

  /// Whether returning this machine requires a separate acceptance of possible lost work.
  bool get blocksGiveBack => state != 'up-to-date' && !(state == 'cannot-say' && why == 'local');

  /// The state beside the repository, preserving unknown host words.
  String get words => switch (state) {
    'ahead' => '${commits == 1 ? '1 commit' : '$commits commits'} ahead of central',
    'up-to-date' => 'at central',
    'moved-on' => 'central moved on',
    'cannot-say' => 'cannot say: ${centralWhyWords(why) ?? 'the machine did not report its central state'}',
    _ => state,
  };
}

/// Why a host cannot say how its copy stands against central, in words: the host's own reasons and Porelo's when the
/// host's answer was refused or its command failed; a later one as it comes, null where none was given.
String? centralWhyWords(String? why) => switch (why) {
  'no-read-key' => 'no key to read the central forge',
  'unreachable' => 'the central forge cannot be reached',
  'no-central-main' => 'the central forge has no main branch',
  'local' => 'no central forge',
  'host-answer-refused' => 'the machine refused to answer',
  'host-command-failed' => "the machine's command failed",
  null => null,
  final why => why,
};

/// A repository's host state and its central state, where it has been taken.
typedef HostRepositoryProgress = ({String repository, String state, String? why, HostRepositoryCentral? central});

/// How far a host has come with one project it was told to carry, in the words of its `org status`.
class HostProjectProgress {
  /// Keeps the host's word on [project].
  const HostProjectProgress({
    required this.project,
    required this.state,
    this.why,
    this.since,
    this.hasNoAddress = false,
    this.repositories = const [],
  });

  /// Each repository's host state and reason, with its central state once taken.
  final List<HostRepositoryProgress> repositories;

  /// The repositories the host has taken.
  List<String> get taken => [
    for (final each in repositories)
      if (each.state == 'taken') each.repository,
  ];

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
  HostProjectProgress withNoAddress() => HostProjectProgress(
    project: project,
    state: state,
    why: why,
    since: since,
    hasNoAddress: true,
    repositories: repositories,
  );
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
  const HostProgress({
    this.projects = const [],
    this.locked = const [],
    this.waitsForToken = false,
    this.refused,
    this.hasRepositoryStatus = true,
  });

  /// This answer, with [without] known as having no address on the host.
  HostProgress withNoAddress(Set<String> without) => HostProgress(
    projects: [
      for (final project in projects)
        if (without.contains(project.project)) project.withNoAddress() else project,
    ],
    locked: locked,
    waitsForToken: waitsForToken,
    refused: refused,
    hasRepositoryStatus: hasRepositoryStatus,
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
      hasRepositoryStatus: switch (answered['projects']) {
        final List<Object?> projects => projects.every(_hasRepositoryStatus),
        _ => false,
      },
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
              repositories: [
                if (project['repositories'] case final List<dynamic> rows)
                  for (final row in rows)
                    if (row case {'repository': final String repository, 'state': final String state})
                      (
                        repository: repository,
                        state: state,
                        why: row['why'] is String ? row['why']! as String : null,
                        central: state == 'taken' ? HostRepositoryCentral.read(row['central']) : null,
                      ),
              ],
            ),
      ],
      locked: [
        for (final person in maps('persons'))
          if (person case {'login': final String login, 'purge_on': final String day})
            HostLockedPerson(login: login, purgeOn: day),
      ],
    );
  }

  static bool _hasRepositoryStatus(Object? project) => switch (project) {
    {'project': String _, 'state': String _, 'repositories': final List<Object?> rows} => rows.every(
      (row) => switch (row) {
        {'repository': String _, 'state': String _} => true,
        _ => false,
      },
    ),
    {'project': String _, 'state': 'pending' || 'waiting-for-token' || 'refused'} => !project.containsKey(
      'repositories',
    ),
    _ => false,
  };

  /// Whether the host supplied enough repository rows to judge the safety of give-back.
  final bool hasRepositoryStatus;

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

/// How one project on a machine stands with the central forge, as the person's own daemon there last listed it; only a
/// prompt, as the push still decides.
class CentralState {
  /// Keeps what the machine answered, an empty [repositories] where it could not say.
  const CentralState({this.readAt, this.repositories = const []});

  /// Reads the repositories of the daemon's `Projects` row: each it carries and says a central state of, and each it
  /// carries with none said yet, which cannot say. A repository with no central forge has nothing to stand against; the
  /// oldest answer is when it was read.
  factory CentralState.fromRepositories(List<Repository> listed) {
    final said = [
      for (final each in listed)
        if (each.carriedHere != false &&
            each.central != 'no-central' &&
            (each.central != null || each.carriedHere == true))
          each,
    ];
    DateTime? oldest;
    for (final each in said) {
      final at = each.aheadMeasured == null ? null : DateTime.tryParse(each.aheadMeasured!);
      if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
    }
    return CentralState(
      readAt: oldest,
      repositories: [for (final each in said) (state: each.central ?? '', commits: each.ahead ?? 0)],
    );
  }

  /// When the host's follow measured it, normally up to five minutes ago.
  final DateTime? readAt;

  /// Each repository's state: `ahead`, `up-to-date`, `moved-on`; anything else cannot say.
  final List<({String state, int commits})> repositories;

  /// How many approved commits are not at the central forge.
  int get ahead => repositories.fold(0, (sum, row) => row.state == 'ahead' ? sum + row.commits : sum);

  /// Whether a push would be refused.
  bool get movedOn => repositories.any((row) => row.state == 'moved-on');

  /// Whether a repository's state, or all of them, cannot be said: ahead by a count nobody gave says no count.
  bool get cannotSay =>
      repositories.isEmpty ||
      repositories.any(
        (row) => (row.state == 'ahead' && row.commits <= 0) || !{'ahead', 'up-to-date', 'moved-on'}.contains(row.state),
      );

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

  /// The host's read-only answer, as JSON: without `--json` it says it in words.
  static final statusVerb = poreloHostCommand('org status --json');

  /// Makes the host fetch now, with nothing on its standard input: a token goes only by the terminal.
  static final refreshVerb = poreloHostCommand('org refresh');

  /// What the host keeps of a project, and whether it took an address for it. Read-only.
  static String projectFileVerb(String project) => 'cat /etc/porelo-host/organization/projects/$project.json';

  /// The name of a project whose file can be asked for in a remote command.
  static final _plainName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  /// What the host [host], reached through [config], says of itself.
  Future<HostProgress> status(String config, String host) async =>
      _withAddresses(config, host, await _ask(config, host, statusVerb));

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

  Future<Ran> _ssh(String config, String host, String verb) => _run(openSsh('ssh'), [
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
      if (missingPoreloHost(host, answer.code) case final missing?) throw OrganizationRefused(missing);
      final said = answer.err.trim().split('\n').last.trim();
      throw OrganizationRefused(said.isEmpty ? 'The machine refused this, and did not say why.' : said);
    }
    return HostProgress.read(answer.out);
  }
}
