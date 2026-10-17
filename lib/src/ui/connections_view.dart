import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guided_walk/guided_walk.dart';
import 'package:porelo_frontend/client.dart';

import '../app/connections.dart';
import 'connection_wizard.dart';
import 'panes.dart';
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
    required this.onClose,
    this.onStoreInATerminal,
    this.onSendAKey,
    this.keysAt = '',
    this.pick = pickWithTheDesktop,
    super.key,
  });

  final Connections connections;

  /// Asks what to declare, and declares it.
  final VoidCallback onAdd;

  /// Forgets the record for one address.
  final ValueChanged<String> onForget;

  /// Closes the view.
  final VoidCallback onClose;

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
          return Column(
            children: <Widget>[
              PaneHeader(
                title: 'Connections — how ${connections.machine} connects out',
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close (Esc)',
                  onPressed: onClose,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Space.normal),
                  children: <Widget>[
                    if (connections.problem != null)
                      _Box(color: scheme.errorContainer, child: Text(connections.problem!, key: const Key('connections-problem'))),
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
                      'owner can — a restricted, read-only token is enough to follow a repository.',
                      key: const Key('connections-explained'),
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: Space.normal),
                    if (connections.all.isEmpty)
                      const Text(
                        'Nothing is declared. A git address still uses a vault entry named after its '
                        'host when there is one.',
                        key: Key('no-connections'),
                      ),
                    for (final each in connections.all)
                      _ConnectionRow(
                        connection: each,
                        vaultOpen: connections.vaultOpen,
                        onForget: () => onForget(each.match),
                      ),
                    const SizedBox(height: Space.normal),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        key: const Key('add-connection'),
                        onPressed: connections.busy ? null : onAdd,
                        icon: const Icon(Icons.add, size: Sizes.rowIcon),
                        label: const Text('Add a connection'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.connection, required this.vaultOpen, required this.onForget});

  final Connection connection;
  final bool vaultOpen;
  final VoidCallback onForget;

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
    return ListTile(
      key: ValueKey<String>('connection ${c.match}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(c.kind == 'SSH_KEY' ? Icons.key_outlined : Icons.password_outlined,
          size: Sizes.rowIcon),
      title: Text(c.match, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${c.kindWords} for ${c.purpose.isEmpty ? 'any use' : c.purpose}, '
              '${c.sourceWords}${c.user.isEmpty ? '' : ', as ${c.user}'} · $there'),
          if (!c.protected)
            Text(
              notInTheVault,
              key: ValueKey<String>('not-protected ${c.match}'),
              style: text.bodySmall?.copyWith(color: scheme.error),
            ),
          if (c.expires.isNotEmpty)
            Text('Stops working at ${c.expires}. Nothing renews it without a person yet.',
                key: ValueKey<String>('expires ${c.match}'), style: text.bodySmall),
        ],
      ),
      // Named, not an icon: this is where a wrong key is taken away, and it has to be found.
      trailing: Tooltip(
        message: 'Forget this record — its value stays where it is',
        child: TextButton.icon(
          key: ValueKey<String>('forget ${c.match}'),
          icon: const Icon(Icons.link_off, size: Sizes.rowIcon),
          label: const Text('Forget'),
          onPressed: onForget,
        ),
      ),
    );
  }
}

/// What declaring wrote, and the storing of its value on the machine.
/// Sends a key to the machine, answering why nothing was stored, or null once it was.
typedef SendAKey = Future<String?> Function({String? file, String? pasted});

class _Storing extends StatefulWidget {
  const _Storing(
      {super.key,
      required this.declared,
      required this.pick,
      this.onStoreInATerminal,
      this.onSendAKey,
      this.keysAt = ''});

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
        initialDirectory: widget.keysAt.isEmpty ? null : widget.keysAt, title: 'Send this key');
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
          color: scheme.errorContainer,
          child: Text(
              '$what Nothing is there yet: it is read ${declared.connection.sourceWords} on the '
              'machine, and a file of this computer is not on that machine. To send a key from '
              'here, forget this record and add it again with its value “In the vault”.',
              key: const Key('connection-declared')),
        );
      }
      return _Box(
        color: scheme.surfaceContainerHighest,
        child: Text('$what Its value is already where it says, so there is nothing to store.',
            key: const Key('connection-declared')),
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
          SelectableText(declared.storeCommand.join(' '),
              key: const Key('store-command'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
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
            WalkSecret(child: TextField(
              key: const Key('store-paste'),
              controller: _pasted,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Or paste the private key'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            )),
            const SizedBox(height: Space.tight),
            OutlinedButton(
              key: const Key('store-send-pasted'),
              onPressed: send == null ? null : _sendPasted,
              child: const Text('Send what was pasted'),
            ),
            if (_refused != null) ...<Widget>[
              const SizedBox(height: Space.small),
              Text(_refused!, key: const Key('store-refused'), style: TextStyle(color: scheme.error)),
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
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.small)),
        child: child,
      );
}
