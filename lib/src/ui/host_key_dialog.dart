import 'package:flutter/material.dart';

import '../app/host_keys.dart';
import '../app/host_session.dart';
import '../app/machines.dart';
import '../app/session.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// Sets the provider key in its hidden terminal prompt and retains the acceptance or refusal.
Future<bool> openHostKeyDialog(BuildContext context, {OpenTerminal? open, Map<String, String>? environment}) async {
  var accepted = false;
  await runInATerminal(
    context,
    title: 'Set Scaleway key',
    explanation: 'Enter the Scaleway secret key (a UUID) in the terminal. Scaleway checks it before it is kept in this computer’s system secret store.',
    machine: Machine.local(),
    command: [
      poreloHost(environment: environment),
      'key',
      'set',
      'scaleway',
    ],
    shownCommand: 'porelo-host key set scaleway',
    open: open,
    onExit: (code) => accepted = code == 0,
    completed: 'accepted',
    stillWorking: 'Waiting for the secret key and Scaleway’s answer in this terminal.',
  );
  return accepted;
}

/// Shows a host's keys the first time it is reached and asks whether to trust them.
///
/// **Trusting is the choice that has to be made, never the one that happens**: the refusal is the
/// plain button and the trust is a separate, deliberate one, because a key accepted without looking
/// is the whole of what somebody in the middle needs.
Future<bool> confirmHostKey(BuildContext context, HostKeyCheck check) async {
  if (check.pinnedByHost) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('The server key cannot be trusted here'),
        content: Text(check.problem!),
        actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
    return false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(check.changed ? 'The key of ${check.host} is not the one known for it' : 'Trust ${check.host}?'),
          content: SizedBox(
            width: Sizes.dialogMedium,
            child: DialogScroll(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (check.changed)
                    Text(
                      'A different key is known for this address. On a rented server that is usual when '
                      'the address was given to a new machine — one you just created, say. Otherwise it '
                      'can be somebody in the middle. Compare the key below with what the machine itself '
                      'says on its console before replacing the old one: '
                      '`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`.',
                      key: const Key('host-key-changed'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    )
                  else
                    const Text(
                      'This machine has not been reached from here before. Compare its keys with what '
                      'the machine itself says — on a rented server, its console: '
                      '`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`.',
                    ),
                  const SizedBox(height: Space.normal),
                  SelectableText(
                    check.fingerprints.join('\n'),
                    key: const Key('host-key-fingerprints'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('host-key-refuse'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Do not trust it'),
            ),
            FilledButton(
              key: const Key('host-key-accept'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(check.changed ? 'Replace the old key' : 'Trust these keys'),
            ),
          ],
        ),
      ) ??
      false;
}
