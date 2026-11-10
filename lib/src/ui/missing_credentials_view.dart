import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/missing_credentials.dart';
import 'command_to_copy.dart';
import 'tokens.dart';

/// What a machine's vault lacks beside the agent, each in its own box: what it costs a start there, which goes on
/// all the same, and a press that runs the machine's own command in a terminal there.
///
/// [onStore] runs it on [machine] and then asks the machine again; null where this window does not reach that
/// machine itself, and then the command is shown to run there by hand.
class MissingCredentials extends StatelessWidget {
  /// Constructor taking what is missing, where, and how it is stored from here.
  const MissingCredentials({required this.missing, required this.machine, this.onStore, super.key});

  /// What the machine named as missing.
  final List<MissingCredential> missing;

  /// The machine's name, as the window shows it.
  final String machine;

  /// Runs an entry's command on [machine], then asks again; null where nothing here reaches it.
  final Future<void> Function(MissingCredential missing)? onStore;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Space.small,
    children: <Widget>[
      for (final each in missing)
        Container(
          key: ValueKey<String>('missing-credential ${each.credential}'),
          width: double.infinity,
          padding: const EdgeInsets.all(Space.normal),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: Sizes.divider),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Radii.small),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.small,
            children: <Widget>[
              Text(each.atTheStart(machine)),
              if (each.thenUnknown case final then?) Text(then, style: Theme.of(context).textTheme.bodySmall),
              ..._store(each),
            ],
          ),
        ),
    ],
  );

  List<Widget> _store(MissingCredential each) {
    if (onStore != null && each.storeCommand.isNotEmpty) {
      return <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: ValueKey<String>('store-missing ${each.credential}'),
            onPressed: () => unawaited(onStore!(each)),
            icon: const Icon(Icons.terminal, size: Sizes.rowIcon),
            label: Text('Store ${each.credential.isEmpty ? 'it' : each.credential} on $machine, in a terminal there'),
          ),
        ),
      ];
    }
    return <Widget>[
      Text(each.notRunHere(machine)),
      if (each.commandToCopy case final command?) CommandToCopy(command: command),
    ];
  }
}

/// A task's builds wait for a credential its start found missing: the host's command for it in a terminal there,
/// and once it ran, that only the task's next start follows them (`restart`).
///
/// [onStore] answers whether the command ended without an error; null where this window does not reach the machine.
class StoreTheBuildsCredential extends StatefulWidget {
  /// Constructor taking what is missing, where, and how it is stored from here.
  const StoreTheBuildsCredential({required this.missing, required this.machine, this.onStore, super.key});

  /// What the task's start found missing.
  final MissingCredential missing;

  /// The machine's name, as the window shows it.
  final String machine;

  /// Runs its command on [machine], answering whether it ended with exit code 0; null where nothing here reaches it.
  final Future<bool> Function(MissingCredential missing)? onStore;

  @override
  State<StoreTheBuildsCredential> createState() => _StoreTheBuildsCredentialState();
}

class _StoreTheBuildsCredentialState extends State<StoreTheBuildsCredential> {
  /// Whether its command ended without an error; null before it ran here.
  bool? _ended;

  bool _running = false;

  Future<void> _store() async {
    setState(() => _running = true);
    final ended = await widget.onStore!(widget.missing);
    if (!mounted) return;
    setState(() {
      _running = false;
      _ended = ended;
    });
  }

  @override
  Widget build(BuildContext context) {
    final missing = widget.missing;
    final key = missing.credential.isEmpty ? 'it' : missing.credential;
    return Column(
      key: const Key('builds-credential'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: <Widget>[
        if (widget.onStore != null && missing.storeCommand.isNotEmpty)
          OutlinedButton.icon(
            key: const Key('store-builds-credential'),
            onPressed: _running ? null : () => unawaited(_store()),
            icon: const Icon(Icons.terminal, size: Sizes.rowIcon),
            label: Text('Store $key on ${widget.machine}, in a terminal there'),
          )
        else ...<Widget>[
          Text(missing.notRunHere(widget.machine)),
          if (missing.commandToCopy case final command?) CommandToCopy(command: command),
        ],
        if (_ended == true)
          Text(switch (missing.afterStore) {
            'restart' => 'The command ended without an error. This task follows its builds only from its next start.',
            _ => 'The command ended without an error. ${missing.thenUnknown ?? ''}'.trim(),
          }, key: const Key('builds-credential-stored'))
        else if (_ended == false)
          const Text(
            'The command did not end without an error: read what it printed, and run it again.',
            key: Key('builds-credential-stored'),
          ),
      ],
    );
  }
}
