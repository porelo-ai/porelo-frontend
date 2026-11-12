import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guided_walk/guided_walk.dart';
import 'package:porelo_frontend/client.dart';

import '../app/commands.dart';
import '../app/connections.dart';
import 'command_menu.dart';
import 'connection_wizard.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'page_explanation.dart' show counted;
import 'pick_a_file.dart';
import 'tokens.dart';

/// How a machine connects out: every credential it is configured with, and what to do about one.
///
/// **Listed with the vault shut too**, because the list holds no secret — which is what tells
/// *"configured, open the vault"* from *"nothing here"*. A credential kept outside the vault is shown
/// as not protected, and never refused.
class ConnectionsView extends StatelessWidget {
  /// Constructor taking the connections and what each action does.
  const ConnectionsView({
    required this.connections,
    required this.onAdd,
    required this.onForget,
    required this.head,
    this.destinations,
    this.onStoreInATerminal,
    this.onSendAKey,
    this.keysAt = '',
    this.pick = pickWithTheDesktop,
    super.key,
  });

  /// The connections the machine keeps, and what changes them.
  final Connections connections;

  /// Asks what to declare, and declares it.
  final VoidCallback onAdd;

  /// Forgets the record for one address.
  final ValueChanged<String> onForget;

  /// Where the page sits and what its head says beside the connections' own words.
  final LeafHead head;

  /// The machine's destinations, the second group of rows under the same head.
  final Widget? destinations;

  /// Stores the last declared value by typing it into a terminal on the machine; null where
  /// nothing here reaches that machine's `porelo`.
  final VoidCallback? onStoreInATerminal;

  /// Sends a key to the machine's store command on its standard input — a file of this computer's,
  /// by path, or what was pasted. Null where nothing here reaches that machine's `porelo`.
  final SendAKey? onSendAKey;

  /// Where this computer keeps its ssh keys, for the file dialog to start in.
  final String keysAt;

  /// Asks for a file of this computer.
  final PickAFile pick;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: connections,
    builder: (context, _) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      final read = connections.read && connections.problem == null;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(Space.normal),
        child: FilteredListSection(
          key: ValueKey<String>(head.id),
          storageId: head.id,
          title: 'Credentials',
          leaf: true,
          collapsible: false,
          path: head.path,
          pathKey: head.pathKey,
          search: head.filter,
          searchHint: 'Filter the connections and destinations',
          read: connections.read,
          busy: connections.busy,
          problem: connections.problem,
          staleRows: head.stale,
          subtitle: counted(connections.all.length, 'connection', 'connections'),
          // Rarely needed — a repository on no forge set up here, or a key a machine must stop using — so
          // kept out of the everyday view.
          actions: <Widget>[
            CommandMenu(
              key: const Key('connections-menu'),
              tooltip: 'Add or forget a connection',
              commands: <Command>[
                Command(
                  id: 'add-connection',
                  label: 'Add a connection',
                  group: 'Connections',
                  home: Home.openedView,
                  unavailable: connections.busy ? 'Still reading or changing the connections.' : null,
                  run: onAdd,
                ),
                for (final each in connections.all)
                  Command(
                    id: 'forget ${each.match}',
                    label: 'Forget ${each.match} — its value stays where it is',
                    group: 'Connections',
                    home: Home.openedView,
                    danger: true,
                    // As greyed out as the rows it stands for, while they are only the last ones read.
                    unavailable: head.stale
                        ? 'The machine does not answer; these are the connections it last listed.'
                        : connections.busy
                        ? 'Still reading or changing the connections.'
                        : null,
                    run: () => onForget(each.match),
                  ),
              ],
            ),
          ],
          beforeRows: <Widget>[
            ...head.notices,
            if (connections.forgotten != null)
              _Box(
                color: scheme.surfaceContainerHighest,
                child: Text(connections.forgottenWords, key: const Key('connections-forgotten')),
              ),
            if (connections.declared case final declared?)
              _Storing(
                // A new declaration is a new storing, and opens its own file dialog.
                key: ObjectKey(declared),
                declared: declared,
                onStoreInATerminal: onStoreInATerminal,
                onSendAKey: onSendAKey,
                keysAt: keysAt,
                pick: pick,
              ),
            Text(
              'Only the description is kept here; a value is stored on the machine and '
              'never passes through this program. A key or a token reaches everything its '
              'owner can — a restricted, read-only token is enough to fetch a repository.',
              key: const Key('connections-explained'),
              style: text.bodySmall,
            ),
            Padding(
              padding: const EdgeInsets.only(top: Space.normal, bottom: Space.small),
              child: Wrap(
                spacing: Space.small,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text('Connections', style: text.titleMedium),
                  Text(read ? '${connections.all.length}' : 'not read', style: text.bodySmall),
                ],
              ),
            ),
          ],
          emptyWords:
              'Nothing is declared. A git address still uses a vault entry named after its '
              'server when there is one.',
          rows: <FilteredRow>[
            for (final each in connections.all)
              (
                words: '${each.match} ${each.kindWords} ${each.purpose}',
                child: _ConnectionRow(connection: each, vaultOpen: connections.vaultOpen),
              ),
          ],
          afterRows: <Widget>[?destinations],
        ),
      );
    },
  );
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.connection, required this.vaultOpen});

  final Connection connection;
  final bool vaultOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = connection;
    // Missing is only a fact with the vault open; shut, it says only that the vault is shut.
    final there = c.present
        ? 'its value is there'
        : c.source == 'VAULT' && !vaultOpen
        ? 'the vault is shut, so nothing can say whether its value is there'
        : 'its value is missing';
    return LeafListRow(
      key: ValueKey<String>('connection ${c.match}'),
      leading: Icon(c.kind == 'SSH_KEY' ? Icons.key_outlined : Icons.password_outlined, size: Sizes.rowIcon),
      title: c.match,
      state: c.present
          ? 'stored'
          : c.source == 'VAULT' && !vaultOpen
          ? 'shut'
          : 'missing',
      subtitleMaxLines: null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${c.kindWords} for ${c.purpose.isEmpty ? 'any use' : c.purpose}, '
            '${c.sourceWords}${c.user.isEmpty ? '' : ', as ${c.user}'} · $there',
          ),
          if (!c.protected)
            Text(
              notInTheVault,
              key: ValueKey<String>('not-protected ${c.match}'),
              style: text.bodySmall?.copyWith(color: scheme.error),
            ),
          if (c.expires.isNotEmpty)
            Text(
              'Stops working at ${c.expires}. Nothing renews it without a person yet.',
              key: ValueKey<String>('expires ${c.match}'),
              style: text.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// What declaring wrote, and the storing of its value on the machine.
/// Sends a key to the machine, answering why nothing was stored, or null once it was.
typedef SendAKey = Future<String?> Function({String? file, String? pasted});

class _Storing extends StatefulWidget {
  const _Storing({
    super.key,
    required this.declared,
    required this.pick,
    this.onStoreInATerminal,
    this.onSendAKey,
    this.keysAt = '',
  });

  final CredentialDeclared declared;
  final PickAFile pick;
  final VoidCallback? onStoreInATerminal;
  final SendAKey? onSendAKey;
  final String keysAt;

  @override
  State<_Storing> createState() => _StoringState();
}

class _StoringState extends State<_Storing> {
  final _pasted = TextEditingController();

  /// Why the last key sent was not stored; it stays here, beside the way to try again.
  String? _refused;

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  Future<void> _chooseAndSend() async {
    final chosen = await widget.pick(
      initialDirectory: widget.keysAt.isEmpty ? null : widget.keysAt,
      title: 'Send this key',
    );
    if (chosen != null && mounted) await _send(file: chosen);
  }

  Future<void> _send({String? file, String? pasted}) async {
    setState(() => _refused = null);
    final refused = await widget.onSendAKey?.call(file: file, pasted: pasted);
    if (mounted) setState(() => _refused = refused);
  }

  void _sendPasted() {
    final value = _pasted.text;
    // Out of the field at once: nothing here keeps a value once it has been sent.
    _pasted.clear();
    unawaited(_send(pasted: value));
  }

  @override
  Widget build(BuildContext context) {
    final declared = widget.declared;
    final scheme = Theme.of(context).colorScheme;
    final what = '${declared.replaced ? 'Updated' : 'Added'}: ${declared.connection.match}.';
    if (declared.storeCommand.isEmpty) {
      if (!declared.connection.present) {
        return _Box(
          color: scheme.surfaceContainerLow,
          child: Text(
            '$what Nothing is there yet: it is read ${declared.connection.sourceWords} on the '
            'machine, and a file of this computer is not on that machine. To send a key from '
            'here, forget this record and add it again with its value “In the vault”.',
            key: const Key('connection-declared'),
          ),
        );
      }
      return _Box(
        color: scheme.surfaceContainerHighest,
        child: Text(
          '$what Its value is already where it says, so there is nothing to store.',
          key: const Key('connection-declared'),
        ),
      );
    }
    final send = widget.onSendAKey;
    return _Box(
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$what Its value is stored on the machine, with:', key: const Key('connection-declared')),
          const SizedBox(height: Space.tight),
          SelectableText(
            declared.storeCommand.join(' '),
            key: const Key('store-command'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: Space.small),
          if (declared.storeStdin.isEmpty)
            OutlinedButton.icon(
              key: const Key('store-in-terminal'),
              onPressed: widget.onStoreInATerminal,
              icon: const Icon(Icons.terminal, size: Sizes.rowIcon),
              label: const Text('Type it into a terminal on the machine'),
            )
          else ...<Widget>[
            Text('It reads ${declared.storeStdin} on its standard input.'),
            const SizedBox(height: Space.small),
            OutlinedButton.icon(
              key: const Key('store-choose-file'),
              onPressed: send == null ? null : () => unawaited(_chooseAndSend()),
              icon: const Icon(Icons.folder_open, size: Sizes.rowIcon),
              label: const Text('Choose a key file of this computer, and send it'),
            ),
            const SizedBox(height: Space.small),
            // A private key: blanked, and left out of what a walk writes down.
            WalkSecret(
              child: TextField(
                key: const Key('store-paste'),
                controller: _pasted,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Or paste the private key'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: Space.tight),
            OutlinedButton(
              key: const Key('store-send-pasted'),
              onPressed: send == null ? null : _sendPasted,
              child: const Text('Send what was pasted'),
            ),
            if (_refused != null) ...<Widget>[
              const SizedBox(height: Space.small),
              Text(
                _refused!,
                key: const Key('store-refused'),
                style: TextStyle(color: scheme.error),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: Space.normal),
    padding: const EdgeInsets.all(Space.normal),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: Sizes.divider),
      borderRadius: BorderRadius.circular(Radii.small),
    ),
    child: child,
  );
}
