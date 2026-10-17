import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'device_key.dart';
import 'fleet_backend.dart';
import 'vault_devices.dart';

/// What the vault's button in the machine's title does right now.
enum VaultAct {
  /// Adds this device to the machine's vault, so it can open it from here.
  enroll,

  /// Opens the vault with this device's key.
  open,

  /// Shuts it.
  shut,
}

/// The vault: what it holds, by name, and the shutting of it.
///
/// **Never a value.** `Credentials` answers names, kinds and lengths and nothing else, and that is
/// the whole promise of the method — on a socket that can be forwarded over ssh. Nothing here
/// asks for more, and nothing here is put where an operation record or a log could keep it.
///
/// Half of what this requirement asks for happens **at the machine** rather than here, and that is
/// a decision rather than a gap: a daemon has no terminal to take a passphrase at, so it can shut
/// the store and can never open it. The screen says where, which is a different sentence from
/// *this cannot be done*.
class Vault extends ChangeNotifier {
  /// Constructor taking where this device keeps the keys that open a vault.
  Vault({required DeviceKeyStore keys}) : devices = VaultDevices(keys);

  /// The devices that open it, this one among them.
  final VaultDevices devices;

  /// What the store says about itself, or null before it has been asked.
  VaultState? state;

  /// What the last lock did, or null.
  Locked? shut;

  /// Which machine [state] and [devices] describe, by name; empty before any was asked.
  String about = '';

  /// Whether it is being asked right now.
  bool busy = false;

  /// Why it could not be read or shut, in words.
  String? problem;

  /// Which question is outstanding.
  ///
  /// **Two parts of the interface asking at once must never leave a stale answer over a newer
  /// one.** Answers can arrive in any order, so each is stamped with the question it belongs to
  /// and an older one is dropped rather than drawn.
  int _asked = 0;

  /// Whether the list of names can be believed.
  ///
  /// A locked store and an empty one both answer with no names, and an interface must not show
  /// them the same way. Corrected on the Porelo side: an unlocked, empty store now
  /// answers `readable: true`.
  bool get readable => state?.readable ?? false;

  /// Whether the machine has said it has no store at all — one to make, not one to open.
  bool get missing => state != null && !state!.exists;

  /// What the store holds, by name.
  List<Credential> get credentials => state?.credentials ?? const <Credential>[];

  /// What the lock in the machine's title does when pressed: shuts an open store, opens a shut one.
  VaultAct get lockDoes => (state?.readable ?? false) ? VaultAct.shut : VaultAct.open;

  /// Whether the lock can do it now.
  bool get lockWorks => whyNot(lockDoes) == null;

  /// What the lock says about the store, and why it does nothing when it does nothing.
  String get lockSays {
    final state = this.state;
    if (state == null) return problem ?? 'Asking the machine about its vault…';
    if (!state.exists) return 'There is no vault on this machine yet.';
    if (state.readable) return 'The vault is open. Shut it.';
    if (devices.enrolledHere) return 'The vault is shut. Open it with this device.';
    return devices.canEnroll
        ? 'The vault is shut, and this device is not enrolled. Unlock it at the machine with '
            '`porelo vault unlock`, then enroll this device.'
        : 'The vault is shut. Unlock it at the machine with `porelo vault unlock`.';
  }

  /// Whether enrolling is offered beside the lock: **only while this device is not enrolled** on a
  /// machine that knows devices, and then it stays there, because until it is done the lock cannot
  /// open the store from here.
  bool get offersEnrolling => devices.canEnroll && !devices.enrolledHere;

  /// What enrolling says, and why it cannot happen yet when it cannot.
  String get enrollSays => whyNot(VaultAct.enroll) == null
      ? 'This device cannot open the vault yet. Enroll it so it can.'
      : 'Enrolling needs the vault open. Unlock it at the machine with `porelo vault unlock` first.';

  /// Why [what] cannot be done now, or null when it can.
  String? whyNot(VaultAct what) {
    final state = this.state;
    if (state == null) return problem ?? 'the machine has not said yet';
    if (!state.exists) return 'there is no vault on this machine yet';
    return switch (what) {
      VaultAct.enroll => !devices.canEnroll
          ? devices.problem ?? 'this machine has not said whether it can'
          : devices.enrolledHere
              ? 'this device is enrolled already'
              : !state.readable
                  ? 'the vault is shut, and a device is enrolled into an open one'
                  : null,
      VaultAct.open => !devices.enrolledHere
          ? 'this device is not enrolled on this machine'
          : state.readable
              ? 'it is open already'
              : null,
      VaultAct.shut => state.readable ? null : 'it is shut already',
    };
  }

  /// Reads the store and its devices for the machine called [machine].
  ///
  /// **Another machine's answer is forgotten first**, so the button never shows one machine's
  /// store on another machine's title while the new answer is on its way.
  Future<void> lookAt(FleetBackend backend, String machine) async {
    if (machine != about) {
      about = machine;
      state = null;
      shut = null;
      devices.forget();
    }
    await Future.wait(<Future<void>>[look(backend), devices.look(backend)]);
  }

  /// Reads what the store says about itself.
  Future<void> look(FleetBackend backend) async {
    final mine = ++_asked;
    busy = true;
    problem = null;
    notifyListeners();
    try {
      final answer = await backend.credentials();
      if (mine != _asked) return;
      state = answer;
    } on VarlinkException catch (refusal) {
      if (mine != _asked) return;
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      if (mine != _asked) return;
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      if (mine != _asked) return;
      problem = '$ex';
    } finally {
      if (mine == _asked) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Shuts the store, and reads it again so what is on screen is what is true.
  Future<void> lock(FleetBackend backend) async {
    final mine = ++_asked;
    busy = true;
    problem = null;
    notifyListeners();
    try {
      final answer = await backend.lock();
      if (mine != _asked) return;
      shut = answer;
      state = await backend.credentials();
    } on VarlinkException catch (refusal) {
      if (mine != _asked) return;
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      if (mine != _asked) return;
      problem = 'Lost contact with the machine: ${ex.message}. The vault may or may not be shut.';
    } on FeatureNotSupported catch (ex) {
      if (mine != _asked) return;
      problem = '$ex';
    } finally {
      if (mine == _asked) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Puts the result of a lock away.
  void letItBe() {
    shut = null;
    notifyListeners();
  }
}
