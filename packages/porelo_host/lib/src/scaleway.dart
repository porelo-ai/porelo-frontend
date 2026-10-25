import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'host_run.dart' show hostKeyTag;
import 'provider.dart';
import 'steps.dart';

/// One answer of Scaleway's API: its status and its JSON body.
class ApiAnswer {
  /// Constructor taking the status and the body.
  const ApiAnswer(this.status, this.body);

  /// The HTTP status.
  final int status;

  /// The decoded JSON body, raw text for a non-JSON answer, or null for none.
  final Object? body;
}

/// Sends one request to Scaleway's API. A seam, so the adapter is proven against recorded answers.
typedef ScalewayApi = Future<ApiAnswer> Function(String method, String path, {Map<String, Object?>? body});

/// Checks a secret before storing or using it, without creating any provider resources.
Future<({int code, String message})> checkScalewayKey(
  String value, {
  ScalewayApi Function(String) exchange = scalewayOverHttps,
}) async {
  final key = value.trim();
  if (key.startsWith('SCW')) {
    return (code: Exit.refused, message: 'that is the access key (SCW…); the secret key is a UUID');
  }
  final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  if (!uuid.hasMatch(key)) {
    return (code: Exit.refused, message: 'that is not a secret key; the secret key is a UUID');
  }
  try {
    final answer = await exchange(key)(
      'GET',
      '/baremetal/v1/zones/fr-par-1/offers?name=EM-I220E-NVME',
    ).timeout(const Duration(seconds: 30));
    if (answer.status >= 200 && answer.status < 300) {
      if (answer.body is! Map) {
        return (
          code: Exit.refused,
          message: 'that is not Scaleway’s answer; the offers response must be a JSON object',
        );
      }
      return (code: Exit.done, message: 'accepted');
    }
    if (answer.status >= 500) {
      return (code: Exit.unreachable, message: 'Scaleway is unavailable (HTTP ${answer.status})');
    }
    final said = switch (answer.body) {
      {'message': final String message} => message,
      final String message => message,
      _ => 'HTTP ${answer.status}',
    };
    // A remote error can echo the authentication header, so it is never trusted with the secret.
    return (code: Exit.refused, message: 'refused by Scaleway: ${said.replaceAll(key, '[redacted]')}');
  } on Exception {
    return (code: Exit.unreachable, message: 'Scaleway could not be reached');
  }
}

/// The real API over HTTPS, with the key in `X-Auth-Token` and nowhere else.
ScalewayApi scalewayOverHttps(String secretKey, {String base = 'https://api.scaleway.com'}) {
  final client = HttpClient();
  return (method, path, {body}) async {
    try {
      final request = await client.openUrl(method, Uri.parse('$base$path'));
      // A key check must make one request and must not forward its credential to another host.
      request.followRedirects = false;
      request.headers.set('X-Auth-Token', secretKey);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      Object? decoded;
      try {
        decoded = text.isEmpty ? null : jsonDecode(text);
      } on FormatException {
        decoded = text;
      }
      return ApiAnswer(response.statusCode, decoded);
    } on IOException {
      throw const ProviderFailed('Scaleway\'s API could not be reached');
    } on FormatException {
      throw const ProviderFailed('Scaleway answered with something that is not JSON');
    }
  };
}

/// A host rented from Scaleway Elastic Metal: the offer and the system as named, in one zone of one project.
///
/// **A server it did not tag is never given back**: [release] reads the server's tags first.
class ScalewayElasticMetal implements HostProvider {
  /// Constructor taking the API, where to rent and what.
  ScalewayElasticMetal({
    required this.api,
    required this.projectId,
    this.zone = 'fr-par-1',
    this.offer = 'EM-I220E-NVME',
    this.system = 'Ubuntu',
    this.systemVersion = '26.04',
  });

  /// The API the requests go to.
  final ScalewayApi api;

  /// The Scaleway project the host is rented in.
  final String projectId;

  /// The zone, `fr-par-1` first.
  final String zone;

  /// The offer's name.
  final String offer;

  /// The system's name and version, as Scaleway lists them.
  final String system;

  /// The system's version.
  final String systemVersion;

  String get _servers => '/baremetal/v1/zones/$zone/servers';

  @override
  Future<RentedHost?> find(String tag) async {
    final listed = await _ok(
      'GET',
      '$_servers?project_id=$projectId&tags=${Uri.encodeQueryComponent(tag)}',
      'list the servers',
    );
    final servers = ((listed as Map)['servers'] as List).cast<Map<String, Object?>>();
    final live = servers.where((s) => (s['tags'] as List).contains(tag) && s['status'] != 'deleting').toList();
    return live.isEmpty ? null : _host(live.first);
  }

  @override
  Future<RentedHost> create(HostRequest request) async {
    // The person's key first: a missing one is the person's to fix, and nothing is rented before it.
    final keyId = await _sshKeyId(request.sshPublicKey, request.name);
    final offerId = await _offerId();
    final osId = await _osId();
    final made = await _ok(
      'POST',
      _servers,
      'rent a server',
      body: <String, Object?>{
        'offer_id': offerId,
        'project_id': projectId,
        'name': request.name,
        'description': 'Porelo host of ${request.name}',
        'tags': request.tags,
        'install': <String, Object?>{
          'os_id': osId,
          'hostname': request.name,
          'ssh_key_ids': <String>[keyId],
        },
        if (request.userData != null) 'user_data': base64.encode(utf8.encode(request.userData!)),
      },
    );
    return _host(made as Map<String, Object?>);
  }

  @override
  Future<RentedHost> state(String id) async =>
      _host(await _ok('GET', '$_servers/$id', 'read $id') as Map<String, Object?>);

  @override
  Future<void> release(String id) async {
    final server = await _ok('GET', '$_servers/$id', 'read $id') as Map<String, Object?>;
    final tags = (server['tags'] as List).cast<String>();
    if (!tags.any((t) => t.startsWith('porelo-project='))) {
      throw ProviderFailed('$id carries no porelo-project tag, so it is not this package\'s to give back');
    }
    // A successful deletion has no JSON body to validate.
    await _request('DELETE', '$_servers/$id', 'give back $id');
  }

  /// A host as the API describes it. The host key is never the API's: it is the one the request
  /// made, read back from the tag it was put in.
  RentedHost _host(Map<String, Object?> server) {
    final keyTag = (server['tags'] as List).cast<String>().where((t) => t.startsWith(hostKeyTag)).firstOrNull;
    final install = server['install'] as Map<String, Object?>?;
    final ips = ((server['ips'] as List?) ?? const <Object?>[]).cast<Map<String, Object?>>();
    final v4 = ips.where((ip) => ip['version'] == 'IPv4').map((ip) => ip['address'] as String).firstOrNull;
    final ready = server['status'] == 'ready' && install?['status'] == 'completed';
    final hostKey = keyTag == null ? null : 'ssh-ed25519 ${keyTag.substring(hostKeyTag.length)}';
    return RentedHost(id: server['id'] as String, address: v4, hostKey: hostKey, ready: ready);
  }

  Future<String> _offerId() async {
    final listed = await _ok(
      'GET',
      '/baremetal/v1/zones/$zone/offers?name=${Uri.encodeQueryComponent(offer)}',
      'list the offers',
    );
    final offers = ((listed as Map)['offers'] as List).cast<Map<String, Object?>>().where((o) => o['name'] == offer);
    if (offers.isEmpty) throw ProviderFailed('$zone offers no $offer');
    final it = offers.first;
    if (it['stock'] == 'empty') throw ProviderFailed('$offer is out of stock in $zone');
    return it['id'] as String;
  }

  Future<String> _osId() async {
    final listed = await _ok('GET', '/baremetal/v1/zones/$zone/os?offer_id=${await _offerId()}', 'list the systems');
    final systems = ((listed as Map)['os'] as List).cast<Map<String, Object?>>().where(
      // Scaleway names a version with its release's name after it: `26.04 LTS (Resolute Raccoon)`.
      (s) => s['name'] == system && _isVersion(s['version'] as String? ?? '') && s['enabled'] != false,
    );
    if (systems.isEmpty) throw ProviderFailed('$zone installs no $system $systemVersion on $offer');
    return systems.first['id'] as String;
  }

  /// Whether Scaleway's [named] version is [systemVersion]: the same, or it followed by a space and
  /// its release's name, never a longer number that begins the same.
  bool _isVersion(String named) => named == systemVersion || named.startsWith('$systemVersion ');

  /// The project's ssh key for [publicKey]. **Registered by the person, never by this package**: the
  /// key it is given may read the project's ssh keys, not add one, so a missing key ends the rent
  /// before anything is rented, saying what to register and where.
  Future<String> _sshKeyId(String publicKey, String name) async {
    final listed = await _ok('GET', '/iam/v1alpha1/ssh-keys?project_id=$projectId&page_size=100', 'list the ssh keys');
    final keys = ((listed as Map)['ssh_keys'] as List).cast<Map<String, Object?>>();
    final wanted = publicKey.split(' ').take(2).join(' ');
    for (final key in keys) {
      if ((key['public_key'] as String).split(' ').take(2).join(' ') == wanted) return key['id'] as String;
    }
    throw ProviderFailed(
      'your public ssh key is not in the Scaleway project $projectId: add it once in the console, '
      'under Project dashboard → SSH keys → Add SSH key, pasting this line: $wanted',
    );
  }

  Future<Object?> _ok(String method, String path, String what, {Map<String, Object?>? body}) async {
    final answer = await _request(method, path, what, body: body);
    if (answer.body is! Map && answer.body is! List) {
      throw const ProviderFailed('Scaleway answered with something that is not JSON');
    }
    return answer.body;
  }

  Future<ApiAnswer> _request(String method, String path, String what, {Map<String, Object?>? body}) async {
    final answer = await api(method, path, body: body);
    if (answer.status >= 200 && answer.status < 300) return answer;
    final said = answer.body is Map ? ((answer.body as Map)['message'] ?? answer.body) : answer.body;
    final reason = switch (answer.status) {
      401 || 403 => 'the key may not $what: $said',
      _ => 'Scaleway refused to $what (${answer.status}): $said',
    };
    throw ProviderFailed(reason);
  }
}
