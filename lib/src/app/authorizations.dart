import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// What a person has to authorize on one machine before work can use it, as the machine streams it.
///
/// **One question per credential**, however many starts were refused for it: the machine raises it
/// once until a grant lands, and a grant (`granted`) takes it away, whoever answered it.
class Authorizations extends ChangeNotifier {
  final Map<String, AuthorizationNeeded> _open = <String, AuthorizationNeeded>{};
  StreamSubscription<AuthorizationNeeded>? _listening;
  bool _disposed = false;

  /// Whether this machine can say at all. False for one older than the stream: said as nothing
  /// asked, never as nothing needed.
  bool supported = true;

  /// What is open now, oldest first.
  List<AuthorizationNeeded> get open =>
      _open.values.toList()..sort((a, b) => a.at.compareTo(b.at));

  /// Starts watching. Safe to call again; it replaces what was watching before.
  void watch(FleetBackend backend) {
    _listening?.cancel();
    _open.clear();
    supported = true;
    _listening = backend.authorizations().listen(
      (event) {
        if (event.state == 'granted') {
          _open.remove(event.credential);
        } else {
          _open[event.credential] = event;
        }
        _notify();
      },
      onError: (Object error) {
        // An older machine has no stream; a lost one comes back with the machine.
        if (error is FeatureNotSupported) supported = false;
        _notify();
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _listening?.cancel();
    super.dispose();
  }
}
