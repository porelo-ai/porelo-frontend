import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../app/machines.dart';
import '../app/session.dart';
import 'dialog_scroll.dart';

import 'package:guided_walk/guided_walk.dart';

import 'tokens.dart';
import 'terminal_copy.dart';
import 'terminal_links.dart';
import 'terminal_look.dart';

/// Opens [machine]'s vault by its passphrase, typed into a terminal running [command] there.
///
/// The only way from here to a vault nothing has opened yet: unlocking with a device needs the
/// device enrolled, and enrolling needs the vault open. Returns once the dialog is put away.
Future<void> unlockInATerminal(
  BuildContext context, {
  required Machine machine,
  required List<String> command,
  OpenTerminal? open,
}) => runInATerminal(
  context,
  title: 'Open the vault on ${machine.name}',
  explanation:
      "Type the vault's passphrase into the terminal. It goes straight to the machine "
      'and never through this program, and nothing here keeps it.',
  machine: machine,
  command: command,
  open: open,
);

/// Runs [command] on [machine] in a terminal a person types into, for a value this program must
/// never hold. Returns once the dialog is put away; what came of it is asked of the machine then.
/// [onExit] reports a process exit, never cancellation; [completed] is shown only after exit zero.
/// [shownCommand] can show a readable command when the actual argument list uses a shell parameter.
Future<void> runInATerminal(
  BuildContext context, {
  required String title,
  required String explanation,
  required Machine machine,
  required List<String> command,
  OpenTerminal? open,
  bool forwardsALoginReply = false,
  String stillWorking = 'Still running on the machine. It may print nothing for a while.',
  String cancel = 'Cancel it',
  Future<String?> Function()? whatCameOfIt,
  ValueChanged<int>? onExit,
  String? shownCommand,
  String? completed,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _UnlockTerminal(
    title: title,
    explanation: explanation,
    machine: machine,
    command: command,
    open: open,
    forwardsALoginReply: forwardsALoginReply,
    stillWorking: stillWorking,
    cancel: cancel,
    whatCameOfIt: whatCameOfIt,
    onExit: onExit,
    shownCommand: shownCommand,
    completed: completed,
  ),
);

class _UnlockTerminal extends StatefulWidget {
  const _UnlockTerminal({
    required this.title,
    required this.explanation,
    required this.machine,
    required this.command,
    this.open,
    this.forwardsALoginReply = false,
    required this.stillWorking,
    required this.cancel,
    this.whatCameOfIt,
    this.onExit,
    this.shownCommand,
    this.completed,
  });

  final String title;
  final String explanation;
  final Machine machine;
  final List<String> command;
  final OpenTerminal? open;
  final bool forwardsALoginReply;

  /// What is said while it runs: a terminal that prints nothing for minutes looks finished.
  final String stillWorking;

  /// The button that ends it early, which is never the obvious one while it runs.
  final String cancel;

  /// Asked of the machine once the terminal has ended, and said in one sentence of the interface's
  /// own: at the end two programs speak at once in the terminal, and neither is the verdict.
  final Future<String?> Function()? whatCameOfIt;

  final ValueChanged<int>? onExit;
  final String? shownCommand;
  final String? completed;

  @override
  State<_UnlockTerminal> createState() => _UnlockTerminalState();
}

class _UnlockTerminalState extends State<_UnlockTerminal> {
  late final Session _session = Session(
    task: 'vault',
    machine: widget.machine,
    open: widget.open,
    run: widget.command,
    forwardsALoginReply: widget.forwardsALoginReply,
  )..addListener(_changed);

  // Asked for once the dialog is on screen: an autofocus inside a dialog loses to its buttons.
  final _keyboard = FocusNode(debugLabel: 'terminal in a dialog');
  final _selection = TerminalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.requestFocus();
    });
  }

  /// Ends it early, once the person says so.
  Future<void> _cancelIt() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.cancel}?'),
        content: const Text('It is still running. Ending it now loses what it has done so far.'),
        actions: <Widget>[
          TextButton(
            key: const Key('unlock-cancel-no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Let it run'),
          ),
          FilledButton(
            key: const Key('unlock-cancel-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(widget.cancel),
          ),
        ],
      ),
    );
    if (yes == true && mounted) Navigator.of(context).pop();
  }

  /// What the machine says came of it, once asked; null before.
  String? _cameOfIt;
  bool _asked = false;
  bool _reportedExit = false;

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final code = _session.exitCode;
    if (!_reportedExit && code != null) {
      _reportedExit = true;
      widget.onExit?.call(code);
    }
    final asking = widget.whatCameOfIt;
    if (asking != null && !_asked && _session.state == SessionState.over) {
      _asked = true;
      unawaited(
        asking().then((said) {
          if (mounted) setState(() => _cameOfIt = said);
        }),
      );
    }
  }

  @override
  void dispose() {
    _session
      ..removeListener(_changed)
      ..dispose();
    _keyboard.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: Sizes.dialog,
      child: DialogScroll(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.explanation, key: const Key('unlock-explained')),
            const SizedBox(height: Space.small),
            SelectableText(
              widget.shownCommand ?? widget.command.join(' '),
              key: const Key('unlock-command'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: Space.small),
            SizedBox(
              height: Sizes.terminal,
              child: ColoredBox(
                color: TerminalLook.background,
                child: WalkSecret(
                  child: CopiesAsShown(
                    terminal: _session.terminal,
                    controller: _selection,
                    child: TerminalView(
                      _session.terminal,
                      key: const Key('unlock-terminal'),
                      theme: TerminalLook.theme,
                      controller: _selection,
                      shortcuts: terminalShortcuts,
                      focusNode: _keyboard,
                      autofocus: true,
                      // The cursor always shown while it waits: a pasted sign-in code went in with
                      // nothing to say where (on a rented machine). What runs here may hide
                      // its own; this terminal is for one answer typed by a person.
                      alwaysShowCursor: _session.live,
                      readOnly: !_session.live,
                      padding: const EdgeInsets.all(Space.small),
                      textStyle: const TerminalStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
            const TerminalPasteHint(),
            // A link left on offer after it ended invites doing it all again.
            if (_session.state != SessionState.over) TerminalLinks(session: _session),
            if (_session.state != SessionState.over) ...<Widget>[
              const SizedBox(height: Space.small),
              Text(widget.stillWorking, key: const Key('unlock-working')),
            ],
            if (_session.state == SessionState.over) ...<Widget>[
              const SizedBox(height: Space.small),
              Text(
                _cameOfIt ??
                    _session.problem ??
                    (widget.completed != null && _session.exitCode == 0 ? widget.completed : null) ??
                    (widget.whatCameOfIt == null
                        ? 'The terminal has ended. What came of it is asked of the machine when this is '
                              'put away.'
                        : 'The terminal has ended. Asking the machine what came of it…'),
                key: const Key('unlock-ended'),
                style: _cameOfIt == null ? null : Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ],
        ),
      ),
    ),
    // Done once it has ended; before that only ending it early, asked first, and never the
    // filled button: a sign-in nearly ended by a press while its image was building.
    actions: <Widget>[
      if (_session.state == SessionState.over)
        FilledButton(
          key: const Key('unlock-done'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        )
      else
        TextButton(key: const Key('unlock-cancel'), onPressed: _cancelIt, child: Text(widget.cancel)),
    ],
  );
}
