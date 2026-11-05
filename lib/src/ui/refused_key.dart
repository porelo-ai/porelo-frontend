import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/gate.dart';
import 'tokens.dart';

/// A forward the machine refused for its ssh key, and the way through it: what happened, which key,
/// the account's keys to try one by one, and keeping one for the address.
///
/// Worded here from the refusal's parts; the forge's own line never reaches the window.
class RefusedKey extends StatelessWidget {
  /// Constructor taking the gate and what each control does.
  const RefusedKey({
    required this.gate,
    required this.machine,
    required this.onRefresh,
    required this.onTry,
    required this.onKeep,
    required this.onTerminal,
    super.key,
  });

  /// The gate whose forward was refused.
  final Gate gate;

  /// The machine's name, as the window shows it.
  final String machine;

  /// Reads the keys again.
  final VoidCallback onRefresh;

  /// Tries one key alone, writing nothing.
  final void Function(SshKey key) onTry;

  /// Keeps one key for the address and forwards again.
  final void Function(SshKey key) onKeep;

  /// Opens a terminal on the machine with the refusal's command ready; null where it names none.
  final VoidCallback? onTerminal;

  @override
  Widget build(BuildContext context) {
    final refusal = gate.keyRefused;
    if (refusal == null) return const SizedBox.shrink();
    final refused = refusal.refused;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('refused-key'),
      width: double.infinity,
      margin: const EdgeInsets.all(Space.normal),
      padding: const EdgeInsets.all(Space.normal),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant, width: Sizes.divider),
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Nothing was forwarded', style: text.titleSmall),
          const SizedBox(height: Space.tight),
          SelectableText(happened(refused, machine), key: const Key('refused-key-what')),
          if (usedKey(refused) case final used?) ...<Widget>[
            const SizedBox(height: Space.tight),
            SelectableText(used, key: const Key('refused-key-used')),
          ],
          const SizedBox(height: Space.small),
          Text(
            'Choose the key to forward ${refusal.branch} with. Try one first: it is tried alone, and '
            'nothing is pushed or kept. Keeping one keeps it for ${refused.address} only.',
          ),
          const SizedBox(height: Space.small),
          if (gate.keysProblem case final why?)
            Text(why, key: const Key('refused-key-keys-problem'))
          else if (gate.keys.isEmpty)
            Text(
              'The account on $machine has no ssh key, neither in its ssh-agent nor in its ssh folder.',
              key: const Key('refused-key-no-keys'),
            )
          else
            for (final key in gate.keys) _KeyRow(sshKey: key, gate: gate, onTry: onTry, onKeep: onKeep),
          const SizedBox(height: Space.small),
          Wrap(
            spacing: Space.small,
            runSpacing: Space.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text('A key not listed? Open KeePassXC, unlock it, and refresh.'),
              OutlinedButton.icon(
                key: const Key('refused-key-refresh'),
                icon: const Icon(Icons.refresh_outlined, size: Sizes.rowIcon),
                label: const Text('Refresh'),
                onPressed: gate.busy ? null : onRefresh,
              ),
            ],
          ),
          if (onTerminal != null) ...<Widget>[
            const SizedBox(height: Space.small),
            Text('What only a terminal can do runs on $machine, in a terminal here.'),
            const SizedBox(height: Space.tight),
            OutlinedButton.icon(
              key: const Key('refused-key-terminal'),
              icon: const Icon(Icons.terminal_outlined, size: Sizes.rowIcon),
              label: Text('Open a terminal on $machine…'),
              onPressed: gate.busy ? null : onTerminal,
            ),
          ],
        ],
      ),
    );
  }

  /// What happened, in this interface's words, from the refusal's outcome.
  static String happened(PushRefused refused, String machine) => switch (refused.outcome) {
    'NO_CREDENTIAL' =>
      'No ssh key is declared for ${refused.address}, so Porelo did not let ssh pick one by itself, '
          'and did not try the push.',
    'KEY_UNAVAILABLE' =>
      'The key declared for ${refused.address} cannot be used on $machine as it stands, so the push '
          'was not tried.',
    'PUSH_REFUSED' => switch (refused.forge) {
      'DEPLOY_KEY' =>
        '${refused.address} refused the push. The forge knows the key as a deploy key, which may not '
            'push there.',
      _ => '${refused.address} refused the push with the key it was given.',
    },
    // An outcome added later: the machine's own sentence, which never carries the forge's line.
    _ => refused.message.isEmpty ? 'The machine refused the forward to ${refused.address}.' : refused.message,
  };

  /// Which key was used, by fingerprint and where it lives; null where none was declared.
  static String? usedKey(PushRefused refused) {
    if (refused.source.isEmpty && refused.fingerprint.isEmpty) return null;
    final where = switch (refused.source) {
      'AGENT' => 'held by the ssh-agent',
      'FILE' when refused.id.isNotEmpty => 'the file ${refused.id}',
      'FILE' => 'a file',
      'VAULT' when refused.id.isNotEmpty => 'the vault entry ${refused.id}',
      'VAULT' => 'the vault',
      _ => refused.source.isEmpty ? '' : refused.source.toLowerCase(),
    };
    final print = refused.fingerprint.isEmpty ? 'a key' : refused.fingerprint;
    return where.isEmpty ? 'Key used: $print.' : 'Key used: $print, $where.';
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.sshKey, required this.gate, required this.onTry, required this.onKeep});

  final SshKey sshKey;
  final Gate gate;
  final void Function(SshKey key) onTry;
  final void Function(SshKey key) onKeep;

  /// An agent's key signs where it is held; a file only where its private half is there and the machine can
  /// sign with it, which a passphrase nothing there can ask for prevents.
  bool get _canSign => sshKey.fromTheAgent || (sshKey.servesWhereItLies && sshKey.usable);

  @override
  Widget build(BuildContext context) {
    final id = Gate.keyId(sshKey);
    final tried = gate.tried[id];
    final notTried = gate.notTried[id];
    final where = sshKey.fromTheAgent ? 'in the ssh-agent' : sshKey.path;
    final named = <String>[
      if (sshKey.comment.isNotEmpty) sshKey.comment,
      if (sshKey.type.isNotEmpty) sshKey.type,
      where,
    ].join(' · ');
    return Padding(
      key: Key('refused-key-row-$id'),
      padding: const EdgeInsets.symmetric(vertical: Space.tight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: Space.small,
            runSpacing: Space.tight,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Icon(sshKey.fromTheAgent ? Icons.key_outlined : Icons.description_outlined, size: Sizes.rowIcon),
              SelectableText(sshKey.fingerprint.isEmpty ? sshKey.path : sshKey.fingerprint),
              Text(named, style: Theme.of(context).textTheme.bodySmall),
              OutlinedButton(
                key: Key('refused-key-try-$id'),
                onPressed: gate.busy || !_canSign ? null : () => onTry(sshKey),
                child: const Text('Try'),
              ),
              FilledButton.tonal(
                key: Key('refused-key-keep-$id'),
                onPressed: gate.busy || !_canSign ? null : () => onKeep(sshKey),
                child: const Text('Keep it and forward again'),
              ),
            ],
          ),
          if (sshKey.obstacle.isNotEmpty) Text(sshKey.obstacle, style: Theme.of(context).textTheme.bodySmall),
          if (!_canSign && sshKey.obstacle.isEmpty)
            Text(
              sshKey.privateHalf
                  ? 'The machine cannot sign with it as it stands.'
                  : 'Only its public half is on the machine, so it cannot sign there.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (tried != null)
            Text(
              tried.accepted
                  ? 'The forge would take the push with this key. Nothing was pushed.'
                  : 'The forge refused the push with this key too. Nothing was pushed.',
              key: Key('refused-key-tried-$id'),
            ),
          // What the forge answered, as only the machine can say it.
          if (tried != null && !tried.accepted && tried.message.isNotEmpty)
            SelectableText(tried.message, style: Theme.of(context).textTheme.bodySmall),
          if (notTried != null) Text(notTried, key: Key('refused-key-not-tried-$id')),
        ],
      ),
    );
  }
}
