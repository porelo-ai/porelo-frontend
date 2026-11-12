import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';
import 'package:xterm/xterm.dart';

import 'connections.dart';
import 'conpty.dart';
import 'desk.dart';
import 'links.dart';
import 'login_forward.dart';
import 'machines.dart';
import 'modified_keys.dart';
import 'pty.dart';
import 'quiet_after_dispose.dart';
import 'wsl.dart';

/// Puts text on this computer's clipboard. Injectable, so a test records what a program copied.
typedef CopyToClipboard = Future<void> Function(String text);

/// What a terminal's program copies goes here: the desktop's clipboard.
CopyToClipboard copyToClipboard = (text) => Clipboard.setData(ClipboardData(text: text));

/// How a terminal is opened. Injectable, so everything above it runs without a process.
typedef OpenTerminal = SessionChannel Function(String executable, List<String> arguments, {int columns, int rows});

/// The terminal a session opens on this computer when it is given none.
SessionChannel openHere(String executable, List<String> arguments, {int columns = 80, int rows = 24}) => desk.isWindows
    ? ConPty.start(executable, arguments, columns: columns, rows: rows)
    : Pty.start(executable, arguments, columns: columns, rows: rows);

/// Why work cannot be worked in by hand, decided before anything is started.
///
/// **Predicted rather than discovered.** `Task` says whether a task is running and how somebody
/// is meant to be involved with it, so both of these are answerable without asking the machine —
/// which is the difference between an action offered as unavailable with a reason and an action
/// that fails after somebody presses it.
enum WhyNot {
  /// It is not up. The way back is starting it again, which keeps the workspace it had.
  notRunning,

  /// Reached through a socket something else forwarded, so nothing here can run a shell there.
  noAddress;

  /// What to say, in a sentence somebody can act on.
  String get words => switch (this) {
    WhyNot.notRunning =>
      'This is not running. Starting it again brings back the workspace, the branch and the '
          'commits it had — and a session with it.',
    WhyNot.noAddress =>
      'This machine is reached through a socket something else forwarded, so a session has '
          'nowhere to run. Add it with "Connect over ssh for me" and its address.',
  };
}

/// Where one session has got to.
enum SessionState {
  /// The way in is being opened.
  opening,

  /// It is open, and what is typed reaches it.
  live,

  /// The far end is gone. [Session.problem] says whether that was ordinary or not.
  over,
}

/// The terminal's colours as a program asks for them, the same as `TerminalLook.darkConsole`.
const _background = 'rgb:0505/0505/0c0c';
const _foreground = 'rgb:e8e8/ecec/ffff';

/// One session against one piece of work.
///
/// **The session is not this object and does not end with it.** What is being drawn here is a way
/// in to `tmux new-session -A -s porelo` inside the container: closing this window leaves that
/// running, and opening it again finds the same session rather than a new one. Everything on
/// screen has to keep saying so, because the opposite assumption — that leaving ends things — is
/// what stops people leaving.
class Session extends ChangeNotifier with QuietAfterDispose {
  /// Opens one against [task] on [machine].
  Session({
    required this.task,
    required this.machine,
    OpenTerminal? open,
    int columns = 80,
    int rows = 24,
    this.run,
    this.forwardsALoginReply = false,
    this.startedAt,
    Duration Function()? clock,
  }) : _open = open ?? openHere,
       _now = clock ?? _monotonic() {
    terminal = Terminal(maxLines: scrollback)
      ..inputHandler = CascadeInputHandler(<TerminalInputHandler>[
        _modifiedKeys,
        ModifiedCursorKeys(),
        defaultInputHandler,
      ])
      ..onOutput = _typed
      ..onResize = _resized
      ..onPrivateOSC = _hyperlink;
    _start(columns, rows);
  }

  /// Which container, as `List` reports it and as every other method takes it.
  final String task;

  /// When the task was started, as its listing says, or null when it does not. What its agent
  /// shows from before then is an earlier start's, however current it looks.
  final DateTime? startedAt;

  /// Which machine it is on. Named on screen because two machines can have a task of the same
  /// name.
  final Machine machine;

  final OpenTerminal _open;

  /// Time on a clock that never goes back, for how long ago the person last acted here.
  final Duration Function() _now;

  static Duration Function() _monotonic() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// When the person last pressed a key, pressed or released the mouse, or pasted in this terminal, and no write
  /// has used it since; null otherwise.
  Duration? _ownActionAt;

  /// What the task asked to put on this computer's clipboard on its own, waiting for the person to allow it.
  HeldCopy? get held => _held;
  HeldCopy? _held;

  /// The person's own action in this terminal, a pointer pressed or released or a paste. **Never what the terminal
  /// sends itself** — an answer to the far end's question, a mouse or focus report — which a task could ask for.
  void ownAction() => _ownActionAt = _now();

  /// A key the person pressed in this terminal: only the first press, so a held key does not keep the way open.
  void ownKey(KeyEvent event) {
    if (event is KeyDownEvent && !event.synthesized) ownAction();
  }

  /// Puts [copy] on this computer's clipboard, the person having allowed it — only while it is the one shown.
  void copyHeld(HeldCopy copy) {
    if (!live || !identical(copy, _held)) return;
    _held = null;
    notifyListeners();
    unawaited(copyToClipboard(copy.text));
  }

  /// Forgets [copy], the person having refused it.
  void dropHeld(HeldCopy copy) {
    if (!identical(copy, _held)) return;
    _held = null;
    notifyListeners();
  }

  /// Whether this terminal runs an agent's login, and so may ask for its reply to be forwarded.
  /// **Only such a terminal**: a work session asking for a port would be a container opening a way
  /// from this computer into the machine.
  final bool forwardsALoginReply;

  /// The port a login's reply is forwarded on while this is open, or null.
  int? forwarded;

  /// Why the login's reply could not be forwarded, or null.
  String? forwardProblem;

  HeldForward? _forward;

  /// A command of its own instead of attaching to [task] — the wizard's `porelo vault init`, typed
  /// into by a person so the passphrase never passes through this program.
  final List<String>? run;

  /// What is on the screen at the far end.
  late final Terminal terminal;

  final ModifiedKeys _modifiedKeys = ModifiedKeys();

  /// Where it has got to.
  SessionState state = SessionState.opening;

  /// Web addresses the far end marked as links (OSC 8), newest last — offered to be opened here,
  /// never opened by themselves. An agent's login prints its page this way.
  final List<TerminalLink> links = <TerminalLink>[];

  /// The machine's `OSC 5379;forward;<port>`: the port its login listens on for the browser's reply.
  void _forwardTheReply(List<String> arguments) {
    if (!live || !forwardsALoginReply || arguments.length != 2 || arguments.first != 'forward') return;
    final port = int.tryParse(arguments.last);
    // One port, once, and never a privileged one: the login's reply, nothing else.
    if (port == null || port < 1024 || port > 65535 || forwarded != null || _forward != null) return;
    forwarded = port;
    notifyListeners();
    unawaited(() async {
      try {
        final held = await raiseForward(machine, port);
        if (_gone || state == SessionState.over) {
          await held.close();
          return;
        }
        _forward = held;
      } on ForwardRefused catch (refused) {
        forwarded = null;
        forwardProblem = refused.words;
        if (!_gone) notifyListeners();
      } on Object {
        // Raised or taken down after the session went: nobody is left to tell.
        forwarded = null;
        if (!_gone) notifyListeners();
      }
    }());
  }

  /// The program's own copy (OSC 52, as tmux's `set-clipboard on` sends it), for this computer's clipboard.
  /// **Writing only**: a request to read the clipboard (`?`) is never answered, since that would hand whatever was
  /// copied here to the container. **Without a word only right after the person's own action here**, once per
  /// action; any other write is held for the person to allow, since a task's text pasted into a shell runs there.
  void _copied(List<String> arguments) {
    if (!live || arguments.length != 2) return;
    final [selection, encoded] = arguments;
    // Only the clipboard, which an empty selection means too: another, written here, would land on it as well.
    final forTheClipboard = selection.isEmpty || selection.contains('c');
    if (!forTheClipboard || encoded.isEmpty || encoded == '?' || encoded.length > _mostCopied) return;
    final String text;
    try {
      text = utf8.decode(base64.decode(base64.normalize(encoded)), allowMalformed: true);
    } on FormatException {
      return;
    }
    if (text.isEmpty) return;
    final acted = _ownActionAt;
    if (acted != null && _now() - acted <= _silentAfterOwnAction) {
      _ownActionAt = null;
      if (_held != null) {
        _held = null;
        notifyListeners();
      }
      unawaited(copyToClipboard(text));
      return;
    }
    _held = HeldCopy(text);
    notifyListeners();
  }

  /// How long after the person's own action a write is taken as theirs. It proves time, not cause.
  static const Duration _silentAfterOwnAction = Duration(seconds: 2);

  /// How much a program may copy at once, in base64: more than any selection, less than a flood.
  static const int _mostCopied = 1 << 20;

  void _hyperlink(String code, List<String> arguments) {
    // Left or put away: what the closing program still prints is read for its last line, never acted on here.
    if (_gone) return;
    if (code == '5379') return _forwardTheReply(arguments);
    // A program choosing its colours asks: the terminal is dark whatever the window's theme.
    if ((code == '10' || code == '11') && arguments.singleOrNull == '?') {
      return type('\x1b]$code;${code == '11' ? _background : _foreground}\x1b\\');
    }
    if (code == '52') return _copied(arguments);
    final link = hyperlinkOf(code, arguments);
    if (link == null || links.contains(link)) return;
    links.add(link);
    notifyListeners();
  }

  /// What went wrong, in words. Null while nothing has.
  ///
  /// **Never a rewording of what the far end said.** `porelo` and `ssh` both say why in their own
  /// sentences, and those are already on the terminal where somebody can read them; what this
  /// adds is what kind of ending it was, which the terminal cannot say.
  String? problem;

  /// The actual process exit code, also one that arrived while it was left; absent while no process ended.
  int? exitCode;

  /// Whether its program was started: one that never was did nothing, any other may have done anything.
  bool get started => _started;
  bool _started = false;

  SessionChannel? _channel;
  StreamSubscription<List<int>>? _reading;

  /// Whether this has been left. An ending that arrives afterwards is not news.
  bool _gone = false;

  /// Whether it is open and can be typed into; never once it was left.
  bool get live => !_gone && state == SessionState.live;

  /// What the command line would be. Public so a test and a person can read the same thing.
  ///
  /// **`ssh -t`, because the far end has to be a terminal.** For a machine somebody else forwards
  /// — a socket path and no host — there is nothing to ssh to, so the verb is run here. Both are
  /// the same command with a different way of reaching it.
  ///
  /// Ordinary SSH machines allow a prompt here; managed hosts keep their pinned batch policy. A
  /// forward has no terminal, so a prompt there is a hang; this *is* a terminal, so a passphrase
  /// can be answered by the person sitting in front of it.
  List<String> get command => machine.host.startsWith('-')
      ? throw const PtyRefused('A machine’s ssh address must not start with a dash.')
      : run ??
            (machine.relay?.kind == 'wsl'
                ? Wsl.runIn(machine.distribution, <String>['porelo', 'task', 'attach', task])
                : machine.needsATunnel
                ? <String>[
                    openSsh('ssh'),
                    ...machine.loginSshOptions,
                    '-t',
                    machine.host,
                    inTheLoginShell('porelo task attach ${quoteForAShell(task)}'),
                  ]
                : <String>['porelo', 'task', 'attach', task]);

  /// Reports one turn of the mouse wheel to the far end as an SGR wheel report, the way tmux reads
  /// it: up is button 64, down 65.
  ///
  /// **For Windows only.** Through a Windows pseudoconsole the terminal never learns that tmux
  /// asked for the mouse, since the pseudoconsole draws the screen again rather than passing on
  /// what tmux wrote; so the terminal would answer the wheel itself, with nothing to scroll.
  void wheel({required bool up}) => type('\x1b[<${up ? 64 : 65};1;1M');

  /// Tells the far end that this terminal gained or lost the keyboard, as xterm does once it asked for it
  /// (`ESC [ ? 1004 h`): tmux passes it on to the program in the task.
  void focused({required bool gained}) {
    if (terminal.reportFocusMode) type(gained ? '\x1b[I' : '\x1b[O');
  }

  /// Sends what somebody typed. Does nothing once it is over, rather than throwing into a widget.
  void type(String input) {
    if (!live) return;
    _channel?.send(input);
  }

  /// Ends this way in.
  ///
  /// **The work inside is untouched.** The multiplexer is a process in the container, so this
  /// closes the channel and the session it reaches carries on — which is why nothing here says
  /// *stop*.
  Future<void> leave() async {
    _gone = true;
    _held = null;
    final reading = _reading;
    _reading = null;
    final channel = _channel;
    _channel = null;
    final forward = _forward;
    _forward = null;
    // The channel is closed whatever its forward did: a terminal left open keeps its program and its handles.
    await _closeForward(forward);
    try {
      await channel?.close();
    } finally {
      // Read until the channel closed or its bound passed: a program that answers as it ends prints its last line
      // then. **The cancel is not waited on.** Canceling a subscription to a broadcast stream settles a turn later,
      // and waiting for it put whatever follows behind the frame that had already reported the session gone.
      unawaited(reading?.cancel());
    }
  }

  /// Takes down a login's forward, which leaving goes on past whatever it threw.
  static Future<void> _closeForward(HeldForward? forward) async {
    try {
      await forward?.close();
    } on Object {
      // A forward that would not close is no reason to keep the terminal open.
    }
  }

  @override
  void dispose() {
    unawaited(_leaveUnwaited());
    super.dispose();
  }

  /// Leaves for whoever does not wait on it: a program that outlives the close has nobody here to tell.
  Future<void> _leaveUnwaited() async {
    try {
      await leave();
    } on Object {
      // Whoever must count it as running, or hear why it would not close, waits on [leave] itself.
    }
  }

  void _start(int columns, int rows) {
    try {
      final channel = _open(command.first, command.skip(1).toList(), columns: columns, rows: rows);
      _channel = channel;
      _started = true;
      state = SessionState.live;
      // Decoded as a stream: a chunk can end in the middle of a character, and a decoder per
      // chunk would put a replacement mark on screen every few kilobytes of anything but ASCII.
      _reading = channel.output.listen(
        (bytes) => terminal.write(_modifiedKeys.take(const Utf8Decoder(allowMalformed: true).convert(bytes))),
      );
      unawaited(channel.ended.then(_itEnded));
    } on PtyRefused catch (refused) {
      state = SessionState.over;
      problem = machine.needsATunnel
          ? 'The way in could not be opened: ${refused.words}.'
          : 'The way in could not be opened: ${refused.words}. A session lives in the container, '
                'so it is reachable only from the machine the daemon runs on.';
    }
    notifyListeners();
  }

  void _typed(String data) => type(data);

  void _resized(int width, int height, int pixelWidth, int pixelHeight) =>
      _channel?.resize(columns: width, rows: height);

  void _itEnded(int code) {
    // Closing the channel ends the far end, so an exit code arrives *after* somebody has left —
    // by which time this is disposed and notifying would throw into whatever is drawing. The code is
    // still kept: what the program did before it ended is not undone by leaving.
    if (_gone) {
      exitCode ??= code;
      return;
    }
    _held = null;
    // The login is over, so its reply has nothing left to reach.
    exitCode = code;
    final forward = _forward;
    _forward = null;
    unawaited(_closeForward(forward));
    state = SessionState.over;
    problem = switch (code) {
      0 => null,
      _refused => 'The machine would not open a session here. What it said is above.',
      _sshFailed => 'The connection to ${machine.name} failed. What ssh said is above.',
      _hungUp => null,
      _ => 'The session ended with $code. What it said is above.',
    };
    notifyListeners();
  }

  /// What `porelo task attach` refuses with, for both of its reasons.
  static const int _refused = 69;

  /// The code of a refusal; a terminal running one command words it itself, since that opens no session.
  static const int refusedCode = _refused;

  /// ssh's own code for "the connection did not happen".
  static const int _sshFailed = 255;

  /// 128 + SIGHUP: this side closed the channel, which is not a failure.
  static const int _hungUp = 129;

  /// How much a session can show of what happened while nobody was watching.
  ///
  /// **10,000 lines, and the figure is Porelo's rather than ours.** It is written into
  /// `/etc/porelo/tmux.conf` when the image is built and read explicitly by `task attach`, so a
  /// base image or somebody's dotfile cannot change it underneath the one process that has to
  /// state it. Confirmed as `09cae48`; before that it was tmux's default, a number
  /// nobody had chosen.
  ///
  /// The window's own buffer is the same figure deliberately: one that held less than a
  /// re-attached session replays would scroll away what coming back had just shown.
  static const int scrollback = 10000;
}

/// The one session that is open. It is shown in its tab under *Work* > *Running*, and nowhere else.
///
/// **One at a time**: several open at once, drawn as chips
/// over one terminal, made leaving one look like leaving all. Opening another leaves this one — the
/// work behind it carries on, and opening it again shows its last lines.
class Sessions extends ChangeNotifier {
  /// Constructor. [openTerminal] stands in for a real one in tests.
  Sessions({this.openTerminal});

  /// How a terminal is opened. Null means a real pty.
  final OpenTerminal? openTerminal;

  Session? _current;

  /// The session that is open, or null.
  Session? get current => _current;

  /// Whether one is open.
  bool get any => _current != null;

  /// Why [task] cannot be worked in by hand, or null when it can.
  ///
  /// **The mode is not a reason.** This end refused `AGENT` and `UNATTENDED` once,
  /// on the strength of *"the agent is the main process, so there is no session to
  /// attach to"*. That was wrong, and the Porelo side said so: **`AGENT` and `SHELL` are the same
  /// task** — same container, same egress, same gate, same credential — and `--attach agent` only
  /// runs the agent's binary first and drops into the shell when it exits. Attaching starts its
  /// own `tmux` by `podman exec`, which does not care what the container's main process is.
  ///
  /// So the refusal took the action away from the commonest kind of task there is, with a reason
  /// that was not true. An `UNATTENDED` run is the one where nobody is expected to be watching —
  /// which is a thing to know, not a thing to forbid, and the log is a suggestion rather than a
  /// substitute.
  static WhyNot? whyNot(Task task, Machine machine) {
    if (!task.running) return WhyNot.notRunning;
    // A local command reaches only this machine's daemon; a forwarded socket's tasks are elsewhere.
    if (machine.host.isEmpty && machine.socketPath != Backend.local().socketPath) {
      return WhyNot.noAddress;
    }
    return null;
  }

  /// Opens the session against [task] on [machine], and returns it.
  ///
  /// **The same work again returns what is there**: one container holds one session, and a second way
  /// in would draw the same screen twice. **Other work leaves the one that was open** without asking —
  /// nothing at the far end stops.
  Session openOn(String task, Machine machine, {DateTime? startedAt}) {
    final open = _current;
    if (open != null && open.task == task && open.machine == machine && open.startedAt == startedAt) return open;
    if (open != null) unawaited(_end(open));
    final session = Session(task: task, machine: machine, open: openTerminal, startedAt: startedAt);
    _current = session;
    notifyListeners();
    return session;
  }

  /// Closes the way in. The work it reached carries on.
  Future<void> leave() async {
    final open = _current;
    if (open == null) return;
    _current = null;
    notifyListeners();
    await _end(open);
  }

  /// Closes the way in, for a window that is being shut.
  Future<void> leaveAll() => leave();

  Future<void> _end(Session session) async {
    try {
      await session.leave();
    } on TerminalStillRunning {
      // The way into work that carries on anyway; nothing waits on its end.
    } finally {
      session.dispose();
    }
  }

  @override
  void dispose() {
    final open = _current;
    _current = null;
    if (open != null) unawaited(_end(open));
    super.dispose();
  }
}

/// What a task asked to put on this computer's clipboard on its own. Compared by identity: allowing one copies that
/// one, never one that replaced it in the meantime.
class HeldCopy {
  /// Constructor taking the decoded text.
  HeldCopy(this.text);

  /// The text as it would be written.
  final String text;
}
