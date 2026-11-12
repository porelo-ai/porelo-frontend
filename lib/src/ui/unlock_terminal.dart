import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../app/machines.dart';
import '../app/pty.dart' show TerminalStillRunning;
import '../app/session.dart';
import 'dialog_scroll.dart';

import 'package:guided_walk/guided_walk.dart';

import 'session_terminal.dart';
import 'tokens.dart';
import 'terminal_copy.dart';
import 'terminal_links.dart';
import 'terminal_look.dart';

/// Opens [machine]'s vault by its passphrase, typed into a terminal running [command] there, or fed by it from the
/// secrets file where [explanation] says so.
///
/// The only way from here to a vault nothing has opened yet: unlocking with a device needs the
/// device enrolled, and enrolling needs the vault open. Returns once the dialog is put away.
Future<void> unlockInATerminal(
  BuildContext context, {
  required Machine machine,
  required List<String> command,
  OpenTerminal? open,
  String? explanation,
}) => runInATerminal(
  context,
  title: 'Open the vault on ${machine.name}',
  explanation:
      explanation ??
      "Type the vault's passphrase into the terminal. It goes straight to the machine "
          'and never through this program, and nothing here keeps it.',
  machine: machine,
  command: command,
  open: open,
);

/// What a terminal's program did, as far as this side saw it: whether it was started, and its exit code, also one
/// that arrived while the terminal closed; no code when none was seen.
typedef TerminalEnd = ({bool started, int? code});

/// Runs [command] on [machine] in a terminal a person types into, for a value this program must
/// never hold. Returns once the dialog is put away, with what its program did; what came of it is
/// asked of the machine then.
/// [onExit] reports a process exit, never cancellation; [completed] is shown only after exit zero.
/// [showCommand] hides the line behind Details when false.
/// [shownCommand] can show a readable command when the actual argument list uses a shell parameter.
/// With [waitsOnItsProgram], a program that outlives the close is thrown as a [TerminalStillRunning],
/// for a caller that counts it as running until it ended; any other caller is not told of it.
Future<TerminalEnd> runInATerminal(
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
  bool showCommand = true,
  String? completed,
  Future<bool> Function(int code)? finish,
  Future<void> Function()? afterClose,
  ValueChanged<String>? lastLine,
  bool waitsOnItsProgram = false,
  bool answersForTheWindow = false,
  Key? key,
}) async {
  final closed = Completer<TerminalEnd>();
  // Handled from the start: its program outliving the close would otherwise be an error nobody handles.
  unawaited(closed.future.then<void>((_) {}, onError: (Object _) {}));
  var built = false;
  // Not waited on: a navigator that goes away with the terminal open never returns from the dialog, so the end comes
  // from the terminal's own going away, and whatever its caller holds for it is let go of then too.
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _UnlockTerminal(
      key: key,
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
      showCommand: showCommand,
      completed: completed,
      finish: finish,
      afterClose: afterClose,
      lastLine: lastLine,
      answersForTheWindow: answersForTheWindow,
      built: () => built = true,
      closing: (leaving) => leaving.then(closed.complete, onError: closed.completeError),
    ),
  );
  unawaited(
    dialog.then<void>(
      (_) {
        // Put away before it was ever built: nothing was started, and no terminal will say so.
        if (!built && !closed.isCompleted) closed.complete((started: false, code: null));
      },
      onError: (Object _) {
        if (!built && !closed.isCompleted) closed.complete((started: false, code: null));
      },
    ),
  );
  try {
    return await closed.future;
  } on TerminalStillRunning {
    if (waitsOnItsProgram) rethrow;
    return (started: true, code: null);
  }
}

/// Takes the last thing [terminal] shows off its screen if it is a JSON object, however many rows it wrapped over: an
/// answer for the program, not the person. Anything else stays, for it may be all a failure said.
@visibleForTesting
void eraseJsonAnswer(Terminal terminal) {
  final lines = terminal.buffer.lines;
  var last = lines.length - 1;
  while (last >= 0 && lines[last].getText().trim().isEmpty) {
    last--;
  }
  if (last < 0) return;
  var first = last;
  while (first > 0 && lines[first].isWrapped) {
    first--;
  }
  final text = [for (var row = first; row <= last; row++) lines[row].getText()].join().trim();
  try {
    if (jsonDecode(text) is! Map) return;
  } on FormatException {
    return;
  }
  // The cursor cannot climb above the screen, so rows that scrolled past its top are blanked where they stand.
  for (var row = first; row < terminal.buffer.scrollBack && row <= last; row++) {
    lines[row]
      ..eraseRange(0, lines[row].length, terminal.cursor)
      ..isWrapped = false;
  }
  final up = terminal.buffer.absoluteCursorY - first;
  terminal.write('\r${up > 0 ? '\x1b[${up}A' : ''}\x1b[J');
}

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
    this.showCommand = true,
    this.completed,
    this.finish,
    this.afterClose,
    this.lastLine,
    this.answersForTheWindow = false,
    required this.built,
    required this.closing,
    super.key,
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
  final bool showCommand;
  final String? completed;
  final Future<bool> Function(int code)? finish;
  final Future<void> Function()? afterClose;

  /// Told the terminal's last line with text when its command ends, before [finish]: what a failed command said last.
  final ValueChanged<String>? lastLine;

  /// Its command ends on a JSON answer meant for this program, taken off the screen once read, unless it is a refusal.
  final bool answersForTheWindow;
  final ValueChanged<Future<TerminalEnd>> closing;

  /// Told once the terminal is made, so a dialog put away before that ends with nothing started.
  final VoidCallback built;

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
    widget.built();
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
  bool _finishing = false;
  late bool _showCommand = widget.showCommand;

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final code = _session.exitCode;
    if (!_reportedExit && code != null) {
      _reportedExit = true;
      widget.onExit?.call(code);
      _tellLastLine();
      if (widget.answersForTheWindow && code == 0) eraseJsonAnswer(_session.terminal);
      if (widget.finish case final finish?) {
        _finishing = true;
        unawaited(() async {
          try {
            final verified = await finish(code);
            if (mounted && verified) _closeOwnRoute();
          } on Exception {
            if (mounted) setState(() => _cameOfIt = 'The terminal check could not complete.');
          } finally {
            if (mounted) setState(() => _finishing = false);
          }
        }());
      }
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

  /// Tells [_UnlockTerminal.lastLine] the terminal's last line with text.
  void _tellLastLine() {
    final told = widget.lastLine;
    if (told == null) return;
    final term = _session.terminal;
    final shown = copiedText(
      term,
      BufferRangeLine(CellOffset(0, 0), CellOffset(term.viewWidth - 1, term.buffer.height - 1)),
    );
    told(shown.split('\n').map((line) => line.trimRight()).lastWhere((line) => line.isNotEmpty, orElse: () => ''));
  }

  /// Closes this terminal's dialog, together with a cancel confirmation still open above it.
  void _closeOwnRoute() {
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    if (!route.isCurrent) navigator.popUntil((each) => each == route);
    navigator.pop();
  }

  @override
  void dispose() {
    final started = _session.started;
    widget.closing(
      _session.leave().then((_) async {
        // A program that ended while its terminal closed may still have done its work: what it did is said on.
        final code = _session.exitCode;
        if (!_reportedExit && code != null) {
          _reportedExit = true;
          widget.onExit?.call(code);
          _tellLastLine();
        }
        await widget.afterClose?.call();
        return (started: started, code: code);
      }),
    );
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
            if (!widget.showCommand)
              TextButton(
                onPressed: () => setState(() => _showCommand = !_showCommand),
                child: Text(_showCommand ? 'Hide details' : 'Details'),
              ),
            if (_showCommand)
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
                    child: SessionTerminal(
                      session: _session,
                      viewKey: const Key('unlock-terminal'),
                      theme: TerminalLook.theme,
                      controller: _selection,
                      focusNode: _keyboard,
                      // The cursor always shown while it waits: a pasted sign-in code went in with
                      // nothing to say where (on a rented machine). What runs here may hide
                      // its own; this terminal is for one answer typed by a person.
                      alwaysShowCursor: _session.live,
                      padding: const EdgeInsets.all(Space.small),
                      textStyle: const TerminalStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
            const TerminalPasteHint(),
            TerminalCopyAsk(session: _session),
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
                    (_session.exitCode == Session.refusedCode
                        ? 'The machine refused this. What it said is above.'
                        : _session.problem) ??
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
          onPressed: _finishing ? null : () => Navigator.of(context).pop(),
          child: const Text('Done'),
        )
      else
        TextButton(key: const Key('unlock-cancel'), onPressed: _cancelIt, child: Text(widget.cancel)),
    ],
  );
}
