import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../app/commands.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import '../app/shell_model.dart';
import '../app/ssh_console.dart';
import 'filtered_list_section.dart';
import 'page_explanation.dart';
import 'page_words.dart';
import 'session_terminal.dart';
import 'terminal_copy.dart';
import 'terminal_links.dart';
import 'terminal_look.dart';
import 'tokens.dart';

/// A machine's *SSH Console*: a terminal on it as the person's own account, or as root for a person listed as its
/// admin, standing in the whole page once opened.
///
/// The key is the one the person's agent holds for the machine and the host key the one it was pinned with, as for
/// every other command to it; nothing here takes a password or names a key file. The terminal takes the page's size,
/// and every change of it reaches the shell on the machine, so a full-screen program there draws to the size shown.
class SshConsoleView extends StatefulWidget {
  /// Shows [machine]'s console under [head]: [commandFor] makes its line, [openTerminal] runs it here, and
  /// [unavailable] and [rootUnavailable] say why it cannot open now. [rootOffered] shows the switch to root.
  const SshConsoleView({
    required this.machine,
    required this.head,
    required this.settings,
    required this.commandFor,
    this.openTerminal,
    this.unavailable,
    this.rootOffered = false,
    this.rootUnavailable,
    super.key,
  });

  /// The machine whose console this is.
  final Machine machine;

  /// The leaf's path, notices and filter, as every section of a machine has them.
  final LeafHead head;

  /// Where the explanation's fold is kept.
  final Settings settings;

  /// The console's command line, as root or not, asked at the press; a [StateError] says why it opens nothing.
  final List<String> Function({required bool asRoot}) commandFor;

  /// Runs the line in a terminal on this computer, or null for this computer's own.
  final OpenTerminal? openTerminal;

  /// Why the own console cannot open now, or null where it can.
  final String? unavailable;

  /// Whether the person may switch to root: only one root takes a key from.
  final bool rootOffered;

  /// Why the root console cannot open now, or null where it can.
  final String? rootUnavailable;

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
  /// Whether the switch stands on root; only shown, and only taken, while root is offered.
  bool _asRoot = false;

  /// The shell while it is open on the page, and once it ended until the person closes it.
  Session? _session;

  /// The line it runs, shown above it.
  List<String>? _line;

  /// Whether the open shell is root's.
  bool _openAsRoot = false;

  /// Why the last press opened nothing.
  String? _refused;

  final _keyboard = FocusNode(debugLabel: 'SSH console');
  final _selection = TerminalController();

  /// Opens the console in the page, as root where [asRoot].
  void _open({required bool asRoot}) {
    final List<String> line;
    try {
      line = widget.commandFor(asRoot: asRoot);
    } on StateError catch (refused) {
      setState(() => _refused = refused.message);
      return;
    }
    final session = Session(task: 'console', machine: widget.machine, open: widget.openTerminal, run: line)
      ..addListener(_changed);
    setState(() {
      _refused = null;
      _line = line;
      _openAsRoot = asRoot;
      _session = session;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.requestFocus();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Closes the console: a shell still running is asked about first, for closing ends it.
  Future<void> _close() async {
    final session = _session;
    if (session == null) return;
    if (session.state != SessionState.over) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close the console?'),
          content: Text('The shell on ${widget.machine.name} is still running. Closing the console ends it.'),
          actions: [
            TextButton(
              key: const Key('ssh-console-close-no'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it open'),
            ),
            FilledButton(
              key: const Key('ssh-console-close-yes'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Close the console'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted || !identical(session, _session)) return;
    }
    setState(() => _session = null);
    _end(session);
  }

  /// Ends [session]'s way in and lets it go.
  void _end(Session session) {
    session.removeListener(_changed);
    unawaited(session.leave().whenComplete(session.dispose));
  }

  @override
  void dispose() {
    if (_session case final session?) _end(session);
    _keyboard.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return session == null ? _start(context) : _console(context, session);
  }

  /// The page before the console is opened: the switch, the words and the button.
  Widget _start(BuildContext context) {
    final machine = widget.machine;
    final head = widget.head;
    final settings = widget.settings;
    final asRoot = _asRoot && widget.rootOffered;
    final open = asRoot
        ? openRootSshConsoleCommand(
            machine: machine.name,
            open: () => _open(asRoot: true),
            unavailable: widget.rootUnavailable,
          )
        : openSshConsoleCommand(
            machine: machine.name,
            open: () => _open(asRoot: false),
            unavailable: widget.unavailable,
          );
    final login = asRoot ? 'root' : 'your own account';
    final whyNone = SshConsoleView.notOffered(machine);
    final reason = open.unavailable ?? _refused;
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
          if (widget.rootOffered) ...[
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
            'A shell on ${machine.name} in this page, as $login. It logs in with the key your agent holds for this '
            'machine and trusts only the host key the machine was pinned with. Leaving the page ends it.',
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

  /// The open console: its line and the way to close it above, the terminal in all the room left.
  Widget _console(BuildContext context, Session session) {
    final machine = widget.machine;
    final over = session.state == SessionState.over;
    return Padding(
      key: ValueKey<String>('ssh-console-open ${machine.name}'),
      padding: const EdgeInsets.all(Space.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.normal,
            runSpacing: Space.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _openAsRoot ? 'Root console on ${machine.name}' : 'SSH Console on ${machine.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                key: const Key('ssh-console-close'),
                onPressed: _close,
                child: const Text('Close the console'),
              ),
            ],
          ),
          SelectableText(
            (_line ?? const []).join(' '),
            key: const Key('ssh-console-line'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: Space.small),
          Expanded(
            child: ColoredBox(
              color: TerminalLook.background,
              child: CopiesAsShown(
                terminal: session.terminal,
                controller: _selection,
                child: SessionTerminal(
                  session: session,
                  viewKey: const Key('ssh-console-terminal'),
                  theme: TerminalLook.theme,
                  controller: _selection,
                  focusNode: _keyboard,
                  padding: const EdgeInsets.all(Space.small),
                  textStyle: const TerminalStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          const TerminalPasteHint(),
          TerminalCopyAsk(session: session),
          if (!over) TerminalLinks(session: session),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                session.problem ?? 'The shell on ${machine.name} has ended. Typing exit ends it, as it did now.',
                key: const Key('ssh-console-ended'),
              ),
            ),
        ],
      ),
    );
  }
}
