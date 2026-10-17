import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'login_forward.dart';
import 'machines.dart';

/// One authorization being granted, once, for the account's later tasks.
///
/// **The interface only listens.** The decision is made in a browser, possibly on another device,
/// and the machine hears the answer from the service; what arrives here is where it stands. So
/// nothing here says it is doing the work, and the link is kept exactly as it came.
class Granting extends ChangeNotifier {
  /// Constructor taking the machine, where it is reached, and the vault entry naming the service.
  Granting(this._backend, this.machine, this.entry);

  final FleetBackend _backend;

  /// The machine whose vault keeps the grant, and where a redirect's answer comes back to.
  final Machine machine;

  /// The vault entry that names the service.
  final String entry;

  /// `needed`, `granted`, `refused`, `expired` or `failed`, or empty before the machine answered.
  String state = '';

  /// The page to decide on, whole, as the machine sent it.
  String link = '';

  /// For a device code, what to type if the page does not carry it.
  String code = '';

  /// For a redirect, the loopback port on the machine the answer comes back to; 0 for a device code.
  int port = 0;

  /// When the question expires, by this computer's clock, or null when the machine did not say.
  DateTime? expiresAt;

  /// Why it failed, in the machine's words.
  String detail = '';

  /// Why nothing could be asked or heard, or null.
  String? problem;

  /// Why a redirect's answer could not be forwarded, or null.
  String? forwardProblem;

  /// Whether a redirect's answer can reach the machine: forwarded here, or not needing it.
  bool forwarded = false;

  StreamSubscription<AuthorizeProgress>? _listening;
  HeldForward? _forward;
  bool _gone = false;

  /// Whether the question is still open.
  bool get waiting => state == 'needed';

  /// Whether it is settled, one way or the other.
  bool get settled => state.isNotEmpty && state != 'needed';

  /// The link as an address to open, or null when it is not a web address: only http and https are
  /// ever opened here, whatever the text says.
  Uri? get address {
    final parsed = Uri.tryParse(link);
    return parsed != null && (parsed.isScheme('https') || parsed.isScheme('http')) && parsed.host.isNotEmpty
        ? parsed
        : null;
  }

  /// Whether the link can be opened now: a web address, and for a redirect the answer's way back
  /// is in place first, or the browser would be sent to a port nothing listens on.
  bool get canOpen => waiting && address != null && (port == 0 || forwarded);

  /// Asks the machine, and listens until it is settled.
  void start() {
    _listening = _backend
        .authorize(entry)
        .listen(
          _heard,
          onError: (Object error) {
            problem = switch (error) {
              FeatureNotSupported() => 'This machine cannot grant an authorization.',
              // Not only a refusal: a service the machine cannot reach answers the same way.
              VarlinkException(:final simpleName, :final parameters) =>
                'It could not be asked for: ${parameters['message'] ?? parameters['detail'] ?? simpleName}',
              VarlinkDisconnected(:final message) => 'Lost contact with the machine: $message',
              _ => '$error',
            };
            unawaited(_closeTheForward());
            _notify();
          },
        );
  }

  void _heard(AuthorizeProgress progress) {
    state = progress.state;
    if (progress.state == 'needed') {
      link = progress.link;
      code = progress.code;
      if (progress.expiresIn > 0) expiresAt = DateTime.now().add(Duration(seconds: progress.expiresIn));
      if (progress.port != port) {
        port = progress.port;
        if (port > 0) unawaited(_forwardTheAnswer());
      }
    } else {
      detail = progress.detail;
      unawaited(_closeTheForward());
    }
    _notify();
  }

  /// A redirect answers to a port on the machine's loopback; a browser here reaches it only
  /// through a forward of the same port, raised before the link is offered.
  Future<void> _forwardTheAnswer() async {
    // One port, never a privileged one: the answer, nothing else.
    if (port < 1024 || port > 65535) {
      forwardProblem = 'The machine named port $port for the answer, which is not one to forward.';
      _notify();
      return;
    }
    try {
      final held = await raiseForward(machine, port);
      if (_gone || settled) {
        await held.close();
        return;
      }
      _forward = held;
      forwarded = true;
    } on ForwardRefused catch (refused) {
      forwardProblem = refused.words;
    }
    _notify();
  }

  Future<void> _closeTheForward() async {
    final held = _forward;
    _forward = null;
    forwarded = false;
    await held?.close();
  }

  /// Opens the link in this desktop's browser.
  Future<void> open(Future<void> Function(Uri address) opener) async {
    final where = address;
    if (canOpen && where != null) await opener(where);
  }

  void _notify() {
    if (!_gone) notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    unawaited(_listening?.cancel());
    unawaited(_closeTheForward());
    super.dispose();
  }
}
