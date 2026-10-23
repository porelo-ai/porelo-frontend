import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/connection_trial.dart';
import '../app/desk.dart';
import '../app/fleet_model.dart';
import '../app/host_keys.dart';
import '../app/machine_setup.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import '../app/setup_run.dart';
import '../app/tunnel.dart';
import 'host_key_dialog.dart';
import 'new_machine.dart';
import 'choice_field.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';
import 'wsl_machine.dart';

/// What one machine says about itself: the kind of way in, and whether it is a second way in to
/// a node already listed. **That is asked, not worked out**: a hostname has many spellings, and a
/// forwarded socket looks nothing like a tunnel raised here.
String describeMachine(Machines machines, Machine machine) => '${machine.name}${machineKind(machines, machine)}';

/// What [describeMachine] says after the name: empty for a plain socket.
String machineKind(Machines machines, Machine machine) {
  final also = machines.sameNodeAs(machine);
  final same = also.isEmpty ? '' : '  ·  the same node as ${also.map((each) => each.name).join(', ')}';
  if (desk.isWindows && machine.kind.isEmpty && machine.needsATunnel) return '  ·  reached over ssh$same';
  return machine.needsATunnel ? '  ·  forward raised here$same' : same;
}

/// Whether one machine is answering, in the space of an icon.
class ReachIcon extends StatelessWidget {
  /// Constructor taking the machine's name, its model and the forward raised for it.
  const ReachIcon({required this.name, required this.fleet, this.tunnel, super.key});

  /// The machine, by the name on screen beside it — not the backend's own label, which is what
  /// the transport calls it and need not be what a person does.
  final String name;

  /// The machine's model.
  final FleetModel fleet;

  /// The forward this interface raised for it, or null when somebody else did.
  final Tunnel? tunnel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String words) = switch (fleet.reachability) {
      Reachability.connecting => (Icons.cloud_queue, scheme.outline, 'Connecting'),
      Reachability.connected => (Icons.cloud_done, scheme.primary, 'Answering'),
      Reachability.unreachable => (Icons.cloud_off, scheme.error, 'Not answering'),
      Reachability.incompatible => (Icons.warning_amber_outlined, scheme.error, 'Speaks nothing this build knows'),
    };
    // The transport's own sentence wins over ours. "Host key verification failed" is a different
    // problem from a machine that is simply not there, and only one of them can be acted on.
    final said = tunnel?.words;
    return Tooltip(
      message: said == null ? '$name: $words' : '$name: $said',
      child: Icon(icon, size: Sizes.mark, color: color),
    );
  }
}

/// How a machine is reached, chosen on the wizard's first page.
enum MachineKind {
  /// Its socket is already forwarded, by somebody else.
  forwarded,

  /// This interface raises the forward.
  raiseIt,

  /// A machine just rented, prepared by the wizard.
  newMachine,

  /// Another user that runs work, on a machine the wizard prepared before.
  newUser,

  /// A WSL distribution of this Windows user, reached through `wsl.exe`. Offered on Windows only.
  wsl,
}

/// Asks for another machine to watch, as a wizard: its name and kind first, then what that kind
/// needs.
///
/// **The first two kinds differ in who raises the forward.** A socket somebody else forwarded
/// is opened exactly as it always was — that path has no credential handling in it at all and
/// must keep working untouched. A machine described by where it *is* has its forward raised here,
/// supervised, and taken down when the window closes.
Future<Machine?> askForAMachine(
  BuildContext context, {
  Iterable<String> taken = const <String>[],
  Future<Trial> Function(Machine)? trying,
  Future<Started> Function(Machine)? starting,
  HostKeys? hostKeys,
  MachineSetup? setup,
  String workUser = 'agent',
  MachineKind? only,
  Map<String, Object?>? draft,
  Future<void> Function(Map<String, Object?>? draft)? remember,
  OpenTerminal? openTerminal,
  Future<int?> Function(Machine machine)? countKeyslots,
  Future<String?> Function(String host)? socketAt,
  String? Function()? whyNotLoggedIn,
  VoidCallback? thenConnections,
  bool? onWindows,
  Widget Function(ValueChanged<Machine?> onReady)? wslSteps,
}) => showDialog<Machine>(
  context: context,
  builder: (context) => _AskForAMachine(
    taken: taken.toList(),
    trying: trying,
    starting: starting,
    hostKeys: hostKeys,
    setup: setup,
    workUser: workUser,
    only: only,
    draft: draft,
    remember: remember,
    openTerminal: openTerminal,
    countKeyslots: countKeyslots,
    socketAt: socketAt,
    whyNotLoggedIn: whyNotLoggedIn,
    thenConnections: thenConnections,
    onWindows: onWindows ?? desk.isWindows,
    wslSteps: wslSteps,
  ),
);

class _AskForAMachine extends StatefulWidget {
  const _AskForAMachine({
    required this.taken,
    this.trying,
    this.starting,
    this.hostKeys,
    this.setup,
    this.workUser = 'agent',
    this.only,
    this.draft,
    this.remember,
    this.openTerminal,
    this.countKeyslots,
    this.socketAt,
    this.whyNotLoggedIn,
    this.thenConnections,
    this.onWindows = false,
    this.wslSteps,
  });

  /// Whether this runs on Windows, offering WSL and an existing machine over ssh.
  final bool onWindows;

  /// The WSL way's steps, told the machine once every check passed; null for the real ones.
  final Widget Function(ValueChanged<Machine?> onReady)? wslSteps;

  /// The names already watched. A second with the same name would never be added.
  final List<String> taken;

  /// Tries a machine before it is watched, or null where nothing can.
  final Future<Trial> Function(Machine)? trying;

  /// Starts a daemon on it, when the trial found ssh working and nothing serving.
  final Future<Started> Function(Machine)? starting;

  /// Confirms the host key of a machine reached for the first time, or null where nothing can.
  final HostKeys? hostKeys;

  /// Makes a new machine's key and logs in to it as root, or null where nothing can.
  final MachineSetup? setup;

  /// The user a new machine runs work as, offered for the wizard to change.
  final String workUser;

  /// The one kind this wizard is for, or null to let the person choose: the second wizard, which
  /// only adds a user, is this dialog with [MachineKind.newUser] and nothing else offered.
  final MachineKind? only;

  /// A setup a wizard started and did not finish, offered to be continued.
  final Map<String, Object?>? draft;

  /// Keeps an unfinished setup, or forgets it with null.
  final Future<void> Function(Map<String, Object?>? draft)? remember;

  /// How the vault's terminal is opened; null means a real pty.
  final OpenTerminal? openTerminal;

  /// How many ways into a machine's vault there are, asked over its socket.
  final Future<int?> Function(Machine machine)? countKeyslots;

  /// Where Porelo's socket is for the account a login reaches, asked of that machine; null where
  /// nothing can ask, and the socket must then be typed.
  final Future<String?> Function(String host)? socketAt;

  /// Why the last login [socketAt] tried was refused, in words, or null where ssh did not say.
  final String? Function()? whyNotLoggedIn;

  /// Asks for how the machine connects out to be set up once it is watched — the wizard's last step,
  /// which needs the daemon the wizard has only just made reachable.
  final VoidCallback? thenConnections;

  @override
  State<_AskForAMachine> createState() => _AskForAMachineState();
}

class _AskForAMachineState extends State<_AskForAMachine> {
  final _name = TextEditingController();
  final _socket = TextEditingController();
  final _host = TextEditingController();
  // Empty, never prefilled: the uid is the other machine's, and a guess nobody corrects looks like a
  // machine that never answers. Left empty, it is asked of the machine and shown filled in.
  final _remote = TextEditingController();
  final _nameFocus = FocusNode();
  bool _nameLeft = false;

  /// The content's own scroll, so an answer that lands below the fold is scrolled to.
  final _scroll = ScrollController();

  Trial? _trial;
  String _triedFor = '';
  bool _trying = false;
  int _attempt = 0;

  /// What a start said, kept after the trial that follows it so the two read together.
  String? _startSaid;
  bool _starting = false;

  /// Which kind of machine it is. **Nothing is preselected**: the kinds are different
  /// commitments — one starts a process and owns it, one logs in as root — and a default would
  /// make that choice for somebody.
  MachineKind? _kind;

  /// Whether the person may run commands as root on that machine - sudo, or root logging in. Asked
  /// first: only then is Porelo set up there from here (walk 9); without it, a Porelo
  /// somebody else set up is connected to. **Nothing is preselected.**
  bool? _admin;

  /// Whether this interface raises the forward, for the two kinds that have one to reach.
  bool? get _raiseIt => switch (_kind) {
    MachineKind.forwarded => false,
    MachineKind.raiseIt => true,
    _ => null,
  };

  /// Which page of the wizard is showing: the name and kind, or what that kind needs.
  int _page = 0;

  /// The WSL distribution that passed every check, or null.
  Machine? _wslReady;

  /// The user that runs work, for the two kinds that make one.
  late final _user = TextEditingController(text: widget.workUser);

  bool get _makesAUser => _kind == MachineKind.newMachine || _kind == MachineKind.newUser;

  /// The run of a new machine or a new user: everything its steps said and did.
  SetupRun? _run;

  /// Whether the unfinished setup was put away rather than continued.
  bool _draftDismissed = false;

  /// The unfinished setup this wizard offers to continue, when there is one it can continue.
  Map<String, Object?>? get _offeredDraft {
    final draft = widget.draft;
    if (draft == null || _run != null || _draftDismissed) return null;
    final addsAUser = draft['addingAUser'] == true;
    if (widget.only == MachineKind.newUser && !addsAUser) return null;
    return draft;
  }

  SetupRun _newRun({Map<String, Object?>? from}) {
    final setup = widget.setup ?? MachineSetup();
    final run =
        (from == null
            ? null
            : SetupRun.fromStored(
                from,
                setup: setup,
                hostKeys: widget.hostKeys,
                trying: widget.trying,
                remember: widget.remember,
                countKeyslots: widget.countKeyslots,
              )) ??
        SetupRun(
          name: _name.text.trim(),
          workUser: _user.text.trim(),
          addingAUser: _kind == MachineKind.newUser,
          setup: setup,
          hostKeys: widget.hostKeys,
          trying: widget.trying,
          remember: widget.remember,
          countKeyslots: widget.countKeyslots,
        );
    run.addListener(_runChanged);
    return run;
  }

  void _runChanged() {
    if (mounted) setState(() {});
  }

  /// Goes to the second page, starting a run for the kinds that make a user — or keeping the one
  /// there is, when the first page still says the same, so going back and on loses nothing.
  void _goOn() {
    if (_makesAUser) {
      final run = _run;
      final same =
          run != null &&
          run.name == _name.text.trim() &&
          run.workUser == _user.text.trim() &&
          run.addingAUser == (_kind == MachineKind.newUser);
      if (!same) {
        run?.removeListener(_runChanged);
        _run = _newRun();
      }
    }
    setState(() => _page = 1);
  }

  /// Continues the unfinished setup where it stopped.
  void _continue(Map<String, Object?> draft) {
    final run = _newRun(from: draft);
    _name.text = run.name;
    _user.text = run.workUser;
    setState(() {
      _run = run;
      _kind = run.addingAUser ? MachineKind.newUser : MachineKind.newMachine;
      _page = 1;
    });
  }

  @override
  void initState() {
    super.initState();
    // Every field, not only the socket. The recipe follows what is typed rather than showing an
    // example that has to be edited twice — and *"Watch it"* is enabled by what has been filled
    // in, which without a listener is decided once and never again. It was: the button stayed
    // dead however much was typed.
    _kind = widget.only;
    for (final field in <TextEditingController>[_name, _socket, _host, _remote, _user]) {
      field.addListener(() => setState(() {}));
    }
    // Marked once somebody moves on from the name, not while they are still typing it.
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && !_nameLeft) setState(() => _nameLeft = true);
    });
  }

  /// Which watched machine already has this name, or one that would share its forward.
  String? get _takenBy {
    final wanted = Machine.slug(_name.text.trim());
    if (wanted.isEmpty) return null;
    for (final each in widget.taken) {
      if (Machine.slug(each) == wanted) return each;
    }
    return null;
  }

  /// The line that forwards the socket, with the local end filled in.
  String get _recipe {
    final local = _socket.text.trim().isEmpty ? '/tmp/porelod-remote.sock' : _socket.text.trim();
    return 'ssh -L $local:/run/user/<uid>/porelo/porelod.sock user@host -N';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _page == 0
          ? (widget.only == MachineKind.newUser ? 'Add a user to a machine' : 'Watch another machine')
          : 'Watch ${_name.text.trim()}',
    ),
    content: SizedBox(
      width: Sizes.dialogMedium,
      child: DialogScroll(
        controller: _scroll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _page == 0 ? _firstPage(context) : _secondPage(context),
        ),
      ),
    ),
    actions: <Widget>[
      // While something runs on the machine only Cancel is offered: going back or on in the
      // middle of it would draw a step that is not true yet.
      if (_page > 0)
        TextButton(
          key: const Key('wizard-back'),
          onPressed: _run?.busy ?? false
              ? null
              : () {
                  final run = _run;
                  if (_makesAUser && run != null && !run.isFirst) {
                    run.previous();
                  } else {
                    setState(() => _page = 0);
                  }
                },
          child: const Text('Back'),
        ),
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      if (_page == 0)
        FilledButton(key: const Key('wizard-next'), onPressed: _canGoOn ? _goOn : null, child: const Text('Next'))
      else if (_makesAUser && _run != null && !_run!.isLast)
        FilledButton(
          key: const Key('setup-next'),
          onPressed: _run!.canGoOn && !_run!.busy ? _run!.next : null,
          child: const Text('Next step'),
        )
      else if (_makesAUser && _run != null) ...<Widget>[
        if (widget.thenConnections case final then?)
          OutlinedButton(
            key: const Key('watch-new-then-connections'),
            onPressed: _run!.ready == null || _run!.busy
                ? null
                : () {
                    final machine = _run!.ready!;
                    unawaited(_run!.forget());
                    then();
                    Navigator.of(context).pop(machine);
                  },
            child: const Text('Watch it, then set up how it connects out'),
          ),
        FilledButton(
          key: const Key('watch-new'),
          onPressed: _run!.ready == null || _run!.busy
              ? null
              : () {
                  final machine = _run!.ready!;
                  unawaited(_run!.forget());
                  Navigator.of(context).pop(machine);
                },
          child: const Text('Watch it'),
        ),
      ] else if (!_makesAUser)
        FilledButton(key: const Key('watch-it'), onPressed: _ready ? _watchIt : null, child: const Text('Watch it')),
    ],
  );

  /// The name, and which kind of machine it is.
  List<Widget> _firstPage(BuildContext context) => <Widget>[
    if (_offeredDraft case final draft?) ...<Widget>[
      Container(
        key: const Key('resume-setup'),
        width: double.infinity,
        padding: const EdgeInsets.all(Space.normal),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Setting up ${draft['name']}'
              '${'${draft['host'] ?? ''}'.isEmpty ? '' : ' (${draft['host']})'} was not finished.',
            ),
            const SizedBox(height: Space.small),
            Wrap(
              spacing: Space.small,
              children: <Widget>[
                FilledButton(
                  key: const Key('resume-setup-continue'),
                  onPressed: () => _continue(draft),
                  child: const Text('Continue where it stopped'),
                ),
                TextButton(
                  key: const Key('resume-setup-discard'),
                  onPressed: () {
                    unawaited(widget.remember?.call(null));
                    setState(() => _draftDismissed = true);
                  },
                  child: const Text('Discard it'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.wide),
    ],
    // Always a tooltip, shown only when it has something to say: toggling the wrapper
    // would rebuild the field and take the cursor out of it mid-word.
    TooltipVisibility(
      visible: _takenBy != null,
      child: Tooltip(
        message: 'A machine called ${_takenBy ?? ''} is already watched',
        child: TextField(
          key: const Key('machine-name'),
          controller: _name,
          focusNode: _nameFocus,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'What to call it',
            hintText: 'the build machine',
            errorText: _nameLeft && _takenBy != null ? 'Already taken' : null,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    ),
    if (widget.only == null && widget.onWindows) ...<Widget>[
      const SizedBox(height: Space.wide),
      Text('How to reach it', style: Theme.of(context).textTheme.labelLarge),
      ChoiceField<MachineKind>(
        id: 'machine-kind-choice',
        label: 'How to reach it',
        value: _kind,
        onChanged: (chosen) => setState(() => _kind = chosen),
        choices: const <Choice<MachineKind>>[
          Choice(
            MachineKind.wsl,
            'A WSL distribution on this computer',
            id: 'machine-wsl',
            means: 'Reached through wsl.exe, with no ssh and no open port; only you reach it.',
          ),
          Choice(
            MachineKind.raiseIt,
            'A Porelo already running on a machine over ssh',
            id: 'machine-raise-it',
            means:
                'Reached with Windows OpenSSH and the keys in its agent; a key with a passphrase must be in the agent.',
          ),
        ],
      ),
    ],
    if (widget.only == null && !widget.onWindows) ...<Widget>[
      const SizedBox(height: Space.wide),
      Text('Are you an administrator there?', style: Theme.of(context).textTheme.labelLarge),
      ChoiceField<bool>(
        id: 'machine-admin',
        label: 'Are you an administrator there?',
        value: _admin,
        onChanged: (chosen) => setState(() {
          _admin = chosen;
          // A way that sets the machine up is not left chosen once it is not offered.
          if (chosen == false && _makesAUser) _kind = null;
        }),
        choices: const <Choice<bool>>[
          Choice(
            true,
            'Yes: I may run commands as root there',
            id: 'machine-admin-yes',
            means:
                'With sudo, or because root logs in. Porelo can be set up there from here, every '
                'command shown before it runs.',
          ),
          Choice(
            false,
            'No: somebody else set Porelo up there for me',
            id: 'machine-admin-no',
            means: 'Only connecting to a Porelo that already runs there is offered.',
          ),
        ],
      ),
      if (_admin != null) ...<Widget>[
        const SizedBox(height: Space.normal),
        Text('How to reach it', style: Theme.of(context).textTheme.labelLarge),
        ChoiceField<MachineKind>(
          id: 'machine-kind-choice',
          label: 'How to reach it',
          value: _kind,
          onChanged: (chosen) => setState(() => _kind = chosen),
          choices: <Choice<MachineKind>>[
            const Choice(
              MachineKind.forwarded,
              'Its socket is already forwarded',
              id: 'machine-already-forwarded',
              means:
                  'Nothing is raised and nothing is managed. This is the way in with no '
                  'credential handling anywhere near it.',
            ),
            const Choice(
              MachineKind.raiseIt,
              'Raise the forward for me',
              id: 'machine-raise-it',
              means:
                  'An ssh forward, started here and taken down when this window closes. '
                  'It never asks for a passphrase: use an agent, and accept the host key '
                  'once in a shell.',
            ),
            if (_admin == true)
              const Choice(
                MachineKind.newMachine,
                'A new machine',
                id: 'machine-new',
                means:
                    'Just rented. The wizard makes a key, then logs in as root once to '
                    'prepare it, showing every command before it runs.',
              ),
            if (_admin == true)
              const Choice(
                MachineKind.newUser,
                'Another user on a machine already prepared',
                id: 'machine-new-user',
                means:
                    'Its own daemon, tasks and vault, beside the ones there. Root logs in with '
                    'the key the machine already knows.',
              ),
          ],
        ),
      ],
    ],
    if (_makesAUser) ...<Widget>[
      const SizedBox(height: Space.normal),
      TextField(
        key: const Key('work-user-name'),
        controller: _user,
        decoration: InputDecoration(
          labelText: 'The user that runs work there',
          helperText: "Created by Porelo's setup script, with its own daemon and vault.",
          errorText: Settings.isUserName(_user.text.trim())
              ? null
              : 'Lower-case letters, digits, _ and -, starting with a letter',
          border: const OutlineInputBorder(),
        ),
      ),
    ],
  ];

  /// What the chosen kind needs.
  List<Widget> _secondPage(BuildContext context) => <Widget>[
    if (_kind == MachineKind.wsl) widget.wslSteps?.call(_wslChanged) ?? WslSteps(onReady: _wslChanged),
    if (_makesAUser && _run != null)
      NewMachineSteps(run: _run!, onGrew: _showTheEnd, openTerminal: widget.openTerminal),
    const SizedBox(height: Space.normal),
    if (_raiseIt == true) ...<Widget>[
      TextField(
        controller: _host,
        key: const Key('machine-host'),
        decoration: const InputDecoration(
          labelText: 'Where it is',
          hintText: 'user@build.example.test',
          helperText:
              'Given to ssh as it stands, so anything in your ssh config '
              'works — including a Host alias.',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: Space.normal),
      TextField(
        controller: _remote,
        key: const Key('machine-remote-socket'),
        decoration: InputDecoration(
          labelText: 'Its socket, on that machine',
          hintText: '/run/user/<uid>/porelo/porelod.sock',
          helperText: widget.socketAt == null
              ? 'The uid is that of the user you log in as, on that machine.'
              : 'Leave it empty and the machine is asked where Porelo serves the user you log in as.',
          border: const OutlineInputBorder(),
        ),
      ),
    ] else if (_raiseIt == false) ...<Widget>[
      TextField(
        controller: _socket,
        key: const Key('machine-socket'),
        decoration: const InputDecoration(
          labelText: 'Forwarded socket',
          hintText: '/tmp/porelod-remote.sock',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: Space.normal),
      Text('Forward it first, and this opens it:', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: Space.tight),
      _Recipe(command: _recipe),
      const SizedBox(height: Space.normal),
      Text(
        'A remote Porelo is its own socket, forwarded — same calls, same replies, same '
        'code.',
        key: const Key('how-to-forward'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
    if (_raiseIt != null && widget.trying != null) ..._trialRow(context),
  ];

  /// The button that tries it, and what the last try found while the fields still say the same.
  List<Widget> _trialRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trial = _triedFor == _signature ? _trial : null;
    return <Widget>[
      const SizedBox(height: Space.normal),
      Row(
        children: <Widget>[
          OutlinedButton.icon(
            key: const Key('try-it'),
            onPressed: _canTry && !_trying ? _tryIt : null,
            icon: const Icon(Icons.network_check, size: Sizes.rowIcon),
            label: const Text('Try the connection'),
          ),
          if (_trying) ...<Widget>[
            const SizedBox(width: Space.normal),
            const SizedBox.square(
              dimension: Sizes.mark,
              child: CircularProgressIndicator(strokeWidth: Sizes.spinnerStroke),
            ),
            const SizedBox(width: Space.small),
            const Text('Trying…'),
          ],
        ],
      ),
      if (trial != null) ...<Widget>[
        const SizedBox(height: Space.small),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              trial.reached ? Icons.check_circle_outline : Icons.error_outline,
              size: Sizes.rowIcon,
              color: trial.reached ? scheme.primary : scheme.error,
            ),
            const SizedBox(width: Space.small),
            Expanded(child: SelectableText(trial.words, key: const Key('trial-result'))),
          ],
        ),
      ],
      // Outside the offer, and deliberately: what a start said is worth reading next to the trial
      // that followed it, including the one that then succeeded and took the offer away.
      if (_startSaid != null) ...<Widget>[
        const SizedBox(height: Space.small),
        SelectableText(_startSaid!, key: const Key('start-result')),
      ],
      if (_canStartIt(trial)) ..._offerToStart(context),
    ];
  }

  /// Whether a start is the answer to what the trial found.
  bool _canStartIt(Trial? trial) => trial != null && !trial.reached && trial.nothingServing && widget.starting != null;

  /// The way back to the offer, for somebody who turned it down and changed their mind.
  ///
  /// **One row, and never the question itself.** The question is a dialog, because an offer at the
  /// end of a scrolling panel is an offer nobody sees — which is exactly what happened.
  List<Widget> _offerToStart(BuildContext context) => <Widget>[
    const SizedBox(height: Space.small),
    OutlinedButton.icon(
      key: const Key('offer-again'),
      onPressed: _starting ? null : _askToStart,
      icon: const Icon(Icons.play_arrow_outlined, size: Sizes.rowIcon),
      label: const Text('Start Porelo there'),
    ),
  ];

  /// Asks whether to start it, and starts it on a yes.
  ///
  /// The line is shown in full before the yes and run unchanged after it: this is the interface
  /// reaching further into somebody else's machine than forwarding a socket goes.
  Future<void> _askToStart() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nothing serves on ${_host.text.trim()}. Start Porelo there?', key: const Key('offer-to-start')),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'The forward came up and no daemon answered through it. This logs in and starts '
                'one, as the user you log in as. Nothing else on that machine is touched.',
              ),
              const SizedBox(height: Space.small),
              // There to be read, not in the way: a screen of shell is the first thing somebody new
              // to Porelo would otherwise meet, and the sentence above says what it does.
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('start-command'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Show the command it runs'),
                  children: <Widget>[_Recipe(command: Tunnels.startCommandFor(_described).join(' '))],
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('not-now'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const Key('start-it'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start it'),
          ),
        ],
      ),
    );
    if (!mounted || yes != true) return;
    await _startIt();
  }

  /// Starts it, and tries again by itself: a start nobody verified is a claim, not an answer.
  Future<void> _startIt() async {
    setState(() {
      _starting = true;
      _startSaid = null;
    });
    final started = await widget.starting!(_described);
    if (!mounted) return;
    setState(() {
      _starting = false;
      _startSaid = started.words;
    });
    _showTheEnd();
    if (started.went) await _tryIt(afterAStart: true);
  }

  /// What the fields describe, so an answer about other fields is never shown against these.
  String get _signature => '$_kind|${_host.text.trim()}|${_remote.text.trim()}|${_socket.text.trim()}';

  bool get _canTry {
    if (_raiseIt == null) return false;
    return _raiseIt! ? _host.text.trim().isNotEmpty && _remoteKnowable : _socket.text.trim().isNotEmpty;
  }

  /// Whether the socket on the other machine is typed, or can be asked of it.
  bool get _remoteKnowable => _remote.text.trim().isNotEmpty || widget.socketAt != null;

  /// Fills in the socket on the other machine from the machine itself, when it was left empty.
  ///
  /// False, with the reason where a trial's answer goes, when the machine could not say.
  Future<bool> _remoteAsked() async {
    final asking = widget.socketAt;
    if (_raiseIt != true || _remote.text.trim().isNotEmpty || asking == null) return true;
    final host = _host.text.trim();
    final found = await asking(host);
    if (!mounted) return false;
    if (found != null) {
      setState(() => _remote.text = found);
      return true;
    }
    setState(() {
      _trial = Trial(
        reached: false,
        words:
            'Could not log in to $host to ask where Porelo is for you there. '
            '${widget.whyNotLoggedIn?.call() ?? 'Check that ssh $host works without a question, or type its socket.'}',
      );
      _triedFor = _signature;
    });
    _showTheEnd();
    return false;
  }

  Future<void> _tryIt({bool afterAStart = false}) async {
    final trying = widget.trying!;
    final attempt = ++_attempt;
    setState(() {
      _trying = true;
      // A try somebody asked for is a fresh question: what an earlier start said goes with it.
      // The try that follows a start keeps it — they are one answer.
      if (!afterAStart) _startSaid = null;
    });
    if (!await _hostKeyAccepted() || !await _remoteAsked()) {
      if (mounted && attempt == _attempt) setState(() => _trying = false);
      return;
    }
    // Asked of the machine only now: what was tried is what the fields say after the asking.
    final signature = _signature;
    final trial = await trying(_described);
    if (!mounted || attempt != _attempt) return;
    setState(() {
      _trying = false;
      _trial = trial;
      _triedFor = signature;
    });
    _showTheEnd();
    // Asked rather than left to be found: an offer at the end of a scrolling panel is one nobody
    // sees. Not after a start, which would ask the same question again in a loop.
    if (!afterAStart && _canStartIt(trial)) await _askToStart();
  }

  /// Scrolls to what just arrived. The panel scrolls, and an answer below the fold is no answer.
  void _showTheEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// The machine the fields describe.
  Machine get _described {
    final name = _name.text.trim().isEmpty ? 'new machine' : _name.text.trim();
    return _raiseIt!
        // The local end is ours to choose, and it goes where the runtime directory already
        // makes it owner-only. Asking somebody for a path they do not care about would be one
        // more thing to get almost right.
        ? Machine(
            name: name,
            socketPath: widget.onWindows ? '' : Machine.endpointFor(name),
            host: _host.text.trim(),
            remoteSocket: _remote.text.trim(),
          )
        : Machine(name: name, socketPath: _socket.text.trim());
  }

  /// Whether the first page is answered: a name nobody else has, and a kind.
  bool get _canGoOn =>
      _name.text.trim().isNotEmpty &&
      _kind != null &&
      _takenBy == null &&
      (!_makesAUser || Settings.isUserName(_user.text.trim()));

  void _wslChanged(Machine? ready) {
    if (mounted) setState(() => _wslReady = ready);
  }

  bool get _ready {
    if (_kind == MachineKind.wsl) return _name.text.trim().isNotEmpty && _takenBy == null && _wslReady != null;
    if (_name.text.trim().isEmpty || _raiseIt == null || _takenBy != null) return false;
    return _raiseIt! ? _host.text.trim().isNotEmpty && _remoteKnowable : _socket.text.trim().isNotEmpty;
  }

  Future<void> _watchIt() async {
    if (_kind == MachineKind.wsl) {
      final ready = _wslReady;
      if (ready != null) {
        Navigator.of(context)
            .pop(Machine(name: _name.text.trim(), socketPath: '', kind: 'wsl', distribution: ready.distribution));
      }
      return;
    }
    if (!await _hostKeyAccepted() || !await _remoteAsked() || !mounted) return;
    Navigator.of(context).pop(_described);
  }

  /// Whether the host key of where it is is known, **asking the person when it is not**.
  ///
  /// Before a trial and before watching, because both log in with `BatchMode`, which fails on an
  /// unknown key rather than asking — and accepting it without looking would be the one step a man
  /// in the middle needs. A refusal, or a key that could not be fetched, is said where the trial's
  /// answer goes.
  Future<bool> _hostKeyAccepted() async {
    if (_raiseIt == true && _host.text.trim().startsWith('-')) {
      setState(() {
        _trial = const Trial(reached: false, words: 'An ssh host must not start with a dash.');
        _triedFor = _signature;
      });
      _showTheEnd();
      return false;
    }
    final keys = widget.hostKeys;
    if (keys == null || _raiseIt != true) return true;
    final signature = _signature;
    final check = await keys.checkMachine(_described);
    if (!mounted) return false;
    if (check.known) return true;
    var said = check.problem;
    if (said == null) {
      if (await confirmHostKey(context, check)) {
        await keys.accept(check);
        return true;
      }
      said = 'The host key of ${check.host} was not trusted, so nothing was tried.';
    }
    if (!mounted) return false;
    setState(() {
      _trial = Trial(reached: false, words: said!);
      _triedFor = signature;
    });
    _showTheEnd();
    return false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _socket.dispose();
    _host.dispose();
    _remote.dispose();
    _user.dispose();
    _run?.removeListener(_runChanged);
    _nameFocus.dispose();
    super.dispose();
  }
}

/// The line that raises the forward, ready to be taken to a shell.
///
/// Copyable rather than only readable: it is going to be typed into a terminal, and retyping a
/// socket path from a screen is how a path ends up almost right.
class _Recipe extends StatelessWidget {
  const _Recipe({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.tight, Space.small),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              command,
              key: const Key('forwarding-command'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: Sizes.rowIcon),
            tooltip: 'Copy the command',
            onPressed: () => Clipboard.setData(ClipboardData(text: command)),
          ),
        ],
      ),
    );
  }
}
