import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/machines.dart';
import '../app/settings.dart';
import '../app/shell_model.dart';
import '../app/ssh_console.dart';
import 'filtered_list_section.dart';
import 'page_explanation.dart';
import 'page_words.dart';
import 'tokens.dart';

/// A machine's *SSH Console*: a terminal on it as the person's own account, opened from here into the window.
///
/// The key is the one the person's agent holds for the machine and the host key the one it was pinned with, as for
/// every other command to it; nothing here takes a password or names a key file.
class SshConsoleView extends StatelessWidget {
  /// Shows [machine]'s console under [head], offering [open] where it can be opened now.
  const SshConsoleView({
    required this.machine,
    required this.head,
    required this.open,
    required this.settings,
    super.key,
  });

  /// The machine whose console this is.
  final Machine machine;

  /// The leaf's path, notices and filter, as every section of a machine has them.
  final LeafHead head;

  /// Opens the terminal; its reason, where it cannot now, is said under its button.
  final Command open;

  /// Where the explanation's fold is kept.
  final Settings settings;

  static final _id = machineSectionPageId(MachineSection.console);

  /// Why [machine] has no console at all, or null where it is reached over ssh.
  static String? notOffered(Machine machine) {
    if (sshConsoleOffered(machine)) return null;
    if (machine.kind == 'wsl') {
      return '${machine.name} is a WSL distribution on this computer, reached through wsl.exe and not over ssh, '
          'so it has no SSH Console.';
    }
    if (machine.isThisComputer) return '${machine.name} is this computer, so it has no SSH Console.';
    return '${machine.name} is reached through a socket something else forwarded, so nothing here has an ssh '
        'address for it.';
  }

  @override
  Widget build(BuildContext context) {
    final whyNone = notOffered(machine);
    final reason = open.unavailable;
    return ListView(
      key: ValueKey<String>('ssh-console ${machine.name}'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        PageHead(
          title: MachineSection.console.label,
          path: head.path,
          pathKey: head.pathKey,
          id: _id,
          settings: settings,
          subtitle: whyNone == null ? 'as your own account on ${machine.where}' : 'not offered for this machine',
        ),
        PageExplanation(id: _id, settings: settings, parts: pageWords[_id]!),
        ...head.notices,
        if (whyNone != null)
          Text(whyNone, key: const Key('ssh-console-none'))
        else ...[
          Text(
            'A shell on ${machine.name} in a terminal in this window, as your own account. It logs in with the key '
            'your agent holds for this machine and trusts only the host key the machine was pinned with.',
          ),
          const SizedBox(height: Space.normal),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('ssh-console-open'),
              onPressed: open.available ? open.run : null,
              child: Text(open.label),
            ),
          ),
          // A grey button says why in words, never behind a hover alone.
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(reason, key: const Key('ssh-console-why')),
            ),
        ],
      ],
    );
  }
}
