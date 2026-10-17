import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/project_workspace.dart';

/// The person's key is found, not asked for: theirs at the forge first and chosen, then the one git
/// signs with, then any other.
void main() {
  const mine = SigningKey(publicKey: 'ssh-ed25519 AAAAmine alice@laptop', fingerprint: 'SHA256:mine', comment: 'alice@laptop');
  const agent = SigningKey(publicKey: 'ssh-ed25519 AAAAagent claude', fingerprint: 'SHA256:agent', comment: 'claude-admin-key');
  const backup = SigningKey(
      publicKey: 'ssh-ed25519 AAAAbackup b', fingerprint: 'SHA256:backup', comment: 'backup-from-laptop', gitSigns: true);

  test('the key the forge lists as the person\'s comes first, marked, and is chosen', () {
    final ordered = orderSigningKeys(<SigningKey>[agent, backup, mine],
        const <ForgeSigningKey>[ForgeSigningKey(title: 'Laptop', key: 'ssh-ed25519 AAAAmine')]);
    expect([for (final each in ordered.keys) each.comment], <String>['alice@laptop', 'backup-from-laptop', 'claude-admin-key']);
    expect(ordered.chosen?.fingerprint, 'SHA256:mine');
    expect(ordered.chosen?.atTheForge, 'Laptop');
    expect(ordered.keys.last.atTheForge, isNull, reason: 'another key is not marked as theirs');
  });

  test('where the forge lists none, the one git signs with is chosen', () {
    final ordered = orderSigningKeys(<SigningKey>[agent, backup, mine], const <ForgeSigningKey>[]);
    expect(ordered.chosen?.fingerprint, 'SHA256:backup');
  });

  test('where nothing says which, nothing is chosen for the person', () {
    expect(orderSigningKeys(<SigningKey>[agent, mine], const <ForgeSigningKey>[]).chosen, isNull);
    expect(orderSigningKeys(<SigningKey>[mine], const <ForgeSigningKey>[]).chosen?.fingerprint, 'SHA256:mine',
        reason: 'one key is the only answer');
  });

  test('a forge that cannot be asked lists nothing, and nothing fails', () async {
    expect(await signingKeysAt(null, 'alice'), isEmpty);
  });
}
