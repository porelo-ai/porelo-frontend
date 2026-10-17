import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'device_key.dart';
import 'fleet_backend.dart';

/// The devices that open a machine's vault, and this device among them: Porelo's keyslots.
///
/// **Built against the keyslots' proposal**, which is not on `Tasks1` yet; until it is, every call answers
/// [FeatureNotSupported] and this says so rather than showing an empty list.
///
/// **The share never leaves this device except to the node it enrolls with.** It is generated here,
/// kept in [store] — the platform's keystore — and sent in the two calls that need it. Nothing here
/// logs it, shows it or puts it in an operation record.
class VaultDevices extends ChangeNotifier {
  /// Constructor taking where this device keeps its keys.
  VaultDevices(this.store);

  /// Where this device keeps its keys.
  final DeviceKeyStore store;

  /// Every credential that can open the vault, as the machine last said.
  List<Keyslot> slots = const <Keyslot>[];

  /// This device's key for the machine last looked at, or null when it is not enrolled there.
  DeviceKey? mine;

  /// Whether the machine knows about devices at all: it answered `Keyslots`. False until it has,
  /// and false for a Porelo from before keyslots.
  bool canEnroll = false;

  /// Whether a call is outstanding.
  bool busy = false;

  /// Why the last call could not be made or answered, in words.
  String? problem;

  /// What the last call did, in words.
  String? said;

  /// Stamps each question, so an answer to an older one is never drawn over a newer one.
  int _asked = 0;

  /// Whether this device holds a key for the machine last looked at **that the machine still has a
  /// slot for**. A vault made again keeps the node and loses every device, so a key kept here can
  /// outlive the slot it opened — and sending it only earns a refusal nobody can act on.
  bool get enrolledHere => mine != null && slots.any((each) => each.id == mine!.slot);

  /// Reads the machine's keyslots and this device's key for it.
  Future<void> look(FleetBackend backend) => _ask((mine) async {
        final node = await backend.node();
        final slots = await backend.keyslots();
        final key = node.isEmpty ? null : await store.read(node);
        if (mine != _asked) return;
        this.slots = slots;
        this.mine = key;
        canEnroll = true;
      });

  /// Forgets what was known, for a machine other than the one this described.
  void forget() {
    _asked++;
    slots = const <Keyslot>[];
    mine = null;
    canEnroll = false;
    busy = false;
    problem = null;
    said = null;
    notifyListeners();
  }

  /// Enrolls this device under [name].
  ///
  /// **The key is kept before it is sent**, so a machine that accepted it while the answer was lost
  /// still has a device that holds it; a refusal removes it again. A second try sends the same share,
  /// which the node recognizes as already enrolled rather than making a second keyslot.
  Future<void> enroll(FleetBackend backend, String name) => _ask((mine) async {
        final node = await backend.node();
        if (node.isEmpty) {
          problem = 'This machine does not say which node it is, so a key kept for it could not be '
              'found again. Nothing was enrolled.';
          return;
        }
        final pending = await store.read(node);
        final share = pending?.share ?? newShare();
        await store.write(node, DeviceKey(slot: pending?.slot ?? '', share: share));
        try {
          final answer = await backend.enrollDevice(name: name, share: share, storage: store.storage);
          final slot = answer.slot;
          final kept = (answer.outcome == KeyslotOutcome.enrolled ||
                  answer.outcome == KeyslotOutcome.alreadyEnrolled) &&
              slot != null;
          if (kept) {
            await store.write(node, DeviceKey(slot: slot.id, share: share));
          } else {
            await store.delete(node);
          }
          // The key is kept per node whatever happens; what is on screen belongs to the machine asked.
          if (mine != _asked) return;
          said = keyslotWords(answer.outcome, name: slot?.name ?? name, detail: answer.detail);
          // What the node recorded, not what this device meant to declare: the two can differ.
          if (kept) said = '$said Recorded as ${slot.id}. ${storageWords(slot.storage)}';
        } on FeatureNotSupported {
          await store.delete(node);
          rethrow;
        }
        await _reread(backend, node, mine);
      });

  /// Opens the vault with this device's key for [minutes], or until it is shut when null.
  Future<void> unlock(FleetBackend backend, {required int? minutes}) => _ask((mine) async {
        final node = await backend.node();
        final key = node.isEmpty ? null : await store.read(node);
        if (key == null) {
          problem = 'This device is not enrolled on this machine, so it has nothing to open the vault '
              'with.';
          return;
        }
        final answer = await backend.unlockWithShare(share: key.share, minutes: minutes);
        if (mine != _asked) return;
        said = keyslotWords(answer.outcome, until: clockTime(answer.until), detail: answer.detail);
      });

  /// Revokes [slot]. **Revoking this device forgets its key here too**, since it opens nothing now.
  Future<void> revoke(FleetBackend backend, Keyslot slot) => _ask((mine) async {
        final node = await backend.node();
        final answer = await backend.revokeKeyslot(slot.id);
        if (answer.outcome == KeyslotOutcome.revoked && node.isNotEmpty) {
          final key = await store.read(node);
          if (key != null && key.slot == slot.id) await store.delete(node);
        }
        if (mine != _asked) return;
        said = keyslotWords(answer.outcome, name: slot.name, detail: answer.detail);
        if (answer.outcome == KeyslotOutcome.revoked) said = '$said ${stillOpens(answer.remaining)}';
        slots = answer.remaining;
        this.mine = node.isEmpty ? null : await store.read(node);
      });

  Future<void> _reread(FleetBackend backend, String node, int asked) async {
    final now = await backend.keyslots();
    final kept = await store.read(node);
    if (asked != _asked) return;
    slots = now;
    mine = kept;
  }

  Future<void> _ask(Future<void> Function(int mine) doing) async {
    final mine = ++_asked;
    busy = true;
    problem = null;
    said = null;
    notifyListeners();
    try {
      await doing(mine);
    } on VarlinkException catch (refusal) {
      if (mine == _asked) problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      if (mine == _asked) problem = 'Lost contact with the machine: ${ex.message}';
    } on DeviceKeyStoreFailed catch (ex) {
      if (mine == _asked) {
        problem = "This device's keystore refused (${ex.reason}), so no key could be kept or read. "
            'Is a keyring running and unlocked?';
      }
    } on FeatureNotSupported {
      if (mine == _asked) {
        canEnroll = false;
        problem = "This machine's Porelo cannot enroll devices yet: that arrives with a later Porelo.";
      }
    } finally {
      if (mine == _asked) {
        busy = false;
        notifyListeners();
      }
    }
  }
}

/// An instant from the machine as a time of day here, or as it came when it is not one.
String clockTime(String instant) {
  final parsed = DateTime.tryParse(instant)?.toLocal();
  if (parsed == null) return instant;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(parsed.hour)}:${two(parsed.minute)}';
}

/// What a keyslot call did, as a sentence, for every outcome the keyslots' proposal names and any it adds later.
String keyslotWords(KeyslotOutcome outcome, {String name = '', String until = '', String detail = ''}) =>
    switch (outcome.name) {
      'ENROLLED' => 'This device can open the vault now, as "$name".',
      'ALREADY_ENROLLED' => 'This device was enrolled already, as "$name".',
      'UNKNOWN_STORAGE' =>
        'The machine does not know how this device keeps its key, so it enrolled nothing.',
      'BAD_SHARE' => 'The machine refused the key this device holds: it is not a key it can read.',
      'VAULT_LOCKED' =>
        'The vault is locked. A device is enrolled into an open vault, so unlock it at the machine '
            'first.',
      'VAULT_WITHOUT_KEYSLOTS' => 'This machine has no vault that devices can open.',
      'REVOKED' => '"$name" can no longer open the vault.',
      'NO_SUCH_SLOT' => '"$name" was already gone.',
      'LAST_WAY_IN' => '"$name" is the last way into the vault, so the machine kept it.',
      'UNLOCKED' => until.isEmpty ? 'The vault is open.' : 'The vault is open until $until.',
      'SHARE_REJECTED' => "The machine did not accept this device's key: it was revoked, or never "
          'enrolled on this machine.',
      _ => detail.isEmpty ? 'That did not work, and the machine did not say why.' : detail,
    };

/// Who can still open the vault after a revocation, from what the node answered rather than asked.
String stillOpens(List<Keyslot> remaining) {
  final ways = <String>[
    for (final slot in remaining.where((slot) => !slot.recovery)) '"${slot.name}"',
    if (remaining.any((slot) => slot.recovery)) 'the passphrase, at the machine',
  ];
  if (ways.isEmpty) return 'Nothing can open it now.';
  final listed = ways.length == 1
      ? ways.single
      : '${ways.sublist(0, ways.length - 1).join(', ')} and ${ways.last}';
  return 'Still able to open it: $listed.';
}

/// What a device's way of keeping its key protects against, **never said stronger than it is**.
String storageWords(KeyslotStorage storage) => switch (storage.name) {
      'USER_SCOPED' => 'Kept in a keyring that opens at login: anything running as this user can read it.',
      'APPLICATION_SCOPED' => 'Kept where only this application can read it.',
      'FIDO2' => 'Released only with a touch on a security key.',
      'TPM2' => "Released only with a PIN, by this machine's TPM.",
      _ => 'Kept in a way this build cannot describe, so nothing is claimed for it.',
    };
