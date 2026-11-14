import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/vault.dart';
import '../app/vault_devices.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'tokens.dart';

/// The vault: what it holds, by name, and the devices that open it, as a page of its machine.
///
/// Opening, shutting and enrolling are the page's actions; this is what there is to read and the
/// one thing to undo, revoking a device.
class VaultView extends StatelessWidget {
  /// Constructor taking the store, the page's head and what can be done to it.
  const VaultView({
    required this.vault,
    required this.onRevoke,
    required this.head,
    required this.atTheMachine,
    this.actions = const [],
    this.notes = const [],
    this.onUnlockHere,
    this.onMakeHere,
    this.onGrant,
    super.key,
  });

  /// What the store says about itself.
  final Vault vault;

  /// Revokes one way in.
  final ValueChanged<Keyslot> onRevoke;

  /// Where the page sits and what its head says beside the vault's own words.
  final LeafHead head;

  /// Whether this window runs on the vault's machine, where its passphrase is typed: the last device is revoked only
  /// there.
  final bool atTheMachine;

  /// The page's main action and the menu of the vault's other commands.
  final List<Widget> actions;

  /// Lines said under the head, before the entries.
  final List<Widget> notes;

  /// Opens the vault by its passphrase in a terminal on the machine, or null where nothing here
  /// can reach that machine's own `porelo`.
  final VoidCallback? onUnlockHere;

  /// Makes the vault by a passphrase chosen in a terminal on the machine, for a machine with none.
  final VoidCallback? onMakeHere;

  /// Grants the authorization an entry names, once, in a browser; null where it cannot be offered.
  final ValueChanged<Credential>? onGrant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = vault.state;
    final small = Theme.of(context).textTheme.bodySmall;
    final devices = vault.devices;
    return ListenableBuilder(
      listenable: head.filter,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(Space.normal),
        children: [
          FilteredListSection(
            key: ValueKey<String>(head.id),
            storageId: head.id,
            title: 'Vault',
            leaf: true,
            collapsible: false,
            path: head.path,
            pathKey: head.pathKey,
            search: head.filter,
            searchHint: 'Filter the entries',
            read: state != null,
            busy: vault.busy,
            problem: vault.problem,
            staleRows: head.stale,
            subtitle: state == null
                ? null
                : !state.exists
                ? 'No vault yet'
                : state.readable
                ? 'Made · open · ${vault.credentials.length} entries'
                : 'Made · locked',
            actions: actions,
            beforeRows: [
              ...head.notices,
              ...notes,
              if (state != null && state.exists && !state.readable)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.small),
                  child: Text('The vault is locked', style: TextStyle(color: StateColours.of(scheme).waiting)),
                ),
              if (state != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.small),
                  child: Text(
                    'Where it is: ${state.vault.isEmpty ? '—' : state.vault}',
                    key: const Key('vault-where-it-is'),
                    style: small,
                  ),
                ),
              if (state != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.small),
                  child: Text(
                    'State: ${switch ((state.exists, state.readable)) {
                      (false, _) => 'no vault on this machine yet',
                      (true, true) => 'open — its contents can be read',
                      (true, false) => 'shut, so nothing here can say what it holds',
                    }}',
                    key: const Key('vault-state'),
                    style: small,
                  ),
                ),
            ],
            // Readable, because there is nothing to open — which is not an open store.
            emptyWords: state == null
                ? null
                : !state.exists
                ? 'There is no vault yet, so there is nothing in it. It is made at the machine, '
                      'with a passphrase chosen there.'
                : !state.readable
                ? 'Nothing can be listed while it is shut. That is not the same as it holding nothing.'
                : 'It is open and holds nothing. That is a state, not a failure.',
            // Names, kinds and lengths. **Never a value** — that is the whole promise of the
            // method, and this interface reaches a socket that can be forwarded over ssh.
            rows: [
              for (final credential in vault.credentials)
                (
                  words: '${credential.name} ${credential.type}',
                  child: ItemListRow(
                    key: ValueKey<String>('credential ${credential.name}'),
                    leading: const Icon(Icons.key_outlined, size: Sizes.mark),
                    title: credential.name,
                    titleKey: const Key('credential-name'),
                    subtitle: describeEntry(credential),
                    subtitleMaxLines: null,
                    state: !credential.isGranted
                        ? 'stored'
                        : credential.grant == null
                        ? 'not granted'
                        : 'granted',
                    onOpen: null,
                    // A service a person decides about in a browser, once, for later tasks.
                    menu: credential.isGranted && onGrant != null
                        ? TextButton(
                            key: ValueKey<String>('grant ${credential.name}'),
                            onPressed: () => onGrant!(credential),
                            child: Text(credential.grant == null ? 'Grant it' : 'Grant it again'),
                          )
                        : null,
                  ),
                ),
            ],
            afterRows: [
              if (devices.problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.wide),
                  child: Text(
                    devices.problem!,
                    key: const Key('devices-problem'),
                    style: small?.copyWith(color: scheme.error),
                  ),
                ),
              if (devices.said != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.small),
                  child: Text(devices.said!, key: const Key('devices-said')),
                ),
              LeafRowsCard(
                title: 'Devices that open it',
                count: devices.problem != null ? 'not read' : '${devices.slots.length}',
                empty: Text(devices.problem != null ? 'not read' : 'None is listed.', style: small),
                children: [
                  for (final slot in devices.slots)
                    if (passesFilter(head.filter, slot.name))
                      ItemListRow(
                        key: Key('keyslot-${slot.id}'),
                        leading: Icon(slot.recovery ? Icons.password : Icons.devices_outlined, size: Sizes.mark),
                        title: devices.mine?.slot == slot.id ? '${slot.name} — this device' : slot.name,
                        subtitle: _about(slot),
                        state: slot.recovery
                            ? 'passphrase'
                            : devices.mine?.slot == slot.id
                            ? 'this device'
                            : 'enrolled',
                        onOpen: null,
                        // The way in when every device is gone, changed at the machine; revoking it from a
                        // window that may have lost its devices is not offered.
                        menu: slot.recovery
                            ? null
                            : IconButton(
                                key: Key('revoke-${slot.id}'),
                                tooltip: 'Revoke',
                                icon: const Icon(Icons.remove_circle_outline, size: Sizes.rowIcon),
                                onPressed: devices.busy ? null : () => _revoke(context, slot),
                              ),
                      ),
                ],
              ),
              const SizedBox(height: Space.wide),
              // One line for everything that happens at the machine instead: a daemon has no
              // terminal to take a passphrase at.
              Text(
                'At the machine: `porelo vault unlock` opens it without a device, `porelo vault '
                'passphrase` changes its passphrase.',
                key: const Key('at-the-machine'),
                style: small,
              ),
              // The way out of a vault nothing has opened yet: a device can only be enrolled into
              // an open one, so the first opening is always by the passphrase.
              if (onMakeHere case final make? when vault.missing)
                Padding(
                  padding: const EdgeInsets.only(top: Space.small),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('make-in-terminal'),
                      onPressed: make,
                      icon: const Icon(Icons.terminal, size: Sizes.rowIcon),
                      label: const Text('Make it here, with a passphrase, in a terminal'),
                    ),
                  ),
                ),
              if (onUnlockHere case final unlock? when !vault.readable && !vault.missing)
                Padding(
                  padding: const EdgeInsets.only(top: Space.small),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('unlock-in-terminal'),
                      onPressed: unlock,
                      icon: const Icon(Icons.terminal, size: Sizes.rowIcon),
                      label: const Text('Open it here, with its passphrase, in a terminal'),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(BuildContext context, Keyslot slot) async {
    final cost = revokeCost(
      slot: slot,
      slots: vault.devices.slots,
      itself: vault.devices.mine?.slot == slot.id,
      atTheMachine: atTheMachine,
    );
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cost.refused ? '"${slot.name}" is not revoked from here' : 'Revoke "${slot.name}"?'),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: Text(cost.words, key: const Key('revoke-says')),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('revoke-keep'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cost.refused ? 'Close' : 'Keep it'),
          ),
          if (!cost.refused)
            FilledButton(
              key: const Key('revoke-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Revoke'),
            ),
        ],
      ),
    );
    if (sure ?? false) onRevoke(slot);
  }

  /// What is known about one entry, without any of it.
  static String _kindAndGrant(Credential credential) {
    final kind = credential.type.isEmpty ? 'kind not recorded' : credential.type;
    final described = credential.characters == 0 ? kind : '$kind · ${credential.characters} characters';
    if (!credential.isGranted) return described;
    // Who a task using it acts as: the machine's record, which outlives any task.
    final grant = credential.grant;
    return grant == null
        ? '$described · not granted yet'
        : '$described · granted by ${grant.grantedBy.isEmpty ? 'an account not recorded' : grant.grantedBy}'
              '${grant.grantedAt.isEmpty ? '' : ', ${grant.grantedAt}'}';
  }
}

/// What is known about one entry, and what goes with it that is not secret: its kind, its length,
/// how it was granted, and its settings shown whole. Never its value.
String describeEntry(Credential credential) {
  final described = VaultView._kindAndGrant(credential);
  if (credential.settings.isEmpty) return described;
  return '$described · ${[for (final setting in credential.settings.entries) '${setting.key}: ${setting.value}'].join(', ')}';
}

String _about(Keyslot slot) {
  if (slot.recovery) return 'The passphrase, used at the machine.';
  final used = slot.lastUsed.isEmpty ? 'not used yet' : 'last used ${_day(slot.lastUsed)}';
  return '${storageWords(slot.storage)} Enrolled ${_day(slot.enrolled)}, $used.';
}

String _day(String instant) => instant.length >= 10 ? instant.substring(0, 10) : instant;
