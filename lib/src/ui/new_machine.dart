import 'package:flutter/material.dart';
import 'package:guided_walk/guided_walk.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' hide Terminal;

import '../app/machine_setup.dart';
import '../app/session.dart';
import '../app/setup_run.dart';
import 'host_key_dialog.dart';
import 'tokens.dart';
import 'terminal_copy.dart';
import 'terminal_look.dart';

/// The steps of a new machine, or of a new user on a machine prepared before, drawn from a
/// [SetupRun]. **The run holds everything**, so this can be rebuilt, left and come back to without
/// losing a word; going back, on and finishing are the dialog's buttons.
class NewMachineSteps extends StatefulWidget {
  /// Constructor taking the run and what to do when something new is printed.
  const NewMachineSteps({required this.run, this.onGrew, this.openTerminal, super.key});

  /// What was said and done, and what is being done.
  final SetupRun run;

  /// Called when output grew, so the dialog can scroll to it.
  final VoidCallback? onGrew;

  /// How a terminal is opened; null means a real pty.
  final OpenTerminal? openTerminal;

  @override
  State<NewMachineSteps> createState() => _NewMachineStepsState();
}

class _NewMachineStepsState extends State<NewMachineSteps> {
  late final _private = TextEditingController(text: widget.run.privateKey);
  late final _public = TextEditingController(text: widget.run.publicKey);
  late final _host = TextEditingController(text: widget.run.host);
  int _grown = 0;

  /// The terminal the vault's passphrase is typed into, while it is open.
  Session? _vault;
  Session? _drive;
  final _driveEmail = TextEditingController();
  late final _tresor = TextEditingController(text: widget.run.tresor);
  final _selection = TerminalController();

  /// The private keys in `~/.ssh`, read once when the steps are drawn.
  late final List<String> _keys = widget.run.setup.sshKeys();

  SetupRun get run => widget.run;

  @override
  void initState() {
    super.initState();
    // Typing redraws: whether a key can be kept depends on both fields being filled.
    _private.addListener(() => setState(() => run.privateKey = _private.text));
    _public.addListener(() => setState(() => run.publicKey = _public.text));
    _host.addListener(() {
      if (run.host == _host.text) return;
      run.host = _host.text;
      run.changed();
    });
    run.addListener(_follow);
  }

  /// Keeps the fields in step with the run, and scrolls when something new was printed.
  void _follow() {
    if (!mounted) return;
    if (_private.text != run.privateKey) _private.text = run.privateKey;
    if (_public.text != run.publicKey) _public.text = run.publicKey;
    final grown = run.output.length + run.log.length + (run.said == null ? 0 : 1);
    if (grown != _grown) {
      _grown = grown;
      widget.onGrew?.call();
    }
    setState(() {});
  }

  /// Opens the terminal for `porelo vault init`. **The passphrase goes keyboard → terminal → ssh →
  /// porelo**; this program never holds it. When the terminal ends, the daemon is asked.
  void _openVault() {
    final machine = run.ready;
    if (machine == null) return;
    final session = Session(task: 'vault', machine: machine, open: widget.openTerminal, run: run.vaultCommand);
    var asked = false;
    session.addListener(() {
      if (!mounted) return;
      setState(() {});
      if (session.state == SessionState.over && !asked) {
        asked = true;
        run.checkVault();
      }
    });
    // Opening it again replaces the one before, which is closed rather than left holding its terminal.
    final before = _vault;
    setState(() => _vault = session);
    before?.dispose();
    _selection.clearSelection();
  }

  /// Opens the terminal for Tresorit's own sign-in, as the work user. **The password goes keyboard → terminal → ssh →
  /// Tresorit's client**; this program never holds it. When the terminal ends, the client is asked who is signed in.
  void _openDrive() {
    final machine = run.ready;
    if (machine == null || !SetupRun.isEmail(_driveEmail.text)) return;
    final session = Session(
      task: 'drive',
      machine: machine,
      open: widget.openTerminal,
      run: run.driveLoginCommand(_driveEmail.text),
    );
    var asked = false;
    session.addListener(() {
      if (!mounted) return;
      setState(() {});
      if (session.state == SessionState.over && !asked) {
        asked = true;
        run.checkDriveLogin();
      }
    });
    final before = _drive;
    setState(() => _drive = session);
    before?.dispose();
    _selection.clearSelection();
  }

  @override
  void dispose() {
    _vault?.dispose();
    _drive?.dispose();
    _driveEmail.dispose();
    _tresor.dispose();
    _selection.dispose();
    run.removeListener(_follow);
    _private.dispose();
    _public.dispose();
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      ...switch (run.step) {
        SetupStep.key => run.addingAUser ? _knownKeyStep(context) : _keyStep(context),
        SetupStep.where => _whereStep(context),
        SetupStep.prepare => _prepareStep(context),
        SetupStep.reach => _reachStep(context),
        SetupStep.vault => _vaultStep(context),
        SetupStep.drive => _driveStep(context),
        SetupStep.harden => _hardenStep(context),
      },
      if (run.busy) ...<Widget>[
        const SizedBox(height: Space.normal),
        Row(
          children: <Widget>[
            const SizedBox.square(
              dimension: Sizes.mark,
              child: CircularProgressIndicator(strokeWidth: Sizes.spinnerStroke),
            ),
            const SizedBox(width: Space.small),
            Expanded(child: Text(run.doing!, key: const Key('setup-doing'))),
          ],
        ),
      ],
      if (run.said != null) ...<Widget>[
        const SizedBox(height: Space.normal),
        SelectableText(
          run.said!,
          key: const Key('setup-said'),
          style: TextStyle(color: run.saidIsBad ? Theme.of(context).colorScheme.error : null),
        ),
      ],
    ],
  );

  Widget _title(BuildContext context, String words) => Text(words, style: Theme.of(context).textTheme.labelLarge);

  List<Widget> _knownKeyStep(BuildContext context) => <Widget>[
    _title(context, '1. The admin key root logs in with'),
    const SizedBox(height: Space.small),
    Text(
      'The key the machine already knows for root — for one this wizard prepared, '
      '~/.ssh/porelo-<its name>-admin. It is used only to set ${run.workUser} up; '
      '${run.workUser} gets a key of its own.',
    ),
    const SizedBox(height: Space.normal),
    _keyPicker(context, use: 'use-key'),
  ];

  /// The keys in `~/.ssh` to choose from, by name, and the button that uses the chosen one.
  Widget _keyPicker(BuildContext context, {required String use}) {
    if (_keys.isEmpty) {
      return const Text('There is no key in ~/.ssh yet.', key: Key('no-existing-key'));
    }
    final chosen = _keys.contains(run.keyFile) ? run.keyFile : null;
    return Wrap(
      spacing: Space.small,
      runSpacing: Space.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        DropdownButton<String>(
          key: const Key('existing-key'),
          value: chosen,
          hint: const Text('Choose a key'),
          onChanged: run.kept != null || run.busy ? null : (file) => setState(() => run.keyFile = file ?? ''),
          items: <DropdownMenuItem<String>>[
            for (final file in _keys) DropdownMenuItem<String>(value: file, child: Text(file.split('/').last)),
          ],
        ),
        if (run.kept == null)
          FilledButton.tonal(
            key: Key(use),
            onPressed: run.busy || chosen == null ? null : run.useKey,
            child: const Text('Use this key'),
          ),
      ],
    );
  }

  List<Widget> _keyStep(BuildContext context) => <Widget>[
    _title(context, '1. The admin key'),
    const SizedBox(height: Space.small),
    const Text(
      "Root's key, for setting the machine up — by this wizard now, and by a person later. The "
      'interface never uses it to reach the machine day to day: each user that runs work gets a '
      'key of its own. Generate one, paste one, or use one already in ~/.ssh; none may have a '
      'passphrase, since this interface never asks for one.',
    ),
    const SizedBox(height: Space.normal),
    // A private key: blanked, and left out of what a walk writes down. A field of several
    // lines cannot be obscured.
    WalkSecret(
      child: TextField(
        key: const Key('new-private-key'),
        controller: _private,
        enabled: run.kept == null,
        maxLines: 3,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        decoration: const InputDecoration(
          labelText: 'Private key',
          hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
          border: OutlineInputBorder(),
        ),
      ),
    ),
    const SizedBox(height: Space.normal),
    TextField(
      key: const Key('new-public-key'),
      controller: _public,
      enabled: run.kept == null,
      maxLines: 2,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      decoration: InputDecoration(
        labelText: 'Public key',
        hintText: 'ssh-ed25519 AAAA…',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          key: const Key('copy-public-key'),
          icon: const Icon(Icons.copy_outlined, size: Sizes.rowIcon),
          tooltip: 'Copy the public key',
          onPressed: _public.text.trim().isEmpty
              ? null
              : () => Clipboard.setData(ClipboardData(text: _public.text.trim())),
        ),
      ),
    ),
    const SizedBox(height: Space.normal),
    if (run.kept == null)
      Wrap(
        spacing: Space.small,
        children: <Widget>[
          OutlinedButton.icon(
            key: const Key('generate-key'),
            onPressed: run.busy ? null : run.generate,
            icon: const Icon(Icons.key_outlined, size: Sizes.rowIcon),
            label: const Text('Generate a key pair'),
          ),
          FilledButton.tonal(
            key: const Key('keep-key'),
            onPressed: run.busy || _private.text.trim().isEmpty || _public.text.trim().isEmpty ? null : run.keep,
            child: Text('Keep it as ~/.ssh/${run.keyName}'),
          ),
        ],
      ),
    if (run.kept == null) ...<Widget>[
      const SizedBox(height: Space.normal),
      Text('Or use a key you already have', style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: Space.tight),
      _keyPicker(context, use: 'use-existing-key'),
    ] else ...<Widget>[
      const Text(
        'Give this admin key to the provider when the server is created — for Hetzner, under '
        "SSH keys. A key added afterwards cannot reach a machine that only knows root's.",
        key: Key('give-the-public-key'),
      ),
      const SizedBox(height: Space.small),
      SelectableText(
        _public.text.trim(),
        key: const Key('public-key-to-copy'),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
    ],
  ];

  List<Widget> _whereStep(BuildContext context) => <Widget>[
    _title(context, '2. Where it is'),
    const SizedBox(height: Space.small),
    const Text(
      'Once the server exists, its name or address. The wizard logs in as root with the key '
      'above; nothing is changed on the machine yet.',
    ),
    const SizedBox(height: Space.normal),
    TextField(
      key: const Key('new-host'),
      controller: _host,
      decoration: const InputDecoration(
        labelText: 'Server name or IP address',
        hintText: '203.0.113.10',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: Space.normal),
    OutlinedButton.icon(
      key: const Key('try-root-login'),
      onPressed: run.busy || _host.text.trim().isEmpty
          ? null
          : () => run.tryRoot((check) => confirmHostKey(context, check)),
      icon: const Icon(Icons.login, size: Sizes.rowIcon),
      label: const Text('Try logging in as root'),
    ),
  ];

  List<Widget> _prepareStep(BuildContext context) => <Widget>[
    _title(context, '3. Preparing it'),
    const SizedBox(height: Space.small),
    Text(
      run.addingAUser
          ? "Porelo's setup script runs as root. Porelo is there already, so it creates the user "
                '${run.workUser} beside the others, with its own daemon and vault. It shows every '
                'command before it runs; nothing changes until you run it.'
          : "Porelo's setup script runs as root. It creates the user ${run.workUser}, which runs "
                'work, and installs Porelo and whatever you choose below: agents, and for messages '
                'between work the Matrix transport and a homeserver of the machine’s own. It shows '
                'every command before it runs; nothing changes until you run it.',
    ),
    const SizedBox(height: Space.normal),
    if (!run.addingAUser)
      OutlinedButton.icon(
        key: const Key('list-packages'),
        onPressed: run.busy || run.prepared ? null : run.listPackages,
        icon: const Icon(Icons.checklist, size: Sizes.rowIcon),
        label: const Text('See what it can install'),
      ),
    if (run.offered != null || run.addingAUser) ...<Widget>[
      const SizedBox(height: Space.small),
      for (final package in run.offered ?? const <InstallablePackage>[])
        CheckboxListTile(
          key: Key('package-${package.name}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: package.installed || run.chosen.contains(package.name),
          // Already there is shown, ticked and fixed, rather than hidden: a person should see
          // what the machine has.
          onChanged: package.installed || run.prepared
              ? null
              : (on) {
                  on == true ? run.chosen.add(package.name) : run.chosen.remove(package.name);
                  run.changed();
                },
          title: Text(
            <String>[
              package.name,
              if (package.version.isNotEmpty) package.version,
              if (package.installed) 'installed',
            ].join(' · '),
          ),
          subtitle: Text(
            <String>[
              if (package.kind.isNotEmpty) package.kind,
              if (package.description.isNotEmpty) package.description,
            ].join(': '),
          ),
        ),
      if (run.choiceLacks case final lacks?)
        Text(
          lacks,
          key: const Key('setup-choice-lacks'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: Space.normal),
      Terminal(text: MachineSetup.show(run.workUser, run.chosen.toList()..sort()), id: 'fetch-script'),
      const SizedBox(height: Space.small),
      OutlinedButton.icon(
        key: const Key('show-setup'),
        onPressed: run.busy || run.prepared ? null : run.show,
        icon: const Icon(Icons.visibility_outlined, size: Sizes.rowIcon),
        label: const Text('Show what it would do'),
      ),
    ],
    if (run.shown != null) ...<Widget>[
      const SizedBox(height: Space.normal),
      Terminal(text: run.shown!, id: 'setup-shown'),
      const SizedBox(height: Space.small),
      if (run.shownFor != run.choice && !run.prepared)
        const Text('The choice changed since this was shown. Show it again before it runs.', key: Key('show-again'))
      else
        FilledButton.icon(
          key: const Key('run-setup'),
          onPressed: run.busy || run.prepared ? null : run.prepare,
          icon: const Icon(Icons.play_arrow_outlined, size: Sizes.rowIcon),
          label: const Text('Run it as root'),
        ),
    ],
    // Lines as they arrive while it is asking; once it has answered, the answer is shown where
    // it belongs — the packages above, the commands in their box — and not a second time.
    if (run.busy &&
        run.output.isNotEmpty &&
        (run.outputOf == RootAction.list || run.outputOf == RootAction.show)) ...<Widget>[
      const SizedBox(height: Space.normal),
      Terminal(text: run.output.join('\n'), id: 'asking-output'),
    ],
    // What running it printed: nothing until it was run, and kept once it has.
    if (run.outputOf == RootAction.prepare && run.output.isNotEmpty) ...<Widget>[
      const SizedBox(height: Space.normal),
      Terminal(text: run.output.join('\n'), id: 'setup-output'),
    ],
  ];

  List<Widget> _reachStep(BuildContext context) => <Widget>[
    _title(context, '4. Reaching it as ${run.workUser}'),
    const SizedBox(height: Space.small),
    Text(
      '${run.workUser} gets a key of its own, and logs in with it and nothing else: its password '
      'stays locked, and ssh is told so for ${run.workUser} alone (as root, below). Then Host '
      "${run.alias} goes into ~/.ssh/config with that key — as ${run.workUser}, never root — "
      "Porelo starts in ${run.workUser}'s own session, porelo setup registers its hooks there, "
      'porelo doctor is asked, and it connects the way watching it will.',
    ),
    const SizedBox(height: Space.normal),
    Text('The key ${run.workUser} logs in with', style: Theme.of(context).textTheme.labelMedium),
    const SizedBox(height: Space.tight),
    DropdownButton<String?>(
      key: const Key('user-key'),
      isExpanded: true,
      value: run.userKeyFile,
      onChanged: run.busy || run.ready != null ? null : run.useUserKey,
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(
          value: null,
          child: Text('A new one: ~/.ssh/${run.userKeyName}', overflow: TextOverflow.ellipsis),
        ),
        for (final file in <String>{..._keys, ?run.userKeyFile})
          if (file != run.kept)
            DropdownMenuItem<String?>(
              value: file,
              child: Text(file.split('/').last, overflow: TextOverflow.ellipsis),
            ),
      ],
    ),
    const SizedBox(height: Space.normal),
    Terminal(
      text: MachineSetup.authorize(
        run.workUser,
        run.userPublicKey.isEmpty ? '<the public key of ${run.workUser}>' : run.userPublicKey,
      ),
      id: 'authorize-script',
    ),
    const SizedBox(height: Space.small),
    FilledButton.icon(
      key: const Key('finish-setup'),
      onPressed: run.busy || run.ready != null ? null : run.reach,
      icon: const Icon(Icons.link, size: Sizes.rowIcon),
      label: const Text('Set it up and connect'),
    ),
    if (run.doctorFound != null) ...<Widget>[
      const SizedBox(height: Space.normal),
      Text(
        'It answers and can be watched, but tasks cannot run there yet. porelo doctor found:',
        key: const Key('doctor-found'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      const SizedBox(height: Space.tight),
      Terminal(text: run.doctorFound!.join('\n'), id: 'doctor-found-lines'),
      const SizedBox(height: Space.small),
      OutlinedButton.icon(
        key: const Key('ask-doctor-again'),
        onPressed: run.busy ? null : run.askDoctorAgain,
        icon: const Icon(Icons.refresh, size: Sizes.rowIcon),
        label: const Text('Ask porelo doctor again'),
      ),
    ],
    if (run.messages case final messages?) ...<Widget>[
      const SizedBox(height: Space.normal),
      Text(messages, key: const Key('setup-messages')),
    ],
    if (run.log.isNotEmpty) ...<Widget>[
      const SizedBox(height: Space.normal),
      Terminal(text: run.log.join('\n'), id: 'setup-log'),
    ],
  ];

  List<Widget> _vaultStep(BuildContext context) {
    final vault = _vault;
    return <Widget>[
      _title(context, '5. The vault'),
      const SizedBox(height: Space.small),
      Text(
        'Credentials for work live in a vault on the machine, made with a passphrase you choose. '
        "You type it twice into a terminal below, as ${run.workUser} — it goes straight to the "
        'machine and never through this program. It opens later with that passphrase, or from '
        'this device once it is enrolled.',
      ),
      const SizedBox(height: Space.normal),
      Terminal(text: run.vaultCommand.join(' '), id: 'vault-command'),
      const SizedBox(height: Space.small),
      if (vault == null || vault.state == SessionState.over)
        OutlinedButton.icon(
          key: const Key('open-vault-terminal'),
          onPressed: run.busy || (run.hasVault ?? false) ? null : _openVault,
          icon: const Icon(Icons.terminal, size: Sizes.rowIcon),
          label: Text(vault == null ? 'Open a terminal to make the vault' : 'Open it again'),
        ),
      if (vault != null) ...<Widget>[
        const SizedBox(height: Space.small),
        SizedBox(
          height: Sizes.terminal,
          child: ColoredBox(
            color: TerminalLook.background,
            child: CopiesAsShown(
              terminal: vault.terminal,
              controller: _selection,
              child: TerminalView(
                vault.terminal,
                key: const Key('vault-terminal'),
                controller: _selection,
                shortcuts: terminalShortcuts,
                theme: TerminalLook.theme,
                autofocus: true,
                // A passphrase is typed here blind: the cursor at least says where it goes.
                alwaysShowCursor: vault.live,
                readOnly: !vault.live,
                padding: const EdgeInsets.all(Space.small),
                textStyle: const TerminalStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        const TerminalPasteHint(),
      ],
    ];
  }

  List<Widget> _driveStep(BuildContext context) {
    final drive = _drive;
    return <Widget>[
      _title(context, '6. Your own drive (optional)'),
      const SizedBox(height: Space.small),
      Text(
        'Tresorit, the one drive available today, in ${run.workUser}\'s own account and nobody else\'s: its client '
        'is installed there and syncs one tresor of yours into that user\'s home. Leave it out with Next; nothing '
        'here is needed for the machine to work.',
        key: const Key('drive-explained'),
      ),
      const SizedBox(height: Space.normal),
      if (!run.driveInstalled) ...<Widget>[
        const Text(
          'Tresorit publishes no digest for its installer. It carries its own signature, which the machine checks '
          'against the pinned certificate of Tresorit\'s code signing before any of it runs.',
        ),
        const SizedBox(height: Space.small),
        FilledButton.icon(
          key: const Key('drive-install'),
          onPressed: run.busy ? null : run.installDrive,
          icon: const Icon(Icons.download, size: Sizes.rowIcon),
          label: Text('Install Tresorit for ${run.workUser}'),
        ),
      ] else if (run.driveSignedInAs == null) ...<Widget>[
        TextField(
          key: const Key('drive-email'),
          controller: _driveEmail,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Your Tresorit e-mail',
            helperText: 'Tresorit asks its password and code in the terminal below, never here.',
          ),
        ),
        const SizedBox(height: Space.small),
        if (drive == null || drive.state == SessionState.over)
          OutlinedButton.icon(
            key: const Key('open-drive-terminal'),
            onPressed: run.busy || !SetupRun.isEmail(_driveEmail.text) ? null : _openDrive,
            icon: const Icon(Icons.terminal, size: Sizes.rowIcon),
            label: Text(drive == null ? 'Open a terminal to sign in' : 'Open it again'),
          ),
        if (drive != null) ...<Widget>[
          const SizedBox(height: Space.small),
          SizedBox(
            height: Sizes.terminal,
            child: ColoredBox(
              color: TerminalLook.background,
              child: CopiesAsShown(
                terminal: drive.terminal,
                controller: _selection,
                child: TerminalView(
                  drive.terminal,
                  key: const Key('drive-terminal'),
                  controller: _selection,
                  shortcuts: terminalShortcuts,
                  theme: TerminalLook.theme,
                  autofocus: true,
                  alwaysShowCursor: drive.live,
                  readOnly: !drive.live,
                  padding: const EdgeInsets.all(Space.small),
                  textStyle: const TerminalStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          const TerminalPasteHint(),
        ],
      ] else ...<Widget>[
        Text('Signed in as ${run.driveSignedInAs}.', key: const Key('drive-signed-in')),
        const SizedBox(height: Space.small),
        TextField(
          key: const Key('drive-tresor'),
          controller: _tresor,
          onChanged: (value) {
            run.tresor = value;
            setState(() {});
          },
          decoration: InputDecoration(
            labelText: "The tresor's name in Tresorit",
            helperText: 'It syncs into ~/${run.driveFolder} of ${run.workUser}.',
          ),
        ),
        const SizedBox(height: Space.small),
        FilledButton(
          key: const Key('drive-sync'),
          onPressed: run.busy || !SetupRun.isTresorName(_tresor.text) || run.driveSynced == run.tresor.trim()
              ? null
              : run.syncDrive,
          child: const Text('Sync it'),
        ),
      ],
    ];
  }

  List<Widget> _hardenStep(BuildContext context) => <Widget>[
    _title(context, '7. Closing the way root came in (optional)'),
    const SizedBox(height: Space.small),
    Text(
      'This writes two lines into the ssh server\'s configuration there and reloads it: root can '
      'no longer log in over ssh at all, with any key, and nobody can log in with a password. '
      'No user and no key is deleted; ${run.workUser} keeps logging in with its key.\n\n'
      'Afterwards the wizard cannot add another user to this machine, because that needs root: '
      "it would take the provider's console. Leave it for later if more users are to come.",
      key: const Key('harden-explained'),
    ),
    const SizedBox(height: Space.normal),
    Terminal(text: MachineSetup.harden, id: 'harden-script'),
    const SizedBox(height: Space.small),
    OutlinedButton.icon(
      key: const Key('harden'),
      onPressed: run.busy || run.hardened ? null : run.harden,
      icon: const Icon(Icons.shield_outlined, size: Sizes.rowIcon),
      label: const Text('Turn off root and password login'),
    ),
    if (run.outputOf == RootAction.harden && run.output.isNotEmpty) ...<Widget>[
      const SizedBox(height: Space.normal),
      Terminal(text: run.output.join('\n'), id: 'harden-output'),
    ],
  ];
}

/// A script, or what one printed, shown the way a terminal shows it: light on dark, whatever the
/// theme — it is the far machine's shell, not a part of this window.
class Terminal extends StatelessWidget {
  /// Constructor taking the text and a key for it.
  const Terminal({required this.text, required this.id, super.key});

  /// What is shown.
  final String text;

  /// The key the text is found by.
  final String id;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxHeight: Sizes.terminal),
    decoration: BoxDecoration(color: TerminalLook.background, borderRadius: BorderRadius.circular(Radii.small)),
    padding: const EdgeInsets.all(Space.small),
    child: SingleChildScrollView(
      reverse: true,
      child: SelectableText(
        text.trim(),
        key: Key(id),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: TerminalLook.foreground),
      ),
    ),
  );
}
