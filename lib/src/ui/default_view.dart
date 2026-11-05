import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_backend.dart';
import '../app/forge.dart';
import '../app/run_here.dart';
import 'first_start_view.dart';
import 'pick_a_file.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// What a checkout is picked with: the desktop's folder dialog, stood in for in tests.
PickAFolder pickACheckout = pickFolderWithTheDesktop;

/// Opens the repositories a machine works on in the Default project.
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
  bool thisComputer = false,
  Future<void> Function(String project, List<String> notes)? onStartProject,
}) => showDialog<void>(
  context: context,
  builder: (_) => DefaultDialog(
    machine: machine,
    machineName: machineName,
    pickAtAForge: pickAtAForge,
    onStartWork: onStartWork,
    thisComputer: thisComputer,
    onStartProject: onStartProject,
    pickAFolder: pickACheckout,
  ),
);

/// `default`: what a machine works on in the Default project, with Porelo's own settings, fixed.
class DefaultDialog extends StatefulWidget {
  /// Constructor taking the machine and what it is called.
  const DefaultDialog({
    required this.machine,
    required this.machineName,
    this.pickAtAForge,
    this.onStartWork,
    this.thisComputer = false,
    this.onStartProject,
    this.pickAFolder = pickFolderWithTheDesktop,
    this.runGit = runHere,
    super.key,
  });

  /// The machine whose `default` this is.
  final FleetBackend machine;

  /// Its name, as the person reads it.
  final String machineName;

  /// Lets the person pick a repository at a forge set up here, or null where none is.
  final Future<({ForgeRepository repository, Forge forge})?> Function()? pickAtAForge;

  /// Starts work on the repository named, once it is in `default`; null where the dialog only lists
  /// what is there to take out.
  final Future<void> Function(String repository)? onStartWork;

  /// Whether the machine is the window's own computer: only there is a checkout's question asked, as no
  /// plugin runs on another machine and a path here means nothing there.
  final bool thisComputer;

  /// Starts work by the project a checkout's first start names.
  ///
  /// With the notes of an answer that asked nothing, which have no question to stand above.
  final Future<void> Function(String project, List<String> notes)? onStartProject;

  /// Asks the desktop for a checkout.
  final PickAFolder pickAFolder;

  /// Reads a checkout's origin on this computer.
  final RunHere runGit;

  @override
  State<DefaultDialog> createState() => _DefaultDialogState();
}

class _DefaultDialogState extends State<DefaultDialog> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _name = TextEditingController();
  List<DefaultRepository>? _repositories;

  String? _problem;
  String? _said;

  /// What the plugins said of a checkout whose answer asked nothing.
  List<String> _notes = const <String>[];
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
    final there = (_repositories ?? const <DefaultRepository>[]).where((each) => each.upstream == address).firstOrNull;
    final added = there ?? await widget.machine.addToDefault(address, name: name);
    if (!mounted) return;
    Navigator.of(context).pop();
    unawaited(widget.onStartWork!(added.name));
  });

  /// A checkout of this computer: the same question as a first start in a terminal, and work by what it
  /// answers. Anything but a yes leaves the start as it is without one: its origin in the field.
  Future<void> _fromACheckout() async {
    final checkout = await widget.pickAFolder(title: 'Use this checkout');
    if (checkout == null || !mounted) return;
    await _asking(() async {
      _said = null;
      _notes = const <String>[];
      final String? project;
      try {
        project = await _projectOf(checkout);
      } on VarlinkException catch (refusal) {
        if (refusal.simpleName != 'FirstStartRefused') rethrow;
        _problem = refusal.parameters['detail'] as String? ?? refusal.simpleName;
        await _fillTheOrigin(checkout);
        return;
      } on FeatureNotSupported {
        _said =
            '${widget.machineName} runs a Porelo that does not ask about a checkout yet, so this start uses '
            'Porelo\u2019s own settings.';
        await _fillTheOrigin(checkout);
        return;
      }
      if (!mounted) return;
      if (project != null) {
        // The dialog goes, and with it this place to read them: they are said where the work starts.
        final notes = _notes;
        Navigator.of(context).pop();
        unawaited(widget.onStartProject!(project, notes));
      } else {
        await _fillTheOrigin(checkout);
      }
    });
  }

  /// The project to start in, or null where this start goes on as it is without one.
  Future<String?> _projectOf(String checkout) async {
    final first = await widget.machine.firstStart(checkout);
    if (!mounted) return null;
    if (!first.asks) _notes = first.notes;
    if (first.asks) {
      if (first.hash.isEmpty) {
        _said = 'The machine asked nothing that a yes could name, so nothing was written.';
        return null;
      }
      if (await askFirstStart(context, first: first) != true) {
        _said = 'Nothing was written or kept, and the next start in this checkout asks again.';
        return null;
      }
      return widget.machine.confirmFirstStart(checkout, first.hash);
    }
    if (first.outcome == FirstStart.known || first.outcome == FirstStart.notDefault) {
      if (first.project.isNotEmpty) return first.project;
    }
    _said = switch (first.outcome) {
      'NO_PLUGIN' =>
        'No plugin on this computer can read this checkout, so this start uses Porelo\u2019s own settings.',
      'NOTHING_RECOGNIZED' => 'Nothing in this checkout was recognized, so this start uses Porelo\u2019s own settings.',
      _ => null,
    };
    return null;
  }

  /// The address a start without a project works on, read from [checkout]; said where there is none.
  Future<void> _fillTheOrigin(String checkout) async {
    final Ran origin;
    try {
      origin = await widget.runGit('git', const <String>['remote', 'get-url', 'origin'], inDirectory: checkout);
    } on Object {
      _problem ??= 'Git could not read this checkout\u2019s origin here, so name its address below.';
      return;
    }
    if (!mounted) return;
    final address = origin.out.trim();
    if (origin.code != 0 || address.isEmpty) {
      _problem ??= 'This checkout names no origin, so name its address below.';
      return;
    }
    setState(() => _address.text = address);
  }

  Future<void> _remove(DefaultRepository repository) => _asking(() async {
    final done = await widget.machine.removeFromDefault(repository.name);
    _said = done.removed
        ? '${repository.name} is out of default. Its mirror, and anything waiting in it, stay on ${widget.machineName}.'
        : '${repository.name} was not in default any more.';
    if (done.keys.isNotEmpty) _said = <String>[_said!, for (final key in done.keys) key.title].join(' ');
    final found = await widget.machine.defaultRepositories();
    if (mounted) setState(() => _repositories = found);
  });

  /// Fills the address field from a forge, the other way to name the same repository.
  Future<void> _pick() async {
    final picked = await widget.pickAtAForge?.call();
    if (picked == null || !mounted) return;
    setState(() {
      _address.text = picked.repository.httpsUrl;
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
      title: Text(starting ? 'Start work in the Default project' : 'Repositories of the Default project'),
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
              for (final (at, note) in _notes.indexed) SelectableText(note, key: ValueKey<String>('default-note $at')),
              if (_busy) const Text('Asking the machine… Any failure will appear here.'),
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
                if (widget.thisComputer && widget.onStartProject != null) ...<Widget>[
                  const SizedBox(height: Space.tight),
                  OutlinedButton(
                    key: const Key('default-checkout'),
                    onPressed: _busy ? null : () => unawaited(_fromACheckout()),
                    child: const Text('Use a checkout on this computer'),
                  ),
                  const SizedBox(height: Space.tight),
                ],
                if (!widget.thisComputer)
                  Text(
                    'Nothing is detected on ${widget.machineName}: work there uses what the repository holds, and '
                    'with no project.yml in it, Porelo\u2019s own settings.',
                    key: const Key('default-nothing-detected'),
                    style: text.bodySmall,
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
