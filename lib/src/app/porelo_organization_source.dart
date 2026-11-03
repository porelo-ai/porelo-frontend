import 'dart:convert';
import 'dart:io';

import 'organization_source.dart';
import 'run_here.dart';

/// The organization as Porelo's own commands answer: the interface reads no organization file and keeps no checkout.
///
/// Each answer is read field by field, and a field it does not know is passed over, since the answers may grow. A word
/// Porelo says goes to the person as it came; what the program wrote elsewhere never does.
class PoreloOrganizationSource implements OrganizationSource {
  /// Runs Porelo through [run].
  PoreloOrganizationSource({RunHere? run}) : _run = run ?? runHere;

  final RunHere _run;

  /// The roles a project's member can have.
  static const roles = ['developer', 'admin'];

  /// How people stood at the last read, for what `project show` does not say of them.
  Map<String, CardStanding> _standing = const {};

  Future<Map<String, Object?>> _ask(List<String> arguments) async {
    final Ran ran;
    try {
      ran = await _run('porelo', [...arguments, '--json']);
    } on ProcessException {
      throw const OrganizationRefused(
        "Porelo's command line could not be started here, so nothing was asked.",
        answered: false,
      );
    } on WorkspaceRefused catch (refused) {
      // It ran out its limit: it may have done what it was asked.
      throw OrganizationRefused(refused.words, answered: false);
    }
    if (ran.code != 0) throw _refusal(ran);
    final answer = _object(ran.out);
    if (answer == null) {
      throw const OrganizationRefused('Porelo gave an answer that could not be read.', answered: false);
    }
    return answer;
  }

  /// A failure's words, and whether the change may have been made: after 69, 70 or a killed process the id is kept, and
  /// every other refusal made nothing.
  OrganizationRefused _refusal(Ran ran) {
    final mayHaveMade = ran.code == 69 || ran.code == 70 || ran.code < 0;
    final refusal = _object(ran.out);
    final words = refusal?['words'];
    return OrganizationRefused(
      words is String && words.isNotEmpty ? words : 'Porelo refused this, and did not say why (exit ${ran.code}).',
      answered: !mayHaveMade,
      reason: refusal?['reason'] is String ? refusal!['reason']! as String : null,
    );
  }

  static Map<String, Object?>? _object(String text) {
    try {
      final decoded = jsonDecode(text.trim());
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  T _reading<T>(T Function() read) {
    try {
      return read();
    } on _Unreadable catch (unreadable) {
      throw OrganizationRefused('Porelo gave an answer that could not be read: ${unreadable.field}.', answered: false);
    }
  }

  @override
  Future<OrganizationView> read() async {
    final answer = await _ask(['org']);
    final view = _reading(() => _view(answer));
    _standing = {for (final person in view.persons) person.login: person.standing};
    return view;
  }

  OrganizationView _view(Map<String, Object?> answer) {
    final vouchedBy = _text(answer, 'vouched_by');
    final me = _maybeMap(answer, 'me');
    return OrganizationView(
      name: _text(answer, 'name'),
      keptIn: _text(answer, 'kept_in'),
      settings: _maybeText(answer, 'settings'),
      forge: _maybeText(answer, 'forge'),
      vouchedBy: vouchedBy,
      revision: _maybeText(answer, 'revision') ?? '',
      stale: _flag(answer, 'stale'),
      // No card here: nobody is named, and the person sees *Add me*.
      me: me == null ? '' : _text(me, 'login'),
      owners: _holders(_maps(answer, 'owners')),
      ownersWithBackup: [
        for (final entry in _maps(answer, 'owners'))
          if (entry['backup'] == true) _text(entry, 'login'),
      ],
      persons: [for (final person in _maps(answer, 'people')) _person(person, vouchedBy)],
      projects: [
        for (final project in _maps(answer, 'projects'))
          OrganizationProject(
            name: _text(project, 'project'),
            admins: _texts(project, 'admins'),
            members: _texts(project, 'members'),
            host: _maybeText(project, 'host'),
          ),
      ],
      hosts: [for (final host in _maps(answer, 'hosts')) _host(host)],
      notes: _notes(answer),
    );
  }

  // A backup key stands in the same list under the same login, and is no holder of its own.
  List<String> _holders(List<Map<String, Object?>> entries) => [
    for (final entry in entries)
      if (entry['backup'] != true) _text(entry, 'login'),
  ];

  OrganizationPerson _person(Map<String, Object?> person, String vouchedBy) {
    final why = _maybeText(person, 'why');
    final state = _text(person, 'state');
    final standing = person['revoked'] == true
        ? CardStanding.revoked
        : switch (state) {
            // Trusted only where the answer says outright it is not revoked.
            'trusted' when person['revoked'] == false => CardStanding.trusted,
            'first-seen' => CardStanding.notYet,
            // A state this build does not know holds nothing, and its words say what it is.
            _ => CardStanding.refused,
          };
    final vouched = _maybeText(person, 'vouched');
    return OrganizationPerson(
      login: _text(person, 'login'),
      standing: standing,
      key: _maybeText(person, 'fingerprint'),
      expires: _maybeText(person, 'expires'),
      words: why != null && why.isNotEmpty
          ? why
          : vouched == 'cannot-say'
          ? '$vouchedBy cannot say now whether this key is theirs'
          : vouched == 'no'
          ? '$vouchedBy does not list this key for them'
          : null,
    );
  }

  OrganizationHost _host(Map<String, Object?> host) {
    final services = _maybeMap(host, 'services');
    final forge = services == null ? null : _maybeMap(services, 'forge');
    final matrix = services == null ? null : _maybeMap(services, 'matrix');
    return OrganizationHost(
      name: _text(host, 'host'),
      address: _maybeText(host, 'address'),
      port: _maybeInt(host, 'ssh_port'),
      hostKey: _maybeText(host, 'ssh_host_key'),
      webPort: forge == null ? null : _maybeInt(forge, 'web_port'),
      gitPort: forge == null ? null : _maybeInt(forge, 'git_port'),
      matrixPort: matrix == null ? null : _maybeInt(matrix, 'port'),
      admins: _holders(_maps(host, 'admins')),
      adminKeys: [
        for (final row in _maps(host, 'admins'))
          HostAdminKey(login: _text(row, 'login'), key: _maybeText(row, 'key'), backup: row['backup'] == true),
      ],
      projects: _texts(host, 'projects'),
    );
  }

  List<String> _notes(Map<String, Object?> answer) => [
    for (final warning in answer['warnings'] is List ? answer['warnings']! as List<Object?> : const <Object?>[])
      if (warning is String) warning,
    for (final refused in _maps(answer, 'refusals'))
      'A change was refused at ${_text(refused, 'path')}: ${_text(refused, 'why')}.',
    for (final sole in _maps(answer, 'sole_without_backup'))
      '${_text(sole, 'login')} is the only ${_text(sole, 'role')}'
          '${_maybeText(sole, 'host') == null ? '' : ' of ${_text(sole, 'host')}'} and has no backup key.',
  ];

  @override
  Future<ProjectView> readProject(String project) async {
    final answer = await _ask(['project', 'show', project]);
    return _reading(() {
      final repositories = _maybeMap(answer, 'repositories');
      final state = repositories == null ? null : _text(repositories, 'state');
      return ProjectView(
        name: _text(answer, 'project'),
        revision: _maybeText(answer, 'revision') ?? '',
        repositoriesRevision: repositories == null ? null : _maybeText(repositories, 'revision'),
        repositoriesProblem: switch (state) {
          'cannot-say' => 'Its repositories could not be read just now.',
          'refused' => 'Its repositories were refused: ${_maybeText(repositories!, 'why') ?? 'no reason given'}.',
          _ => null,
        },
        host: _maybeText(answer, 'host'),
        address: _maybeText(answer, 'address'),
        opened: answer['opened'] == true,
        roles: roles,
        repositories: [
          if (repositories != null)
            for (final repository in _maps(repositories, 'names'))
              ProjectRepository(name: _text(repository, 'name'), address: _maybeText(repository, 'upstream')),
        ],
        members: [
          for (final member in _maps(answer, 'members'))
            ProjectMember(
              login: _text(member, 'login'),
              role: _text(member, 'role'),
              locked: member['locked'] == true,
              standing: _standing[_text(member, 'login')] ?? CardStanding.notYet,
            ),
        ],
      );
    });
  }

  @override
  Future<List<ListedProject>> myProjects() async {
    final answer = await _ask(['project', 'list']);
    return _reading(
      () => [
        for (final project in _maps(answer, 'projects'))
          ListedProject(
            name: _text(project, 'project'),
            source: _text(project, 'source'),
            role: _maybeText(project, 'role'),
            locked: _truth(project, 'locked'),
            host: _maybeText(project, 'host'),
            stale: _flag(answer, 'stale'),
          ),
      ],
    );
  }

  /// The person's own public key, as their card on this computer holds it.
  Future<String> myPublicKey() async {
    final answer = await _ask(['identity', 'show']);
    return _reading(() => _text(answer, 'key'));
  }

  @override
  Future<List<OrganizationKey>> myKeys() async {
    final answer = await _ask(['identity', 'keys']);
    return _reading(
      () => [
        for (final key in _maps(answer, 'keys'))
          if (key['usable'] == true)
            OrganizationKey(
              fingerprint: _text(key, 'fingerprint'),
              label: _maybeText(key, 'comment') ?? '',
              vouched: switch (key['key_listed']) {
                final bool listed => listed,
                _ => null,
              },
            ),
      ],
    );
  }

  @override
  Future<void> apply(OrganizationWrite write) async {
    await _ask([
      ..._arguments(write),
      // Nothing accepted yet: `identity create` takes no base then. Making or choosing an organization never does.
      if (write.base.isNotEmpty &&
          write.change != OrganizationChange.createOrganization &&
          write.change != OrganizationChange.chooseOrganization) ...[
        '--base',
        write.base,
      ],
      // A set-up writes this computer's file alone, and is simply asked again.
      if (write.change != OrganizationChange.chooseOrganization) ...['--id', write.id],
    ]);
  }

  static List<String> _arguments(OrganizationWrite write) {
    final input = write.input;
    String given(String name) =>
        input[name] ?? (throw OrganizationRefused('This change is missing its $name.', answered: true));
    return switch (write.change) {
      OrganizationChange.createOrganization => ['org', 'create', given('address')],
      OrganizationChange.chooseOrganization => [
        'setup',
        '--organization',
        given('address'),
        if (input['replace'] != null) '--replace',
      ],
      OrganizationChange.addCard => [
        'identity',
        'create',
        '--login',
        given('login'),
        '--name',
        given('name'),
        if (input['email'] case final email? when email.isNotEmpty) ...['--email', email],
        '--key',
        given('key'),
      ],
      OrganizationChange.changeCard => ['identity', 'rotate', '--key', given('key')],
      OrganizationChange.revokeCard => ['org', 'person', 'revoke', given('login')],
      OrganizationChange.replaceCard => ['org', 'person', 'replace', given('login'), '--card', given('card')],
      OrganizationChange.addOrganizationOwner => ['org', 'owner', 'add', given('login')],
      OrganizationChange.removeOrganizationOwner => ['org', 'owner', 'remove', given('login')],
      OrganizationChange.addProject => ['org', 'project', 'add', given('project'), '--admin', given('admin')],
      OrganizationChange.changeProjectAdmin => ['org', 'project', 'admin', given('project'), given('admin')],
      OrganizationChange.removeProject => ['org', 'project', 'remove', given('project')],
      OrganizationChange.addHost => ['org', 'host', 'add', given('host'), '--admin', given('admin')],
      OrganizationChange.removeHost => ['org', 'host', 'remove', given('host')],
      OrganizationChange.changeHost => [
        'org',
        'host',
        'change',
        given('host'),
        // What is not named stays as it is; the command asks for address, port and key on a first change.
        if (input['address'] case final address? when address.isNotEmpty) ...['--address', address],
        if (input['port'] case final port? when port.isNotEmpty) ...['--ssh-port', port],
        if (input['hostKey'] case final key? when key.isNotEmpty) ...['--host-key', key],
        if (input['webPort'] case final port? when port.isNotEmpty) ...['--forge-web-port', port],
        if (input['gitPort'] case final port? when port.isNotEmpty) ...['--forge-git-port', port],
        if (input['matrixPort'] case final port? when port.isNotEmpty) ...['--matrix-port', port],
      ],
      OrganizationChange.addHostAdmin => ['org', 'host', 'admin', 'add', given('host'), given('login')],
      OrganizationChange.removeHostAdmin => ['org', 'host', 'admin', 'remove', given('host'), given('login')],
      OrganizationChange.addProjectToHost => ['org', 'host', 'carry', given('host'), given('project')],
      OrganizationChange.removeProjectFromHost => ['org', 'host', 'uncarry', given('host'), given('project')],
      OrganizationChange.openProject => ['project', 'open', given('project')],
      OrganizationChange.changeProjectRepository => ['project', 'address', given('project'), given('address')],
      OrganizationChange.addProjectMember => [
        'project',
        'member',
        'add',
        given('project'),
        given('login'),
        '--role',
        given('role'),
      ],
      OrganizationChange.changeProjectMemberRole => [
        'project',
        'member',
        'role',
        given('project'),
        given('login'),
        given('role'),
      ],
      OrganizationChange.removeProjectMember => ['project', 'member', 'remove', given('project'), given('login')],
      OrganizationChange.lockProjectMember => ['project', 'member', 'lock', given('project'), given('login')],
      OrganizationChange.unlockProjectMember => ['project', 'member', 'unlock', given('project'), given('login')],
      OrganizationChange.addProjectRepository => [
        'project',
        'repository',
        'add',
        given('project'),
        given('repository'),
        '--upstream',
        given('address'),
      ],
      OrganizationChange.removeProjectRepository => [
        'project',
        'repository',
        'remove',
        given('project'),
        given('repository'),
      ],
    };
  }

  static String _text(Map<String, Object?> map, String field) {
    final value = map[field];
    return value is String ? value : throw _Unreadable(field);
  }

  static String? _maybeText(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value == null) return null;
    return value is String ? value : throw _Unreadable(field);
  }

  /// A truth value that may be left out, and is no other word: a malformed one must not read as false.
  static bool _flag(Map<String, Object?> map, String field) => map[field] == null ? false : _truth(map, field);

  static bool _truth(Map<String, Object?> map, String field) {
    final value = map[field];
    return value is bool ? value : throw _Unreadable(field);
  }

  static int? _maybeInt(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value == null) return null;
    return value is int ? value : throw _Unreadable(field);
  }

  static Map<String, Object?>? _maybeMap(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value == null) return null;
    return value is Map<String, Object?> ? value : throw _Unreadable(field);
  }

  static List<Map<String, Object?>> _maps(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value == null) return const [];
    if (value is! List) throw _Unreadable(field);
    return [
      for (final each in value)
        if (each is Map<String, Object?>) each else throw _Unreadable(field),
    ];
  }

  static List<String> _texts(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value == null) return const [];
    if (value is! List) throw _Unreadable(field);
    return [
      for (final each in value)
        if (each is String) each else throw _Unreadable(field),
    ];
  }
}

class _Unreadable implements Exception {
  const _Unreadable(this.field);

  final String field;
}
