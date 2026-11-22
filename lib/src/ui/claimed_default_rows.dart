import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_backend.dart';
import 'tokens.dart';

/// The repositories of `default` that a project of the organization names now, on each machine given: their next task
/// starts in that project, and each is offered for leaving `default`, asked once. A running task keeps its project.
class ClaimedDefaultRows extends StatefulWidget {
  /// Reads `default` of each of [machines].
  const ClaimedDefaultRows({required this.machines, super.key});

  /// The machines answering now, each by the name the person reads.
  final List<({String name, FleetBackend backend})> machines;

  @override
  State<ClaimedDefaultRows> createState() => _ClaimedDefaultRowsState();
}

class _ClaimedDefaultRowsState extends State<ClaimedDefaultRows> {
  /// Each machine's repositories of `default` a project names, by the machine's name.
  final _claimed = <String, List<NamedDefaultRepository>>{};

  /// What a leaving came to, by `machine/repository`.
  final _said = <String, String>{};

  /// The repositories being taken out, by `machine/repository`.
  final _leaving = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_readAll());
  }

  @override
  void didUpdateWidget(ClaimedDefaultRows old) {
    super.didUpdateWidget(old);
    final before = {for (final each in old.machines) each.name};
    if (widget.machines.any((each) => !before.contains(each.name)) || widget.machines.length != before.length) {
      _claimed.removeWhere((name, _) => !widget.machines.any((each) => each.name == name));
      unawaited(_readAll());
    }
  }

  Future<void> _readAll() => Future.wait([for (final machine in widget.machines) _read(machine)]);

  /// The organization's projects that name a repository of `default`, or, from a Porelo that cannot list them, the
  /// placed projects its list of `default` says name one.
  Future<List<NamedDefaultRepository>> _named(FleetBackend backend) async {
    try {
      return await backend.namedDefaultRepositories();
    } on FeatureNotSupported {
      return [
        for (final each in await backend.defaultRepositories())
          if (each.claimedBy.isNotEmpty)
            NamedDefaultRepository(name: each.name, upstream: each.upstream, project: each.claimedBy),
      ];
    }
  }

  Future<void> _read(({String name, FleetBackend backend}) machine) async {
    try {
      final found = await _named(machine.backend);
      if (!mounted) return;
      setState(() => _claimed[machine.name] = found);
    } on Object {
      // A machine that cannot say now offers nothing; the Default dialog says why where it is opened.
    }
  }

  Future<void> _leave(({String name, FleetBackend backend}) machine, NamedDefaultRepository repository) async {
    final key = '${machine.name}/${repository.name}';
    final asked = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Take ${repository.name} out of Default?'),
        content: Text(
          '${_names(repository)}, so its next task on ${machine.name} starts there. A task running in Default keeps '
          'its project. Its mirror on ${machine.name}, and anything waiting in it, stay.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('default-leave-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Take it out of Default'),
          ),
        ],
      ),
    );
    if (asked != true || !mounted || _leaving.contains(key)) return;
    setState(() {
      _leaving.add(key);
      _said.remove(key);
    });
    String said;
    try {
      final done = await machine.backend.leaveDefault(repository.name);
      said = [
        if (done.removed)
          '${repository.name} is out of Default on ${machine.name}; its next task starts in ${repository.project}.'
        else
          '${repository.name} was not in Default on ${machine.name} any more.',
        for (final each in done.keys) each.title,
      ].join(' ');
    } on VarlinkException catch (refusal) {
      said = switch (refusal.simpleName) {
        'DefaultRepositoryInUse' =>
          'Tasks of Default still work on ${repository.name}: '
              '${(refusal.parameters['tasks'] as List<dynamic>? ?? const []).join(', ')}. It stays in Default until '
              'they are removed.',
        'NoSuchDefaultRepository' => '${repository.name} was not in Default on ${machine.name} any more.',
        _ => '${machine.name} refused it: ${refusal.parameters['message'] ?? refusal.simpleName}.',
      };
    } on Exception catch (error) {
      said = '${repository.name} could not be taken out of Default on ${machine.name}: $error';
    }
    if (!mounted) return;
    setState(() {
      _leaving.remove(key);
      _said[key] = said;
    });
    await _read(machine);
  }

  /// Which project names [repository], and by which of its repositories where the machine says.
  static String _names(NamedDefaultRepository repository) => repository.projectRepository.isEmpty
      ? '${repository.project} names it now'
      : '${repository.project} names it now as ${repository.projectRepository}';

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final machine in widget.machines)
        for (final repository in _claimed[machine.name] ?? const <NamedDefaultRepository>[])
          ListTile(
            key: ValueKey<String>('default-claimed ${machine.name}/${repository.name}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.drive_file_move_outline),
            title: Text('${repository.name}, in Default on ${machine.name}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_names(repository)}: its next task starts in ${repository.project}. It stays in Default until '
                  'it is taken out.',
                ),
                if (repository.removal.isNotEmpty)
                  SelectableText(
                    'At a terminal: ${repository.removal}',
                    key: ValueKey<String>('default-removal ${machine.name}/${repository.name}'),
                  ),
              ],
            ),
            trailing: TextButton(
              key: ValueKey<String>('default-leave ${machine.name}/${repository.name}'),
              onPressed: _leaving.contains('${machine.name}/${repository.name}')
                  ? null
                  : () => unawaited(_leave(machine, repository)),
              child: const Text('Take it out of Default…'),
            ),
          ),
    ];
    final said = [
      for (final each in _said.entries) Text(each.value, key: ValueKey<String>('default-left ${each.key}')),
    ];
    if (rows.isEmpty && said.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.normal),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...rows, ...said]),
    );
  }
}
