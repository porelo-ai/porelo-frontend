import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'organization_source.dart';
import 'core_credentials.dart';
import 'run_here.dart';
import 'run_porelo.dart';

/// How long a stale answer's check is waited for before the kept state is shown.
Duration refreshLimit = const Duration(seconds: 60);

/// The reason of a refusal that is the person's own choice not to trust a forge's host key.
const _declined = 'host-key-declined';

/// The organization as Porelo's own commands answer: the interface reads no organization file and keeps no checkout.
///
/// Each answer is read field by field, and a field it does not know is passed over, since the answers may grow. A word
/// Porelo says goes to the person as it came; what the program wrote elsewhere never does.
class PoreloOrganizationSource implements OrganizationSource, ReadsKeptFirst, FoundingChecks {
  /// Runs Porelo through [run].
  PoreloOrganizationSource({RunHere? run}) : _run = run ?? runPorelo;

  final RunHere _run;

  /// Prepares the local vault for an operation that needs the central forge's API token.
  Future<void> Function(String repository)? prepareForgeWrite;

  /// Compares and records an unknown forge key in the window before one retry of the same request.
  Future<bool> Function(String host)? confirmForgeHost;

  /// The roles a project's member can have.
  static const roles = ['developer', 'admin'];

  /// How people stood at the last read, for what `project show` does not say of them; null before any read answered.
  Map<String, CardStanding>? _standing;

  /// The organization's newest read while it is under way, which a project read answering meanwhile waits for.
  Future<void>? _organizationRead;

  /// Whether the organization was asked for: once it was, a project read names no card it has not answered.
  bool _organizationAsked = false;

  /// How many organization reads were begun, so one that ends after a newer one leaves the cards as that one stood them.
  var _organizationReads = 0;

  Future<Map<String, Object?>> _ask(List<String> arguments, {bool mayTrust = true}) async {
    final Ran ran;
    try {
      ran = await _run('porelo', [...arguments, '--json']);
    } on ProcessException {
      throw const OrganizationRefused(
        "Porelo's command line could not be started here, so nothing was asked.",
        answered: false,
      );
    } on PoreloNotStarted catch (refused) {
      // Nothing was started, so nothing was done: a refusal, never an answer still to come.
      throw OrganizationRefused(refused.words);
    } on WorkspaceRefused catch (refused) {
      // It ran out its limit: it may have done what it was asked.
      throw OrganizationRefused(refused.words, answered: false);
    }
    if (ran.code != 0) {
      final refused = _refusal(ran);
      if (mayTrust && refused.reason == 'unknown-host-key' && confirmForgeHost != null) {
        // Current Core names the destination only in this public hint, never as a command to execute.
        final hint = RegExp(r"porelo credentials trust-host ([A-Za-z0-9][A-Za-z0-9.:-]*)'").firstMatch(refused.words);
        final host = hint?.group(1);
        if (host != null) {
          CoreCredentials.host(host);
          if (await confirmForgeHost!(host)) return _ask(arguments, mayTrust: false);
          throw const OrganizationRefused(
            'The SSH host key was not trusted, so the request did not continue. Refresh asks again.',
            answered: false,
            reason: _declined,
          );
        }
      }
      throw refused;
    }
    final answer = _object(ran.out);
    if (answer == null) {
      throw const OrganizationRefused('Porelo gave an answer that could not be read.', answered: false);
    }
    return answer;
  }

  /// The Organization Admins, null only where the answer holds none; any other form cannot be said, as it must not
  /// widen rights by reading as the owners' rule.
  static List<String>? _organizationAdmins(Object? listed) {
    if (listed == null) return null;
    if (listed is List && listed.every((login) => login is String)) return List<String>.from(listed);
    throw const OrganizationRefused('Porelo cannot say who the Organization Admins are.', answered: false);
  }

  /// A failure's words, and whether the change may have been made: after 69, 70 or a killed process the id is kept, and
  /// every other refusal made nothing.
  OrganizationRefused _refusal(Ran ran) {
    final mayHaveMade = ran.code == 69 || ran.code == 70 || ran.code < 0;
    final refusal = _object(ran.out);
    final words = refusal?['words'];
    return OrganizationRefused(
      words is String && words.isNotEmpty
          ? words.replaceAll(_askedAgainWithItsId, 'ask again')
          : 'Porelo refused this, and did not say why (exit ${ran.code}).',
      answered: !mayHaveMade,
      reason: refusal?['reason'] is String ? refusal!['reason']! as String : null,
      entry: _entry(refusal?['entry']),
    );
  }

  /// An entry to write, where one with something in it was given.
  static String? _entry(Object? given) => given is String && given.trim().isNotEmpty ? given : null;

  /// The id is this program's to keep, and asking again here sends the same one; the person never types it.
  static final _askedAgainWithItsId = RegExp(r'ask\s+again with (?:the same )?--id(?: [A-Za-z0-9_-]+)?');

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
  Future<OrganizationView> read() => _readSettled(null);

  @override
  Future<OrganizationView> readKeptFirst(void Function(OrganizationView kept) kept) => _readSettled(kept);

  Future<OrganizationView> _readSettled(void Function(OrganizationView kept)? kept) {
    _organizationAsked = true;
    final reading = _readOrganization(kept);
    final settled = reading.then<void>((_) {}, onError: (Object _) {});
    _organizationRead = settled;
    unawaited(
      settled.then((_) {
        if (identical(_organizationRead, settled)) _organizationRead = null;
      }),
    );
    return reading;
  }

  Future<OrganizationView> _readOrganization(void Function(OrganizationView kept)? kept) async {
    final read = ++_organizationReads;
    final first = await _ask(['org']);
    if (kept != null && _reading(() => _flag(first, 'stale'))) {
      final view = _reading(() => _view(first));
      // The kept cards stand for a kept project read until a checked answer says how they stand now.
      _standing ??= {for (final person in view.persons) person.login: person.standing};
      kept(view);
    }
    final (answer, notChecked) = await _checkedAgain(['org'], first);
    final view = _reading(() => _view(answer, notChecked));
    // An older read ending after a newer one says nothing of how the cards stand now.
    if (read != _organizationReads) return view;
    _standing = {for (final person in view.persons) person.login: person.standing};
    return view;
  }

  /// A stale answer is the state Porelo kept, shown before its check: asked once more, it waits for the check. A check
  /// that is refused or does not end leaves the kept state, which still says that it is stale, beside what stopped it;
  /// only a host key the person declined to trust stops the read.
  Future<(Map<String, Object?>, String?)> _checkedAgain(List<String> arguments, Map<String, Object?> kept) async {
    if (!_reading(() => _flag(kept, 'stale'))) return (kept, null);
    try {
      // A check left behind is ended by the command's own limit.
      return (await _ask([...arguments, '--refresh']).timeout(refreshLimit), null);
    } on TimeoutException {
      return (kept, 'the check did not end within ${refreshLimit.inSeconds} seconds');
    } on OrganizationRefused catch (refused) {
      if (refused.reason == _declined) rethrow;
      return (kept, 'the check was refused: ${refused.words}');
    }
  }

  StaleWhy? _staleWhy(Map<String, Object?> answer, String? notChecked) {
    if (notChecked != null) return StaleWhy.notChecked(notChecked);
    final why = _maybeMap(answer, 'stale_why');
    return why == null ? null : StaleWhy(_text(why, 'cause'), said: _maybeText(why, 'said'));
  }

  OrganizationView _view(Map<String, Object?> answer, [String? notChecked]) {
    final vouchedBy = _text(answer, 'vouched_by');
    final me = _maybeMap(answer, 'me');
    return OrganizationView(
      name: _text(answer, 'name'),
      keptIn: _text(answer, 'kept_in'),
      settings: _maybeText(answer, 'settings'),
      forge: _maybeText(answer, 'forge'),
      address: _maybeText(answer, 'address'),
      vouchedBy: vouchedBy,
      revision: _maybeText(answer, 'revision') ?? '',
      stale: _flag(answer, 'stale'),
      checkedAt: DateTime.tryParse(_maybeText(answer, 'checked_at') ?? ''),
      staleWhy: _flag(answer, 'stale') ? _staleWhy(answer, notChecked) : null,
      // No card here: nobody is named, and the person sees *Add me*.
      me: me == null ? '' : _text(me, 'login'),
      owners: _holders(_maps(answer, 'owners')),
      organizationAdmins: _organizationAdmins(answer['organization_admins']),
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
            opened: project.containsKey('opened') ? _flag(project, 'opened') : null,
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
      // Only the projects carried in part; an older porelo says nothing, and every project is carried whole.
      repositories: {
        for (final MapEntry(:key, :value) in (_maybeMap(host, 'repositories') ?? const <String, Object?>{}).entries)
          // Unread, never carried whole: a part read as the whole would offer it to no other machine.
          key: value is List && value.every((name) => name is String)
              ? value.cast<String>().toList()
              : throw _Unreadable('repositories'),
      },
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
  Future<bool> handTokenTo(String host) async {
    final answer = await _ask(['org', 'host', 'refresh', _positional(host, 'host')]);
    return _reading(() {
      if (answer['handedOver'] is! bool) throw const _Unreadable('handedOver');
      return answer['handedOver']! as bool;
    });
  }

  @override
  Future<ProjectView> readProject(String project) => _readProject(project, null);

  @override
  Future<ProjectView> readProjectKeptFirst(String project, void Function(ProjectView kept) kept) =>
      _readProject(project, kept);

  Future<ProjectView> _readProject(String project, void Function(ProjectView kept)? kept) async {
    final first = await _ask(['project', 'show', project]);
    // Shown at once only where its members' cards are known: an unknown card is never shown as "not yet".
    if (kept != null && _reading(() => _flag(first, 'stale'))) {
      if (_standing case final standing?) {
        kept(_projectView(first, null, standing));
      } else if (_reading(() => _maps(first, 'members').isEmpty)) {
        kept(_projectView(first, null, const {}));
      }
    }
    final (answer, notChecked) = await _checkedAgain(['project', 'show', project], first);
    // Its members' cards stand in the organization's answer: the newest under way, or else the last that answered.
    for (var reading = _organizationRead; reading != null; reading = _organizationRead) {
      await reading;
    }
    final known = _standing;
    // A card no answer said is no card "not yet" vouched for, which holds its roles: the read waits for one.
    if (known == null && _organizationAsked && _reading(() => _maps(answer, 'members').isNotEmpty)) {
      throw const OrganizationRefused(
        'The Porelo organization could not be read, so how the members of this project stand cannot be said.',
        answered: false,
      );
    }
    return _projectView(answer, notChecked, known ?? const {});
  }

  ProjectView _projectView(Map<String, Object?> answer, String? notChecked, Map<String, CardStanding> standing) {
    return _reading(() {
      final repositories = _maybeMap(answer, 'repositories');
      final state = repositories == null ? null : _text(repositories, 'state');
      return ProjectView(
        name: _text(answer, 'project'),
        revision: _maybeText(answer, 'revision') ?? '',
        repositoriesRevision: repositories == null ? null : _maybeText(repositories, 'revision'),
        repositoriesProblem: switch (state) {
          // Stale: the organization was not reached, and what it said last cannot judge the repositories' signatures.
          'cannot-say' when _flag(answer, 'stale') => _unreached(
            _maybeText(answer, 'checked_at'),
            _staleWhy(answer, notChecked),
          ),
          'cannot-say' => 'Its repositories could not be read just now.',
          'refused' => 'Its repositories were refused: ${_maybeText(repositories!, 'why') ?? 'no reason given'}.',
          _ => null,
        },
        host: _maybeText(answer, 'host'),
        address: _maybeText(answer, 'address'),
        opened: answer['opened'] == true,
        stale: _flag(answer, 'stale'),
        checkedAt: DateTime.tryParse(_maybeText(answer, 'checked_at') ?? ''),
        staleWhy: _flag(answer, 'stale') ? _staleWhy(answer, notChecked) : null,
        review: repositories == null ? null : _maybeText(repositories, 'review'),
        roles: roles,
        repositories: [
          if (repositories != null)
            for (final repository in _maps(repositories, 'names'))
              ProjectRepository(
                name: _text(repository, 'name'),
                address: _maybeText(repository, 'upstream'),
                central: _maybeText(repository, 'central'),
                review: _maybeText(repository, 'review'),
              ),
        ],
        members: [
          for (final member in _maps(answer, 'members'))
            ProjectMember(
              login: _text(member, 'login'),
              role: _text(member, 'role'),
              locked: member['locked'] == true,
              standing: standing[_text(member, 'login')] ?? CardStanding.notYet,
            ),
        ],
      );
    });
  }

  static String _unreached(String? checkedAt, StaleWhy? why) => [
    'Porelo has not checked the organization just now, so its repositories are not shown.',
    lastChecked(checkedAt == null ? null : DateTime.tryParse(checkedAt)),
    if (why != null) 'Why: ${why.words}',
  ].join(' ');

  @override
  Future<ProjectInitDraft> readProjectInit(String checkout, {String? project, String? name, String? upstream}) async {
    _positional(checkout, 'checkout folder');
    final answer = await _ask([
      'project',
      'init',
      checkout,
      if (project != null) ...['--project', _positional(project, 'project')],
      if (name != null) ...['--name', _positional(name, 'name')],
      if (upstream != null) ...['--upstream', upstream],
    ]);
    try {
      return await _reading(() {
        // An omitted warning list is not an empty one: signing must wait for a complete preview.
        for (final field in ['values', 'disagreements', 'plugins']) {
          if (answer[field] is! List) throw _Unreadable(field);
        }
        if (answer.containsKey('entry') && _entry(answer['entry']) == null) throw const _Unreadable('entry');
        return ProjectInitDraft(
          repository: _text(answer, 'repository'),
          upstream: _maybeText(answer, 'upstream'),
          draft: _text(answer, 'draft'),
          revision: _maybeText(answer, 'revision'),
          entry: _entry(answer['entry']),
          values: [
            for (final value in _maps(answer, 'values'))
              ProjectInitValue(
                key: _text(value, 'key'),
                value: _display(value, 'value'),
                file: _said(value, 'file'),
                line: _line(value),
                origin: _maybeText(value, 'origin'),
                unknown: _truth(value, 'unknown'),
                note: _said(value, 'note'),
                plugin: _maybeText(value, 'plugin'),
              ),
          ],
          disagreements: [
            for (final disagreement in _maps(answer, 'disagreements'))
              (key: _text(disagreement, 'key'), values: _alternatives(disagreement)),
          ],
          unplaced: _listed(answer, 'unplaced'),
          notPlaced: _listed(answer, 'not_placed'),
          credentialsNeeded: _listed(answer, 'credentials_needed'),
          plugins: [
            for (final plugin in _maps(answer, 'plugins'))
              (name: _text(plugin, 'name'), state: _text(plugin, 'state'), why: _said(plugin, 'why')),
          ],
        );
      });
    } on OrganizationRefused {
      throw const OrganizationRefused('The checkout draft could not be read.');
    }
  }

  static int? _line(Map<String, Object?> value) {
    final line = _maybeInt(value, 'line');
    if (line != null && line < 0) throw const _Unreadable('line');
    // Core and the plugins say 0 where a file has no line for the value.
    return line == 0 ? null : line;
  }

  static String _alternatives(Map<String, Object?> value) {
    final values = value['values'];
    if (values is! List) throw const _Unreadable('disagreement values');
    return [
      for (final each in values)
        if (each is Map<String, Object?>)
          [each['value'], if (_where(each) case final where?) '($where)'].join(' ')
        else
          '$each',
    ].join(' or ');
  }

  /// A list Core answers in rows, as a person reads it: empty where it holds nothing.
  static String _listed(Map<String, Object?> value, String field) {
    if (!value.containsKey(field)) throw _Unreadable(field);
    final found = value[field];
    if (found is! List) return found is String ? found : jsonEncode(found);
    return found.map(_row).join('\n');
  }

  static String _row(Object? each) {
    if (each is! Map<String, Object?>) return each is String ? each : jsonEncode(each);
    if (each['id'] case final String credential) return credential;
    final value = '${each['value'] ?? ''}';
    return [
      if (each['key'] case final String key) value.isEmpty ? key : '$key: $value',
      ?_where(each),
      ?_said(each, 'note'),
      if (_said(each, 'plugin') case final plugin?) 'Plugin: $plugin',
    ].join(' · ');
  }

  static String? _where(Map<String, Object?> row) {
    final file = _said(row, 'file');
    if (file == null) return null;
    final line = row['line'];
    return line is int && line > 0 ? '$file:$line' : file;
  }

  /// A word that may be left out: Core says "" for one it has none of.
  static String? _said(Map<String, Object?> map, String field) {
    final value = _maybeText(map, field);
    return value == null || value.isEmpty ? null : value;
  }

  static String _display(Map<String, Object?> value, String field) {
    if (!value.containsKey(field)) throw _Unreadable(field);
    final found = value[field];
    return found is String ? found : jsonEncode(found);
  }

  static String _positional(String value, String field) {
    if (value.isEmpty || value.startsWith('-') || value.contains('\u0000')) {
      throw OrganizationRefused('The $field cannot be used as a command argument.');
    }
    return value;
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

  @override
  Future<List<FoundingNeed>> checkFounding(String address, {bool replace = false}) async {
    final answer = await _ask(['org', 'create', address, '--check', if (replace) '--replace']);
    return _reading(
      () => [
        for (final need in _maps(answer, 'needs'))
          FoundingNeed(
            name: _text(need, 'name'),
            state: _text(need, 'state'),
            words: _text(need, 'words'),
            next: _maybeText(need, 'next'),
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
    if (write.change.byHand) return _byHand(write);
    if (prepareForgeWrite case final prepare?) {
      if (write.change == OrganizationChange.createOrganization) {
        final address = write.input['address'];
        if (address == null) throw const OrganizationRefused('The Porelo organization needs a repository address.');
        await prepare(address);
      } else if (write.change == OrganizationChange.createProjectRepository ||
          (write.change == OrganizationChange.addProject && write.input['review'] != null)) {
        final address = (await read()).address;
        if (address == null) {
          throw const OrganizationRefused('Porelo cannot say where the Porelo organization is kept.', answered: false);
        }
        await prepare(address);
      }
    }
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

  /// Porelo changes no project file that exists: it says the entry, with exit 0 for `project init` and as a `by-hand`
  /// refusal for the rest, and it takes no revision or id for them, as nothing is signed.
  Future<void> _byHand(OrganizationWrite write) async {
    final project = write.input['project'] ?? '';
    final Map<String, Object?> answer;
    try {
      answer = await _ask(_arguments(write));
    } on OrganizationRefused catch (refused) {
      // Removing has nothing to write, so it comes with no entry: its words say what to take out.
      if (refused.reason == 'by-hand') {
        throw ProjectFileByHand(project: project, entry: refused.entry, words: refused.words);
      }
      rethrow;
    }
    if (_entry(answer['entry']) case final entry?) throw ProjectFileByHand(project: project, entry: entry);
    // An older Porelo still writes these itself, and answers the revision it wrote: taken as written, so that asking
    // again cannot make a second commit.
    if (write.change != OrganizationChange.initializeProject && _maybeText(answer, 'revision') != null) return;
    throw const OrganizationRefused('Porelo did not say the entry to write.', answered: false);
  }

  static List<String> _arguments(OrganizationWrite write) {
    final input = write.input;
    String given(String name) =>
        input[name] ?? (throw OrganizationRefused('This change is missing its $name.', answered: true));
    String review() => switch (given('review')) {
      'required' => 'required',
      'optional' => 'optional',
      _ => throw const OrganizationRefused('The review policy must be required or optional.'),
    };
    return switch (write.change) {
      OrganizationChange.createOrganization => [
        'org',
        'create',
        given('address'),
        if (input['replace'] != null) '--replace',
      ],
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
      OrganizationChange.addOrganizationAdmin => ['org', 'admin', 'add', given('login')],
      OrganizationChange.removeOrganizationAdmin => ['org', 'admin', 'remove', given('login')],
      OrganizationChange.addProject => [
        'org',
        'project',
        'add',
        given('project'),
        '--admin',
        given('admin'),
        // Whoever names themselves creates its repository with it, one step for one person.
        if (input.containsKey('review')) ...['--create-repository', '--review', review()],
      ],
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
      // Named repositories each with its own --repository; none is the whole project.
      OrganizationChange.addProjectToHost => [
        'org',
        'host',
        'carry',
        given('host'),
        given('project'),
        for (final name in OrganizationRowChange.repositoriesOf(input)) ...[
          '--repository',
          _positional(name, 'repository'),
        ],
      ],
      OrganizationChange.removeProjectFromHost => [
        'org',
        'host',
        'uncarry',
        given('host'),
        given('project'),
        for (final name in OrganizationRowChange.repositoriesOf(input)) ...[
          '--repository',
          _positional(name, 'repository'),
        ],
      ],
      OrganizationChange.createProjectRepository => [
        'project',
        'create-repository',
        given('project'),
        if (input.containsKey('review')) ...['--review', review()],
      ],
      OrganizationChange.changeProjectReview => [
        'project',
        'review',
        _positional(given('project'), 'project'),
        if (input['repository'] case final repository?) _positional(repository, 'repository'),
        review(),
      ],
      OrganizationChange.initializeProject => [
        'project',
        'init',
        _positional(given('checkout'), 'checkout folder'),
        '--project',
        _positional(given('project'), 'project'),
        if (input['name'] case final name?) ...['--name', _positional(name, 'name')],
        if (input.containsKey('review')) ...['--review', review()],
        if (input['central'] case final central?) ...['--central', central],
        if (input['upstream'] case final upstream?) ...['--upstream', upstream],
      ],
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
        if (input['central'] case final central?) ...['--central', central],
        if (input.containsKey('review')) ...['--review', review()],
      ],
      OrganizationChange.nameRepositoryCentral => [
        'project',
        'repository',
        'change',
        given('project'),
        given('repository'),
        '--central',
        given('central'),
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
