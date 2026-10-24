import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/forge.dart';
import '../app/connections.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/machine_binding.dart';
import '../app/project_workspace.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// Opens working on the repository's project on a machine. Answers the project's name where the
/// person asked to start work in it on the machine, and null otherwise.
Future<String?> showBinding(
  BuildContext context,
  MachineBinding binding, {
  bool startFollows = false,
  Machine? terminalMachine,
  OpenTerminal? openTerminal,
  Future<({Forge forge, ProjectWorkspace workspace})?> Function()? changeToken,
}) async {
  final start = await showDialog<String>(
    context: context,
    builder: (_) => BindingDialog(
      binding: binding,
      startFollows: startFollows,
      changeToken: changeToken,
      terminalMachine: terminalMachine,
      openTerminal: openTerminal,
    ),
  );
  binding.dispose();
  return start;
}

/// Working on a project on a machine: one button, said as what the person gets, each step said as
/// it is done. What a project's keys and changes are for later is in `ProjectForgeDialog`.
class BindingDialog extends StatefulWidget {
  /// Constructor taking the binding.
  const BindingDialog({
    required this.binding,
    this.startFollows = false,
    this.changeToken,
    this.terminalMachine,
    this.openTerminal,
    super.key,
  });

  /// What binding the machine to the project knows and does.
  final MachineBinding binding;

  /// The selected machine where the terminal prompt must run.
  final Machine? terminalMachine;

  /// The terminal transport, with a stand-in in tests.
  final OpenTerminal? openTerminal;

  /// Whether starting work follows the binding by itself, the dialog closing on its own once the
  /// machine holds the project; what it pinned is then said
  /// at the foot of the window.
  final bool startFollows;

  /// Opens the forges to change the token, and answers the forge and clone to go on with; null
  /// where nothing is connected then. A refusal for the token's rights is fixed without closing this.
  final Future<({Forge forge, ProjectWorkspace workspace})?> Function()? changeToken;

  @override
  State<BindingDialog> createState() => _BindingDialogState();
}

class _BindingDialogState extends State<BindingDialog> {
  List<SigningKey>? _keys;
  SigningKey? _key;

  /// The keys the forge lists as the person's: all pinned at the follow where the machine takes them.
  List<ForgeSigningKey> _atTheForge = const <ForgeSigningKey>[];
  String? _problem;
  bool _hasProject = false;

  /// Whether the machine's Porelo can do this at all, read before anything is asked of it.
  bool? _canBeBound;

  bool _followed = false;

  /// Closes the dialog with the project once the machine holds it, saying what it pinned: never
  /// where the machine pinned another key than the person's, which is to be read before going on.
  void _follow() {
    final binding = widget.binding;
    final bound = binding.bound;
    if (!widget.startFollows || _followed || bound == null || !mounted) return;
    final key = _key;
    final pinned = binding.pinned;
    final another =
        binding.pinnedAll.isEmpty && pinned != null && pinned.isNotEmpty && key != null && pinned != key.fingerprint;
    if (another) return;
    _followed = true;
    final machine = binding.machineName;
    final said = binding.pinnedAll.length > 1
        ? '$machine accepts changes to the project signed with any of your signing keys at ${binding.forge.name}.'
        : '$machine accepts changes to the project signed with your key.';
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop(bound);
    // What an earlier binding said is put away: this one's words are the ones that matter now.
    messenger?.removeCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        key: const Key('binding-followed'),
        content: Text(<String>[said, ...binding.done].join(' ')),
        duration: const Duration(seconds: 12),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.binding.addListener(_follow);
    unawaited(_open());
  }

  Future<void> _storeToken() async {
    final machine = widget.terminalMachine;
    final host = widget.binding.tokenHost;
    final command = machine == null
        ? null
        : onTheMachine(machine, <String>['porelo', 'vault', 'put', 'git.token.$host'], terminal: true);
    if (command == null) throw const BindingRefused('No terminal can be opened on this machine from here.');
    await runInATerminal(
      context,
      title: 'Connect $host on ${machine!.name}',
      explanation:
          'Enter your own forge token at Porelo’s terminal prompt on ${machine.name}. Its vault keeps it for git over https.',
      machine: machine,
      command: command,
      open: widget.openTerminal,
    );
  }

  Future<void> _open() async {
    try {
      final binding = widget.binding;
      final can = await binding.canBeBound();
      if (mounted) setState(() => _canBeBound = can);
      await binding.workspace.open();
      final text = await binding.workspace.read();
      final held = await binding.workspace.signingKeys();
      final atTheForge = await signingKeysAt(binding.forge, binding.login);
      final ordered = orderSigningKeys(held, atTheForge);
      if (!mounted) return;
      setState(() {
        _hasProject = text != null;
        _keys = ordered.keys;
        _atTheForge = atTheForge;
        // Found, not asked again: the person's key at the forge, the one git signs with, or the only one.
        _key = ordered.chosen;
      });
    } on WorkspaceRefused catch (refused) {
      if (mounted) setState(() => _problem = refused.words);
    }
  }

  /// Changes the token, and goes on with it here: the clone and the keys are read again with it.
  Future<void> _changeToken(Future<({Forge forge, ProjectWorkspace workspace})?> Function() change) async {
    final changed = await change();
    if (changed == null || !mounted) return;
    widget.binding.useToken(changed.forge, changed.workspace);
    setState(() => _problem = null);
    await _open();
  }

  /// Why the button cannot be pressed yet, in words, or null where it can.
  String? _waitsFor(MachineBinding binding) => switch (null) {
    _ when binding.busy => 'Working on it…',
    _ when _canBeBound == false => null,
    _ when _keys == null && _problem == null => 'Getting the project ready on this computer…',
    _ when !_hasProject => null,
    _ when _key == null => 'Choose the key you sign your commits with first.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.binding,
    builder: (context, _) {
      final binding = widget.binding;
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      final keys = _keys;
      final key = _key;
      final pinned = binding.pinned;
      final machine = binding.machineName;
      final forge = binding.forge.name;
      final ready = _hasProject && key != null && !binding.busy && _canBeBound != false;
      final waits = _waitsFor(binding);
      return AlertDialog(
        key: const Key('binding-dialog'),
        title: Text('Work on ${binding.workspace.repository.fullName} on $machine'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$machine uses your own $forge token in its vault for git over https. Enter it in '
                  'a terminal on that machine when asked. It accepts a change to the project only '
                  'when it is signed with your key.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: Space.small),
                if (_canBeBound == false)
                  Text(
                    '$machine runs a Porelo that cannot do this yet. Update the porelo package on $machine '
                    'and restart it (systemctl --user restart porelod), then open this again.',
                    key: const Key('binding-too-old'),
                    style: TextStyle(color: scheme.error),
                  ),
                if (_problem ?? binding.problem case final problem?) ...<Widget>[
                  Text(
                    problem,
                    key: const Key('binding-problem'),
                    style: TextStyle(color: scheme.error),
                  ),
                  if (widget.changeToken case final change?)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const Key('binding-change-token'),
                        onPressed: binding.busy ? null : () => unawaited(_changeToken(change)),
                        child: const Text('Change its token, and go on here'),
                      ),
                    ),
                ],
                if (keys != null && !_hasProject)
                  const Text('It has no project.yml yet: make it a project first.', key: Key('binding-no-project')),
                // Asked only where the forge did not say which key is theirs: the key that signed
                // the project file was asked for again here.
                if (keys != null && keys.length > 1 && key?.atTheForge == null)
                  DropdownButtonFormField<String>(
                    key: const Key('binding-key'),
                    isExpanded: true,
                    initialValue: key?.fingerprint,
                    decoration: const InputDecoration(labelText: 'The key you sign your commits with'),
                    items: <DropdownMenuItem<String>>[
                      for (final each in keys)
                        DropdownMenuItem<String>(
                          value: each.fingerprint,
                          child: Text(
                            '${each.comment.isEmpty ? 'a key with no comment' : each.comment}'
                            '${each.gitSigns ? ' · the one git signs your commits with' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (chosen) => setState(() => _key = keys.firstWhere((each) => each.fingerprint == chosen)),
                  ),
                if (key != null)
                  Text(
                    _atTheForge.isNotEmpty && key.atTheForge != null
                        ? 'Pinned to your signing keys at ${binding.forge.name}: '
                              '${_atTheForge.map((each) => each.title.isEmpty ? 'a key with no title' : '"${each.title}"').join(', ')}. '
                              'Signed here with ${key.words}.'
                        : 'Signed with ${key.comment.isEmpty ? 'your key' : key.comment} (${key.fingerprint})',
                    key: const Key('binding-your-key'),
                    style: text.bodySmall,
                  ),
                // The trust anchor, compared at a glance and never typed: what the machine took
                // beside the key the person signs with. Measured on Porelo 234: a follow that
                // applied may not repeat the fingerprint; not saying it is not a different key.
                if (binding.pinnedAll.length > 1)
                  Text(
                    '$machine accepts changes to the project signed with any of your signing keys at '
                    '${binding.forge.name}: ${binding.pinnedAll.join(', ')}.',
                    key: const Key('binding-anchor'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                else if (pinned != null && key != null)
                  Text(
                    pinned.isEmpty || pinned == key.fingerprint || binding.pinnedAll.isNotEmpty
                        ? '$machine accepts changes to the project signed with your key.'
                        : '$machine took $pinned, which is not your key ${key.fingerprint}. '
                              'Do not go on until you know why.',
                    key: const Key('binding-anchor'),
                    style: pinned.isEmpty || pinned == key.fingerprint
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
                  ),
                if (binding.hostKey case final met?) _HostKeyAtTheForge(binding: binding, met: met),
                for (final (index, each) in binding.done.indexed)
                  Text(each, key: ValueKey<String>('binding-done $index'), style: text.bodySmall),
                if (waits != null && binding.bound == null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.small),
                    child: Text(waits, key: const Key('binding-waits'), style: text.bodySmall),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('binding-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(binding.bound == null ? 'Cancel' : 'Done'),
          ),
          if (binding.bound case final project?)
            FilledButton(
              key: const Key('binding-start'),
              onPressed: () => Navigator.of(context).pop(project),
              child: Text('Start work in $project on $machine'),
            )
          else if (binding.publishedOffer != null && key != null)
            FilledButton(
              key: const Key('binding-trust-host-key'),
              onPressed: binding.busy
                  ? null
                  : () => unawaited(
                      binding.trustPublishedAndBind(
                        key,
                        signers: key.atTheForge != null ? _atTheForge : const <ForgeSigningKey>[],
                      ),
                    ),
              child: Text('Trust ${binding.forge.name}’s published key and go on'),
            )
          else
            FilledButton(
              key: const Key('binding-bind'),
              onPressed: ready && binding.hostKey == null
                  ? () => unawaited(
                      binding.bind(
                        key,
                        signers: key.atTheForge != null ? _atTheForge : const <ForgeSigningKey>[],
                        storeToken: _storeToken,
                      ),
                    )
                  : null,
              child: Text('Work on it on $machine'),
            ),
        ],
      );
    },
  );
}

/// The forge's host, never met by the machine: the keys it offered, and the one the forge publishes
/// for itself over its API, which is what a person would otherwise compare by eye.
class _HostKeyAtTheForge extends StatelessWidget {
  const _HostKeyAtTheForge({required this.binding, required this.met});

  /// What binding the machine to the project knows and does.
  final MachineBinding binding;

  final Followed met;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final machine = binding.machineName;
    final forge = binding.forge.name;
    final offer = binding.publishedOffer;
    final changed = met.outcome == 'HOST_KEY_CHANGED';
    return Column(
      key: const Key('binding-host-key'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: <Widget>[
        Text(
          changed
              ? '$machine met another key at ${met.host} than the one it remembers. That is what somebody in '
                    'between looks like, so nothing is offered to trust: find out why before going on.'
              : '$machine has never met ${met.host}, so it cannot fetch from there yet.',
          style: changed ? TextStyle(color: scheme.error, fontWeight: FontWeight.bold) : text.bodyMedium,
        ),
        for (final each in met.hostKeys)
          SelectableText(
            '${each.type}  ${each.fingerprint}'
            '${binding.published.contains(each.fingerprint) ? '  · $forge publishes this key' : ''}',
            key: ValueKey<String>('binding-host-key ${each.fingerprint}'),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        if (!changed)
          Text(
            offer != null
                ? '$forge publishes ${offer.fingerprint} as its own, read over its API rather than the '
                      'connection $machine was offered it on. Trusting it lets $machine fetch from ${met.host}.'
                : binding.published.isEmpty
                ? '$forge could not be asked which keys it publishes, so nothing is trusted from here: '
                      'compare one with what $forge publishes, at $machine’s terminal.'
                : 'None of these is a key $forge publishes for itself, so nothing is offered to trust.',
            key: const Key('binding-host-key-says'),
            style: text.bodySmall,
          ),
      ],
    );
  }
}
