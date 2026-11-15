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

/// A machine's *SSH Console*: a terminal on it as the person's own account, or as root for a person listed as its
/// admin, opened from here into the window.
///
/// The key is the one the person's agent holds for the machine and the host key the one it was pinned with, as for
/// every other command to it; nothing here takes a password or names a key file.
class SshConsoleView extends StatefulWidget {
  /// Shows [machine]'s console under [head], offering [open] where it can be opened now, and a switch to [openAsRoot]
  /// where one is given.
  const SshConsoleView({
    required this.machine,
    required this.head,
    required this.open,
    required this.settings,
    this.openAsRoot,
    super.key,
  });

  /// The machine whose console this is.
  final Machine machine;

  /// The leaf's path, notices and filter, as every section of a machine has them.
  final LeafHead head;

  /// Opens the terminal; its reason, where it cannot now, is said under its button.
  final Command open;

  /// Opens the terminal as root, absent for a person root takes no key from: then no switch shows.
  final Command? openAsRoot;

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
  State<SshConsoleView> createState() => _SshConsoleViewState();
}

class _SshConsoleViewState extends State<SshConsoleView> {
  /// Whether the switch stands on root; it falls back to the own account once root is no longer offered.
  bool _asRoot = false;

  @override
  Widget build(BuildContext context) {
    final machine = widget.machine;
    final head = widget.head;
    final settings = widget.settings;
    final rootCommand = widget.openAsRoot;
    final asRoot = _asRoot && rootCommand != null;
    final open = asRoot ? rootCommand : widget.open;
    final login = asRoot ? 'root' : 'your own account';
    final whyNone = SshConsoleView.notOffered(machine);
    final reason = open.unavailable;
    return ListView(
      key: ValueKey<String>('ssh-console ${machine.name}'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        PageHead(
          title: MachineSection.console.label,
          path: head.path,
          pathKey: head.pathKey,
          id: SshConsoleView._id,
          settings: settings,
          subtitle: whyNone == null ? 'as $login on ${machine.where}' : 'not offered for this machine',
        ),
        PageExplanation(id: SshConsoleView._id, settings: settings, parts: pageWords[SshConsoleView._id]!),
        ...head.notices,
        if (whyNone != null)
          Text(whyNone, key: const Key('ssh-console-none'))
        else ...[
          if (rootCommand != null) ...[
            SegmentedButton<bool>(
              key: const Key('ssh-console-login'),
              segments: const [
                ButtonSegment(value: false, label: Text('My account')),
                ButtonSegment(value: true, label: Text('root')),
              ],
              selected: {asRoot},
              onSelectionChanged: (chosen) => setState(() => _asRoot = chosen.single),
            ),
            const SizedBox(height: Space.normal),
          ],
          Text(
            'A shell on ${machine.name} in a terminal in this window, as $login. It logs in with the key '
            'your agent holds for this machine and trusts only the host key the machine was pinned with.',
          ),
          if (asRoot)
            const Text(
              'Root takes the keys of the persons listed as this machine\'s admins. Where it has not taken yours yet, '
              'the terminal shows ssh\'s own refusal.',
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
