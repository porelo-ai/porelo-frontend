import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_backend.dart';
import '../app/forge.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Opens the repositories a machine works on without a project.
///
/// With [onStartWork], it is **the one way to start work in `default`**:
/// a repository is named — typed, or picked at a forge beside the field — and work starts
/// on it, the repository going into `default` on the way. Without it, it lists what is there to take
/// out. [pickAtAForge] opens the person's repositories at a forge, and hands the one picked back with
/// the forge it is on.
Future<void> showTheDefault(
  BuildContext context, {
  required FleetBackend machine,
  required String machineName,
  Future<({ForgeRepository repository, Forge forge})?> Function()? pickAtAForge,
  Future<void> Function(String repository)? onStartWork,
  Future<({Forge forge, String fullName})?> Function(String upstream)? forgeHolding,
}) => showDialog<void>(
  context: context,
  builder: (_) => DefaultDialog(
    machine: machine,
    machineName: machineName,
    pickAtAForge: pickAtAForge,
    onStartWork: onStartWork,
    forgeHolding: forgeHolding,
  ),
);

/// `default`: what a machine works on without a project, with Porelo's own settings, fixed.
class DefaultDialog extends StatefulWidget {
  /// Constructor taking the machine and what it is called.
  const DefaultDialog({
    required this.machine,
    required this.machineName,
    this.pickAtAForge,
    this.onStartWork,
    this.forgeHolding,
    super.key,
  });

  final FleetBackend machine;
  final String machineName;
  final Future<({ForgeRepository repository, Forge forge})?> Function()? pickAtAForge;

  /// Starts work on the repository named, once it is in `default`; null where the dialog only lists
  /// what is there to take out.
  final Future<void> Function(String repository)? onStartWork;

  /// The forge set up here that holds [upstream], with its `owner/name` there, or null.
  final Future<({Forge forge, String fullName})?> Function(String upstream)? forgeHolding;

  @override
  State<DefaultDialog> createState() => _DefaultDialogState();
}

class _DefaultDialogState extends State<DefaultDialog> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _name = TextEditingController();
  List<DefaultRepository>? _repositories;

  /// The repository picked at a forge, while the address field still holds its address: the machine
  /// gets a key of its own there when work starts on it.
  ({ForgeRepository repository, Forge forge})? _picked;

  /// The keys a repository taken out left at its forge, to be removed there on request.
  ({Forge forge, String repository, List<MachineDeployKey> keys})? _keysLeft;
  String? _problem;
  String? _said;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void dispose() {
    _address.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _read() => _asking(() async {
    final found = await widget.machine.defaultRepositories();
    if (mounted) setState(() => _repositories = found);
  });

  /// Puts [address] into `default`, unless it is there already, and starts work on it.
  Future<void> _startOn(String address, {String? name}) => _asking(() async {
    final picked = _picked?.repository.sshUrl == address ? _picked : null;
    // Where the repository is at a forge set up here, the machine gets a key of its own there,
    // as working on a project gives it - picked or not, and before it goes into default: a row
    // started from, or a first try whose key was refused, left the machine with none and the
    // start refused by GitHub (on a rented machine).
    final at = picked != null
        ? (forge: picked.forge, fullName: picked.repository.fullName)
        : await widget.forgeHolding?.call(address);
    final there = (_repositories ?? const <DefaultRepository>[]).where((each) => each.upstream == address).firstOrNull;
    final added = there ?? await widget.machine.addToDefault(address, name: name);
    if (at != null) {
      final key = await widget.machine.deployKey(defaultProject, repository: added.name);
      final held = await at.forge.deployKeys(at.fullName);
      if (!held.any((each) => _keyPart(each.key) == _keyPart(key.publicKey))) {
        await at.forge.addDeployKey(at.fullName, title: key.title, key: key.publicKey, readOnly: false);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    unawaited(widget.onStartWork!(added.name));
  });

  Future<void> _remove(DefaultRepository repository) => _asking(() async {
    final done = await widget.machine.removeFromDefault(repository.name);
    _said = done.removed
        ? '${repository.name} is out of default. Its mirror, and anything waiting in it, stay on ${widget.machineName}.'
        : '${repository.name} was not in default any more.';
    // The key the machine forgot still opens the repository at its forge until it is removed there.
    final forge = done.keys.isEmpty ? null : await widget.forgeHolding?.call(repository.upstream);
    _keysLeft = forge == null ? null : (forge: forge.forge, repository: forge.fullName, keys: done.keys);
    final found = await widget.machine.defaultRepositories();
    if (mounted) setState(() => _repositories = found);
  });

  /// Removes the keys the machine forgot at the forge they were registered at.
  Future<void> _removeKeysThere() => _asking(() async {
    final left = _keysLeft;
    if (left == null) return;
    var removed = 0;
    for (final held in await left.forge.deployKeys(left.repository)) {
      if (left.keys.any((each) => _keyPart(each.publicKey) == _keyPart(held.key))) {
        await left.forge.removeDeployKey(left.repository, held.id);
        removed++;
      }
    }
    _said = removed == 0
        ? 'Its key was not at ${left.forge.name} any more.'
        : '${widget.machineName}’s key to ${left.repository} is removed at ${left.forge.name}.';
    _keysLeft = null;
  });

  static String _keyPart(String key) => key.trim().split(RegExp(r'\s+')).take(2).join(' ');

  /// Fills the address field from a forge, the other way to name the same repository.
  Future<void> _pick() async {
    final picked = await widget.pickAtAForge?.call();
    if (picked == null || !mounted) return;
    setState(() {
      _picked = picked;
      _address.text = picked.repository.sshUrl;
    });
  }

  Future<void> _asking(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await action();
    } on VarlinkException catch (refusal) {
      _problem = '${widget.machineName} refused it: ${refusal.parameters['message'] ?? refusal.simpleName}.';
    } on FeatureNotSupported {
      _problem = '${widget.machineName} runs a Porelo with no default project yet. Update Porelo there.';
    } on ForgeRefused catch (refused) {
      _problem = refused.words;
    } on VarlinkDisconnected catch (ex) {
      _problem = 'Lost contact with ${widget.machineName}: ${ex.message}';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final repositories = _repositories;
    final starting = widget.onStartWork != null;
    final address = _address.text.trim();
    return AlertDialog(
      key: const Key('default-dialog'),
      title: Text(starting ? 'Start work without a project' : 'Repositories worked on without a project'),
      content: SizedBox(
        width: Sizes.dialog,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'A repository here is worked on without writing a project first, with Porelo’s own settings, '
                'which cannot be changed: guarded, the default image, no connection beyond what the agent '
                'needs to reach its provider, and no messages to or from other work. Approved work goes to '
                'the repository’s origin. Whoever needs anything else makes a project repository.',
                key: const Key('default-fixed'),
                style: text.bodySmall,
              ),
              const SizedBox(height: Space.small),
              if (_problem != null)
                Text(
                  _problem!,
                  key: const Key('default-problem'),
                  style: TextStyle(color: scheme.error),
                ),
              if (_said != null) Text(_said!, key: const Key('default-said')),
              if (_keysLeft case final left?)
                TextButton(
                  key: const Key('default-remove-key'),
                  onPressed: _busy ? null : () => unawaited(_removeKeysThere()),
                  child: Text('Remove ${widget.machineName}’s key to ${left.repository} at ${left.forge.name} too'),
                ),
              if (repositories == null && _problem == null) const Text('Asking the machine…'),
              if (repositories != null && repositories.isEmpty && !starting)
                const Text('No repository yet.', key: Key('default-none')),
              if (starting && (repositories ?? const <DefaultRepository>[]).isNotEmpty)
                Text('One worked on before', style: text.titleSmall),
              for (final each in repositories ?? const <DefaultRepository>[])
                ListTile(
                  key: ValueKey<String>('default-repository ${each.name}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(each.name),
                  subtitle: Text(
                    each.claimedBy.isEmpty
                        ? each.comesFromAndGoes
                        : '${each.comesFromAndGoes} · ${each.claimedBy} names it too: its next task starts there, '
                              'so it can be taken out of default',
                  ),
                  // Taking one out is offered when starting too: since Default left Projects, this is the
                  // one place a repository named by its address is taken out again (walk 10).
                  trailing: starting
                      ? Wrap(
                          spacing: Space.tight,
                          children: <Widget>[
                            TextButton(
                              key: ValueKey<String>('default-start ${each.name}'),
                              onPressed: _busy ? null : () => unawaited(_startOn(each.upstream)),
                              child: const Text('Start work on it'),
                            ),
                            IconButton(
                              key: ValueKey<String>('default-remove ${each.name}'),
                              tooltip: each.claimedBy.isEmpty ? 'Take it out' : 'Take it out of default',
                              icon: const Icon(Icons.remove_circle_outline, size: Sizes.rowIcon),
                              onPressed: _busy ? null : () => unawaited(_remove(each)),
                            ),
                          ],
                        )
                      : TextButton(
                          key: ValueKey<String>('default-remove ${each.name}'),
                          onPressed: _busy ? null : () => unawaited(_remove(each)),
                          child: Text(each.claimedBy.isEmpty ? 'Take it out' : 'Take it out of default'),
                        ),
                ),
              if (starting) ...<Widget>[
                const SizedBox(height: Space.small),
                Text(
                  (repositories ?? const <DefaultRepository>[]).isEmpty ? 'Which repository' : 'Or another one',
                  style: text.titleSmall,
                ),
                // Two ways to fill the same field, side by side: typed, or picked at a forge.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const Key('default-address'),
                        controller: _address,
                        decoration: const InputDecoration(labelText: 'Its address, as git reaches it'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (widget.pickAtAForge != null) ...<Widget>[
                      const SizedBox(width: Space.small),
                      OutlinedButton(
                        key: const Key('default-pick'),
                        onPressed: _busy ? null : () => unawaited(_pick()),
                        child: const Text('or pick it at a forge'),
                      ),
                    ],
                  ],
                ),
                TextField(
                  key: const Key('default-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'What its tasks name it (optional)'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('default-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(starting ? 'Cancel' : 'Done'),
        ),
        if (starting)
          FilledButton(
            key: const Key('default-start-new'),
            onPressed: _busy || address.isEmpty
                ? null
                : () => unawaited(_startOn(address, name: _name.text.trim().isEmpty ? null : _name.text.trim())),
            child: const Text('Start work on it'),
          ),
      ],
    );
  }
}
