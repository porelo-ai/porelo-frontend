import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What a stand-in planner on the loopback address does to be taken for this account's planner, in the forms the
/// planner's REST description gives: it answers `POST /proof` for its token and port, takes a request only when its
/// `porelo-signature` holds under the token and it carries no `Authorization`, and proves each answer in
/// `porelo-answer`, as the planner's access filter does.
///
/// Built here from those forms, not from the planning package's own code, so a window call the package does not sign
/// as the planner checks is refused here too.
class SignedPlanner {
  /// Proves, checks and signs under [token].
  SignedPlanner(this.token);

  /// The token it proves and checks under, as its address file names it; never sent by a caller.
  String token;

  /// Whether it answers the proof as a stranger on the port would: under another token.
  bool stranger = false;

  /// Whether it refuses every request with 401, a signed one too, as for a clock far off.
  bool refuse = false;

  /// The proofs it was asked for.
  int proofs = 0;

  /// Every request but a proof that reached it: its method, its path and its `Authorization` header.
  final requests = <(String, String, String?)>[];

  /// Serves [request]: a proof is answered here; any other request is recorded, refused with 401 unless its signature
  /// holds, and otherwise answered with the status and JSON text [answer] gives for its method, path and body, proven.
  Future<void> serve(
    HttpRequest request,
    Future<(int, String)> Function(String method, String path, String body) answer,
  ) async {
    final body = [for (final chunk in await request.toList()) ...chunk];
    final response = request.response;
    if (request.method == 'POST' && request.uri.path == '/proof') {
      proofs++;
      final challenge = _decode((jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['challenge'] as String);
      final port = request.connectionInfo!.localPort;
      final form = _labeled('porelo-planner-proof-1')
        ..add([port >> 8 & 0xff, port & 0xff])
        ..add(challenge);
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({'proof': _base64(_mac(stranger ? 'x$token' : token, form.takeBytes()))}));
      await response.close();
      return;
    }
    requests.add((request.method, request.uri.path, request.headers.value(HttpHeaders.authorizationHeader)));
    final nonce = _verified(request, body);
    if (nonce == null || refuse) {
      response.statusCode = HttpStatus.unauthorized;
      await response.close();
      return;
    }
    final (status, text) = await answer(request.method, request.uri.path, utf8.decode(body));
    final bytes = utf8.encode(text);
    final form = _labeled('porelo-planner-answer-1')
      ..add(_field(nonce))
      ..add(_field(ascii.encode('$status')))
      ..add(_field(sha256.convert(bytes).bytes));
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set('porelo-answer', 'porelo-planner-answer-1;s=${_base64(_mac(token, form.takeBytes()))}')
      ..add(bytes);
    await response.close();
  }

  /// The nonce of [request] when its one signature holds for it and [body] under the token and it carries no
  /// `Authorization`, else null.
  List<int>? _verified(HttpRequest request, List<int> body) {
    final header = request.headers['porelo-signature'];
    if (header == null || header.length != 1 || request.headers.value(HttpHeaders.authorizationHeader) != null) {
      return null;
    }
    final parts = RegExp(r'^porelo-planner-request-1;t=([0-9]+);n=([A-Za-z0-9_-]{22});s=([A-Za-z0-9_-]{43})$')
        .firstMatch(header.single);
    if (parts == null) return null;
    final nonce = _decode(parts.group(2)!);
    final form = _labeled('porelo-planner-request-1')
      ..add(_field(ascii.encode(request.method)))
      ..add(_field(utf8.encode(request.uri.toString())))
      ..add(_field(utf8.encode(request.headers.value(HttpHeaders.hostHeader) ?? '')))
      ..add(_field(utf8.encode(request.headers.value(HttpHeaders.contentTypeHeader) ?? '')))
      ..add(_field(sha256.convert(body).bytes))
      ..add(_field(ascii.encode(parts.group(1)!)))
      ..add(_field(nonce));
    return _base64(_mac(token, form.takeBytes())) == parts.group(3) ? nonce : null;
  }

  static List<int> _mac(String token, List<int> message) => Hmac(sha256, utf8.encode(token)).convert(message).bytes;

  static String _base64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _decode(String text) => base64Url.decode(base64Url.normalize(text));

  static BytesBuilder _labeled(String label) => BytesBuilder(copy: false)
    ..add(ascii.encode(label))
    ..addByte(0);

  static List<int> _field(List<int> bytes) {
    final length = bytes.length;
    return [length >> 24 & 0xff, length >> 16 & 0xff, length >> 8 & 0xff, length & 0xff, ...bytes];
  }
}
