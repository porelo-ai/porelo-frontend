import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

import 'access_developers.dart' show checkForgeLogin;

/// Read access to the private access repository, reported by its forge.
abstract interface class ForgeCollaborators {
  /// Refuses a token or account without Administration on the access repository.
  Future<void> checkAdministration(String repository);

  /// Invites [login] with read permission, returning the forge's confirmed state.
  Future<String> grantRead(String repository, String login);

  /// Revokes direct access and any pending invitation for [login].
  Future<void> revokeRead(String repository, String login);

  /// Reads pending invitations and effective repository permissions.
  Future<Map<String, String>> readAccess(String repository, Iterable<String> logins);
}

/// A repository a person can reach on a forge, as the forge lists it for their login.
class ForgeRepository {
  /// `owner/name`, as the forge names it.
  final String fullName;

  /// Where git reaches it over ssh, as the forge gives it: what a machine follows and fetches.
  final String sshUrl;

  /// Where git reaches it over https, with the person's token: what this computer clones from.
  final String httpsUrl;

  /// The branch a change to the project's configuration is pushed to.
  final String defaultBranch;

  /// Whether the person is an admin of it, as the forge reports.
  final bool admin;

  /// Whether the person may push to it: a change to `project.yml` is pushed with their login.
  final bool push;

  /// Whether it is private.
  final bool private;

  /// Constructor taking every field.
  const ForgeRepository({
    required this.fullName,
    required this.sshUrl,
    required this.httpsUrl,
    required this.defaultBranch,
    required this.admin,
    required this.push,
    required this.private,
  });
}

/// A key a person signs commits with, as their forge lists it.
class ForgeSigningKey {
  /// Constructor taking what the person called it and the key.
  const ForgeSigningKey({required this.title, required this.key});

  /// What the person called it at the forge.
  final String title;

  /// The public key, `ssh-ed25519 AAAA…`.
  final String key;

  /// The key itself, without anything after it: how two are compared.
  String get keyPart => key.trim().split(RegExp(r'\s+')).take(2).join(' ');
}

/// Who a token logs in as.
class ForgeAccount {
  /// The login name.
  final String login;

  /// Constructor taking the login.
  const ForgeAccount(this.login);
}

/// Why a forge did not do what was asked, in words a person can act on.
class ForgeRefused implements Exception {
  /// Constructor taking the sentence and, where the forge gave one, its status.
  const ForgeRefused(this.words, {this.status});

  /// What was refused and why, in a sentence a person can act on.
  final String words;

  /// The forge's HTTP status, where it answered with one.
  final int? status;

  @override
  String toString() => words;
}

/// What a forge answered one request with.
typedef ForgeReply = ({int status, String body, Map<String, String> headers});

/// Sends one request to a forge. Injectable, so a test judges the rules without a network.
typedef ForgeHttp = Future<ForgeReply> Function(String method, Uri uri, Map<String, String> headers, String? body);

/// One forge, behind what making a project from a repository needs of it: who the token is, which repositories it reaches,
/// and whether one is a project already. **GitHub first; GitLab, Gitea, Forgejo
/// and Bitbucket are each one more of these later**, never a change to the flow.
abstract interface class Forge {
  /// What a person calls it: `GitHub`.
  String get name;

  /// Who the token logs in as. Refused, in words, where the token is not accepted.
  Future<ForgeAccount> whoAmI();

  /// Every repository the login reaches, as the forge lists them.
  Future<List<ForgeRepository>> repositories();

  /// Whether [repository] has a `project.yml` at the root of its default branch.
  Future<bool> hasProjectFile(ForgeRepository repository);

  /// One repository by `owner/name`, as the listing gives it: what a project's own tools start from.
  Future<ForgeRepository> repository(String fullName);

  /// The branches of [repository], by name, in the forge's order.
  Future<List<String>> branches(String repository);

  /// The fingerprints of the ssh host keys the forge publishes for itself, `SHA256:…`, read over
  /// its API: a channel other than the ssh connection a machine was offered the keys on.
  Future<List<String>> hostKeyFingerprints();

  /// The ssh keys [login] signs commits with, as the forge lists them for anybody to read: what
  /// makes a person's key theirs, rather than one of whatever their agent holds.
  Future<List<ForgeSigningKey>> signingKeys(String login);
}

/// GitHub, through its REST API, with a personal access token.
///
/// **The token is sent to GitHub and nowhere else**: in a header, over https, never in a URL, a
/// command line or a log.
class GitHub implements Forge, ForgeCollaborators {
  /// Constructor taking the token and, for a test or GitHub Enterprise, the API's address; a request
  /// over the network that is not answered within [answerWithin] is said as GitHub refusing it.
  GitHub(this._token, {Uri? api, ForgeHttp? http, Duration answerWithin = const Duration(seconds: 30)})
    : _api = api ?? Uri.parse('https://api.github.com'),
      _http = http ?? _Network(answerWithin).send;

  /// The API of the GitHub at [address]: `api.github.com` for `github.com`, `/api/v3` on a
  /// self-hosted instance.
  static Uri apiOf(String address) =>
      address == 'github.com' ? Uri.parse('https://api.github.com') : Uri.parse('https://$address/api/v3');

  final String _token;
  final Uri _api;
  final ForgeHttp _http;

  @override
  String get name => 'GitHub';

  @override
  Future<ForgeAccount> whoAmI() async {
    final user = _mapOf(await _send('GET', _at('/user')));
    return ForgeAccount('${user['login'] ?? ''}');
  }

  @override
  Future<List<ForgeRepository>> repositories() async {
    final all = <ForgeRepository>[];
    // Every page the forge has, as its Link header says; a person with many repositories sees them all.
    Uri? next = _at('/user/repos', queryParameters: <String, String>{'per_page': '100', 'sort': 'full_name'});
    while (next != null) {
      final reply = await _send('GET', next);
      for (final each in _listOf(reply)) {
        // One the forge names wrongly is left out, not the whole list.
        if (each is Map<String, dynamic> && isFullName('${each['full_name']}')) all.add(_repository(each));
      }
      next = _nextPage(reply.headers['link']);
    }
    return all;
  }

  /// Where this forge's repositories are cloned from: `github.com` for `api.github.com`, the
  /// instance's own host for `/api/v3`.
  String get _webHost => _api.host == 'api.github.com' ? 'github.com' : _api.host;

  @override
  Future<ForgeRepository> repository(String fullName) async =>
      _repository(_mapOf(await _send('GET', _at('/repos/$fullName'))));

  @override
  Future<bool> hasProjectFile(ForgeRepository repository) async {
    final reply = await _send(
      'GET',
      _at(
        '/repos/${repository.fullName}/contents/project.yml',
        queryParameters: <String, String>{'ref': repository.defaultBranch},
      ),
      allow404: true,
    );
    return reply.status == 200;
  }

  @override
  Future<List<String>> branches(String repository) async {
    final all = <String>[];
    Uri? next = _at('/repos/$repository/branches', queryParameters: <String, String>{'per_page': '100'});
    while (next != null) {
      final reply = await _send('GET', next);
      for (final each in _listOf(reply)) {
        if (each is Map<String, dynamic> && each['name'] is String) all.add(each['name'] as String);
      }
      next = _nextPage(reply.headers['link']);
    }
    return all;
  }

  @override
  Future<List<String>> hostKeyFingerprints() async {
    final meta = _mapOf(await _send('GET', _at('/meta')));
    final listed = meta['ssh_key_fingerprints'];
    return <String>[
      if (listed is Map<String, dynamic>)
        for (final each in listed.values)
          if (each is String) each.startsWith('SHA256:') ? each : 'SHA256:$each',
    ];
  }

  @override
  Future<List<ForgeSigningKey>> signingKeys(String login) async {
    final listed = _listOf(await _send('GET', _at('/users/$login/ssh_signing_keys')));
    return <ForgeSigningKey>[
      for (final each in listed.whereType<Map<String, dynamic>>())
        if (each['key'] is String) ForgeSigningKey(title: '${each['title'] ?? ''}', key: each['key'] as String),
    ];
  }

  void _checkCollaborator(String repository, [String? login]) {
    if (!isFullName(repository)) throw const ForgeRefused('Give the access repository as owner/name.');
    if (login != null) checkForgeLogin(login);
  }

  Future<ForgeReply> _collaboratorCall(
    String method,
    String repository,
    String suffix, {
    String? body,
    bool allow404 = false,
  }) async {
    try {
      final parts = suffix.split('?');
      return await _send(
        method,
        _at(
          '/repos/$repository${suffix.isEmpty ? '' : '/${parts.first}'}',
          queryParameters: parts.length == 2 ? Uri.splitQueryString(parts[1]) : null,
        ),
        body: body,
        allow404: allow404,
      );
    } on ForgeRefused catch (refused) {
      if (refused.status == 401 || refused.status == 403 || refused.status == 404) {
        throw ForgeRefused(
          'GitHub refused access management. The central token needs Administration: Read and write on the access repository $repository. Check its selected repositories and your admin access.',
          status: refused.status,
        );
      }
      // GitHub may echo submitted values; no API diagnostics enter developer settings.
      throw ForgeRefused(
        'GitHub refused access management${refused.status == null ? '' : ' (HTTP ${refused.status})'}. Check the access repository and developer login.',
        status: refused.status,
      );
    }
  }

  @override
  Future<void> checkAdministration(String repository) async {
    _checkCollaborator(repository);
    final reply = await _collaboratorCall('GET', repository, '');
    final permissions = _mapOf(reply)['permissions'];
    if (permissions is! Map || permissions['admin'] != true) {
      throw ForgeRefused(
        'The central token needs Administration: Read and write on the access repository $repository, and your account must administer it.',
      );
    }
  }

  Future<Map<String, int>> _invitations(String repository) async {
    final invitations = <String, int>{};
    var page = 1;
    while (true) {
      final reply = await _collaboratorCall('GET', repository, 'invitations?per_page=100&page=$page');
      final listed = _listOf(reply);
      for (final item in listed) {
        if (item is! Map ||
            item['id'] is! int ||
            (item['id'] as int) <= 0 ||
            item['invitee'] is! Map ||
            item['invitee']['login'] is! String) {
          throw const ForgeRefused('GitHub returned a malformed repository invitation.');
        }
        final login = item['invitee']['login'] as String;
        checkForgeLogin(login);
        if (invitations.containsKey(login.toLowerCase())) {
          throw const ForgeRefused('GitHub repeated a repository invitation page.');
        }
        invitations[login.toLowerCase()] = item['id'] as int;
      }
      if (listed.length < 100) return invitations;
      page++;
    }
  }

  @override
  Future<String> grantRead(String repository, String login) async {
    _checkCollaborator(repository, login);
    final reply = await _collaboratorCall(
      'PUT',
      repository,
      'collaborators/$login',
      body: jsonEncode({'permission': 'pull'}),
    );
    return switch (reply.status) {
      201 => 'invited',
      204 => 'can read',
      _ => throw const ForgeRefused('GitHub did not confirm read access or an invitation.'),
    };
  }

  @override
  Future<void> revokeRead(String repository, String login) async {
    _checkCollaborator(repository, login);
    final pending = await _invitations(repository);
    final invitation = pending[login.toLowerCase()];
    if (invitation != null) await _collaboratorCall('DELETE', repository, 'invitations/$invitation');
    await _collaboratorCall('DELETE', repository, 'collaborators/$login');
  }

  @override
  Future<Map<String, String>> readAccess(String repository, Iterable<String> logins) async {
    _checkCollaborator(repository);
    final pending = await _invitations(repository);
    final states = <String, String>{};
    for (final login in logins.toSet()) {
      _checkCollaborator(repository, login);
      if (pending.containsKey(login.toLowerCase())) {
        states[login] = 'invited';
        continue;
      }
      final reply = await _collaboratorCall('GET', repository, 'collaborators/$login/permission', allow404: true);
      if (reply.status == 404) {
        states[login] = 'no read access';
        continue;
      }
      final permission = _mapOf(reply)['permission'];
      if (permission is! String) throw const ForgeRefused('GitHub did not report repository permission.');
      states[login] = switch (permission) {
        'read' || 'triage' || 'write' || 'maintain' || 'admin' => 'can read',
        'none' => 'no read access',
        _ => 'unknown permission',
      };
    }
    return states;
  }

  /// Whether [fullName] is `owner/name` and nothing else: it becomes a folder here and a path on
  /// the forge, so `..`, a slash too many or a character outside GitHub's names is never one.
  static bool isFullName(String fullName) {
    final parts = fullName.split('/');
    return parts.length == 2 &&
        parts.every((part) => RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(part) && part != '.' && part != '..');
  }

  /// A repository as the forge answered it. **Where it is cloned from is made here**, from its
  /// checked name and this forge's own host, never taken from the answer: a forge that answered
  /// another host would have the token sent there with the clone.
  ForgeRepository _repository(Map<String, dynamic> map) {
    final permissions = map['permissions'];
    bool may(String what) => permissions is Map<String, dynamic> && permissions[what] == true;
    final fullName = '${map['full_name'] ?? ''}';
    if (!isFullName(fullName)) throw ForgeRefused('GitHub answered "$fullName", which is not a repository name.');
    return ForgeRepository(
      fullName: fullName,
      sshUrl: 'git@$_webHost:$fullName.git',
      httpsUrl: 'https://$_webHost/$fullName.git',
      defaultBranch: '${map['default_branch'] ?? 'main'}',
      admin: may('admin'),
      push: may('push'),
      private: map['private'] == true,
    );
  }

  /// The next page from a `Link` header, or null on the last. **Only a page of this forge's own
  /// API is followed**, since the token goes with it: one anywhere else is refused.
  Uri? _nextPage(String? link) {
    if (link == null) return null;
    for (final part in link.split(',')) {
      final match = RegExp(r'<([^>]+)>;\s*rel="next"').firstMatch(part);
      if (match == null) continue;
      final next = Uri.tryParse(match.group(1)!);
      if (next == null ||
          next.scheme != _api.scheme ||
          next.host != _api.host ||
          next.port != _api.port ||
          !next.path.startsWith(_api.path)) {
        throw ForgeRefused(
          'GitHub pointed its next page at ${next?.host ?? 'an address it did not write out'}, '
          'which is not its own; the token is not sent there.',
        );
      }
      return next;
    }
    return null;
  }

  /// [path] under this forge's API, never in place of it: a GitHub of its own keeps its API under
  /// `/api/v3`, which a bare replace would drop.
  Uri _at(String path, {Map<String, String>? queryParameters}) =>
      _api.replace(path: '${_api.path}$path', queryParameters: queryParameters);

  /// [reply]'s body as the list a call reads, or GitHub refusing it: a proxy's page, or JSON of another
  /// shape, is said rather than thrown past every form that asked.
  static List<dynamic> _listOf(ForgeReply reply) => switch (_decoded(reply)) {
    final List<dynamic> list => list,
    _ => throw ForgeRefused('GitHub answered with something other than the list this asks for.'),
  };

  /// [reply]'s body as the object a call reads, or GitHub refusing it.
  static Map<String, dynamic> _mapOf(ForgeReply reply) => switch (_decoded(reply)) {
    final Map<String, dynamic> map => map,
    _ => throw ForgeRefused('GitHub answered with something other than the object this asks for.'),
  };

  static Object? _decoded(ForgeReply reply) {
    try {
      return jsonDecode(reply.body);
    } on FormatException {
      throw ForgeRefused(
        'GitHub answered with a page that is not its API, as a proxy or a network sign-in does.',
        status: reply.status,
      );
    }
  }

  Future<ForgeReply> _send(String method, Uri uri, {bool allow404 = false, String? body}) async {
    final ForgeReply reply;
    try {
      reply = await _http(method, uri, <String, String>{
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'porelo-frontend',
        if (body != null) 'Content-Type': 'application/json',
      }, body);
    } on SocketException catch (ex) {
      throw ForgeRefused('GitHub could not be reached: ${ex.message}');
    } on IOException catch (ex) {
      // A TLS handshake refused, or an exchange broken off: no answer of GitHub's either.
      throw ForgeRefused('GitHub could not be asked: $ex');
    }
    if (reply.status >= 200 && reply.status < 300) return reply;
    if (allow404 && reply.status == 404) return reply;
    throw ForgeRefused(_why(reply, uri), status: reply.status);
  }

  /// GitHub's own sentence, under ours: what the status means for the person.
  static String _why(ForgeReply reply, [Uri? uri]) {
    String said = '';
    try {
      final body = jsonDecode(reply.body);
      if (body is Map<String, dynamic> && body['message'] is String) said = body['message'] as String;
      // "Validation Failed" alone says nothing a person can act on; the reason is in `errors`, such
      // as "key is already in use" (a deploy key refused on GitHub).
      if (body is Map<String, dynamic> && body['errors'] is List) {
        final details = <String>[
          for (final each in body['errors'] as List<dynamic>)
            if (each is Map<String, dynamic>)
              <Object?>[each['message'], each['field'], each['code']].whereType<String>().join(' '),
        ].where((each) => each.isNotEmpty).toList();
        if (details.isNotEmpty) said = '$said: ${details.join('; ')}';
      }
    } on FormatException {
      // Not JSON: nothing of GitHub's to quote.
    }
    final ours = switch (reply.status) {
      401 => 'GitHub does not accept this token: it is wrong, expired or revoked.',
      403 => 'GitHub refused it: the token lacks a right this needs, or a limit was reached.',
      404 => 'GitHub has nothing there this token can see.',
      // Among others: the same key on a second repository, which GitHub refuses.
      422 => 'GitHub refused it as it stands.',
      _ => 'GitHub answered ${reply.status}.',
    };
    // What to change, and where, where GitHub's answer says enough to know it.
    final repository = RegExp(r'^/repos/([^/]+/[^/]+)').firstMatch(uri?.path ?? '')?.group(1);
    final what = repository == null ? '' : ' for $repository';
    if (reply.status == 403 && said.contains('not accessible by personal access token')) {
      final path = uri?.path ?? '';
      final right = path.contains('/contents') || path.contains('/git/') ? 'Contents: Read and write' : null;
      if (right != null) {
        return 'This token lacks $right$what. Give it that at GitHub → Settings → Developer settings → '
            'Fine-grained tokens → this token → Repository permissions, with$what among its '
            'repositories. ($said)';
      }
    }
    return said.isEmpty ? ours : '$ours ($said)';
  }
}

/// The forge over the network, with connections kept open and reused between requests: one per
/// token's forge. Asking about fifty repositories one handshake at a time took a
/// minute or two.
///
/// **Every request ends within [_within]**, connecting and answering together: a forge that accepts
/// and then says nothing would otherwise hold the form that asked for good.
class _Network {
  _Network(this._within);

  final Duration _within;
  HttpClient? _client;

  Future<ForgeReply> send(String method, Uri uri, Map<String, String> headers, String? body) async {
    final client = _client ??= HttpClient()
      ..idleTimeout = const Duration(seconds: 30)
      ..connectionTimeout = _within;
    HttpClientRequest? request;
    try {
      return await () async {
        request = await client.openUrl(method, uri);
        headers.forEach(request!.headers.set);
        if (body != null) request!.write(body);
        final response = await request!.close();
        final text = await response.transform(utf8.decoder).join();
        final seen = <String, String>{};
        response.headers.forEach((name, values) => seen[name.toLowerCase()] = values.join(', '));
        return (status: response.statusCode, body: text, headers: seen);
      }().timeout(_within);
    } on TimeoutException {
      request?.abort();
      throw ForgeRefused('GitHub did not answer within ${_within.inSeconds} seconds.');
    }
  }
}

/// The person's own forge token for API calls, kept in this computer's system secret store.
/// Machines receive their own vault entry only through a terminal prompt there.
abstract interface class ForgeTokens {
  /// The token for [forge] (`github.com`), or null when none is kept.
  Future<String?> read(String forge);

  /// Keeps [token] for [forge], replacing any before it.
  Future<void> write(String forge, String token);

  /// Forgets the token for [forge].
  Future<void> delete(String forge);
}

/// Tokens in the same system store and entry used by `porelo-host key set <host>`.
class PlatformForgeTokens implements ForgeTokens {
  /// Constructor using the system store, or a stand-in for a test.
  PlatformForgeTokens({SecretStore Function()? store}) : _store = store ?? SecretStore.forThisSystem;

  final SecretStore Function() _store;

  Future<T> _using<T>(Future<T> Function(SecretStore) call) async {
    try {
      final store = _store();
      try {
        return await call(store);
      } finally {
        await store.close();
      }
    } on Exception {
      throw const ForgeRefused('This computer’s system secret store could not be used.');
    }
  }

  @override
  Future<String?> read(String forge) => _using((store) => store.read(providerKeyName(forgeAddress(forge))));

  @override
  Future<void> write(String forge, String token) =>
      _using((store) => store.write(providerKeyName(forgeAddress(forge)), token));

  @override
  Future<void> delete(String forge) => _using((store) => store.remove(providerKeyName(forgeAddress(forge))));
}

/// Tokens in memory only, for tests.
class MemoryForgeTokens implements ForgeTokens {
  final Map<String, String> _tokens = <String, String>{};

  @override
  Future<String?> read(String forge) async => _tokens[forge];

  @override
  Future<void> write(String forge, String token) async => _tokens[forge] = token;

  @override
  Future<void> delete(String forge) async => _tokens.remove(forge);
}
