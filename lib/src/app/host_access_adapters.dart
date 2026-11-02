import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'host_access.dart';
import 'identity.dart';
import 'run_here.dart';

/// Core's proven identity for host administration: the card kept here, while its key is usable now.
///
/// Usable means what `identity show --json` answers: the key not revoked, the card verified (`card_refused` null) and
/// the agent holding the key. Otherwise nobody is proven, and [whyNone] says why.
class CoreHostAdminProof extends ChangeNotifier implements HostAdminProof {
  /// Constructor taking Core's identity verbs, or a process runner for them.
  CoreHostAdminProof({Identity? identity, RunHere? run}) : _identity = identity ?? Identity(run: run);

  final Identity _identity;
  HostAdminIdentity? _current;
  String _why = 'Your identity has not been read yet.';

  // Only the newest read is kept: an older one that ends later never brings back a key since taken away.
  int _generation = 0;

  /// The proven login and card key fingerprint as last read, or null.
  HostAdminIdentity? current() => _current;

  @override
  String? get whyNone => _current == null ? _why : null;

  @override
  Future<void> readAgain() async {
    final read = ++_generation;
    HostAdminIdentity? proven;
    String why;
    try {
      final card = await _identity.show();
      why = card.whyKeyUnusable ?? '';
      if (why.isEmpty) proven = HostAdminIdentity(card.login, card.fingerprint, card.key);
    } on NoIdentity catch (none) {
      why = none.words;
    } on IdentityRefused catch (refused) {
      why = refused.words;
    } on Exception {
      why = "Porelo's answer on your identity could not be read. Try again.";
    }
    if (read != _generation) return;
    _current = proven;
    if (proven == null) _why = why;
    notifyListeners();
  }
}
