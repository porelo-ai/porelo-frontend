import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_backend.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Shows the machine's destinations, and lets a person add, change and remove their own.
Future<void> showDestinations(BuildContext context, FleetBackend backend) => showDialog<void>(
  context: context,
  builder: (_) => DestinationsDialog(backend: backend),
);

/// The services a credential can be for, as the machine declares them.
///
/// **What a console can do, this can**: a destination is a file at the
/// machine, and here it is listed, written with a preview the machine answers first, and removed.
/// A packaged one cannot be changed or removed; one of the user's own can take its place.
class DestinationsDialog extends StatefulWidget {
  /// Constructor taking the machine to ask.
  const DestinationsDialog({required this.backend, super.key});

  final FleetBackend backend;

  @override
  State<DestinationsDialog> createState() => _DestinationsDialogState();
}

class _DestinationsDialogState extends State<DestinationsDialog> {
  List<Destination>? _destinations;
  String? _problem;
  String? _said;

  /// The destination being written, or null while none is.
  _Draft? _draft;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() => _asking(() async {
    final read = await widget.backend.destinations();
    if (mounted) setState(() => _destinations = read);
  });

  Future<void> _asking(Future<void> Function() action) async {
    setState(() => _problem = null);
    try {
      await action();
    } on FeatureNotSupported {
      if (mounted) setState(() => _problem = 'This machine cannot list its destinations.');
    } on VarlinkException catch (refusal) {
      if (mounted) {
        setState(
          () => _problem = switch (refusal.simpleName) {
            'DestinationRefused' => '${refusal.parameters['message'] ?? 'The machine refused it.'}',
            'NoSuchDestination' => 'There is no destination ${refusal.parameters['name'] ?? ''} on this machine.',
            _ => 'The machine refused it: ${refusal.simpleName}.',
          },
        );
      }
    } on VarlinkDisconnected catch (ex) {
      if (mounted) setState(() => _problem = 'Lost contact with the machine: ${ex.message}');
    }
  }

  Future<void> _remove(Destination destination) => _asking(() async {
    final done = await widget.backend.removeDestination(destination.name);
    if (mounted) {
      setState(
        () => _said = done.removed
            ? 'Removed ${destination.name}: ${done.file} is gone.'
            : 'Nothing of your own was there to remove for ${destination.name}.',
      );
    }
    await _read();
  });

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final text = Theme.of(context).textTheme;
    final draft = _draft;
    return AlertDialog(
      key: const Key('destinations-dialog'),
      title: const Text('Destinations'),
      content: SizedBox(
        width: Sizes.dialog,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'The services a credential can be for, beside the model providers: where requests go, '
                'and where the key goes in them. Each is a file on the machine.',
                style: text.bodySmall,
              ),
              const SizedBox(height: Space.small),
              if (_problem != null)
                Text(
                  _problem!,
                  key: const Key('destinations-problem'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_said != null) Text(_said!, key: const Key('destinations-said')),
              if (destinations == null && _problem == null) const Text('Asking the machine…'),
              if (destinations != null && destinations.isEmpty)
                const Text('No destination is declared on this machine.', key: Key('no-destinations')),
              for (final each in destinations ?? const <Destination>[]) _row(context, each),
              const SizedBox(height: Space.small),
              if (draft == null)
                OutlinedButton.icon(
                  key: const Key('add-destination'),
                  onPressed: () => setState(() => _draft = _Draft()),
                  icon: const Icon(Icons.add, size: Sizes.rowIcon),
                  label: const Text('Add a destination'),
                )
              else
                _DraftForm(
                  draft: draft,
                  backend: widget.backend,
                  onWritten: (written) async {
                    setState(() {
                      _draft = null;
                      _said = 'Written: ${written.name}, in ${written.file}.';
                    });
                    await _read();
                  },
                  onLeave: () => setState(() => _draft = null),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('destinations-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Destination each) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: ValueKey<String>('destination ${each.name} ${each.packaged ? 'packaged' : 'own'}'),
      child: Padding(
        padding: const EdgeInsets.all(Space.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              each.label.isEmpty || each.label == each.name ? each.name : '${each.label} (${each.name})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(each.upstream, style: text.bodySmall),
            Text('The key goes ${each.keyGoes}.', style: text.bodySmall),
            SelectableText(each.file, style: text.bodySmall),
            if (each.packaged)
              Text(
                each.inForce
                    ? 'Installed by a package: it cannot be changed or removed here, only have one of '
                          'your own put in its place.'
                    : 'Installed by a package, and not in force: one of your own of the same name takes '
                          'its place.',
                key: ValueKey<String>('destination-packaged ${each.name}'),
                style: text.bodySmall,
              ),
            Wrap(
              spacing: Space.small,
              children: <Widget>[
                if (each.inForce)
                  TextButton(
                    key: ValueKey<String>('change-destination ${each.name}'),
                    onPressed: () => setState(() => _draft = _Draft.of(each)),
                    child: Text(each.packaged ? 'Put your own in its place' : 'Change it'),
                  ),
                if (!each.packaged)
                  TextButton(
                    key: ValueKey<String>('remove-destination ${each.name}'),
                    onPressed: () => unawaited(_remove(each)),
                    child: const Text('Remove it'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What is being typed for a destination.
class _Draft {
  _Draft()
    : name = TextEditingController(),
      label = TextEditingController(),
      upstream = TextEditingController(),
      header = TextEditingController(text: 'Authorization'),
      prefix = TextEditingController(),
      query = TextEditingController();

  _Draft.of(Destination each)
    : name = TextEditingController(text: each.name),
      label = TextEditingController(text: each.label),
      upstream = TextEditingController(text: each.upstream),
      header = TextEditingController(text: each.authHeader),
      prefix = TextEditingController(text: each.authPrefix),
      query = TextEditingController(text: each.authQuery);

  final TextEditingController name;
  final TextEditingController label;
  final TextEditingController upstream;
  final TextEditingController header;
  final TextEditingController prefix;
  final TextEditingController query;

  /// Everything typed, as one comparable value: a preview holds only for what it was asked about.
  String get typed =>
      <TextEditingController>[name, label, upstream, header, prefix, query].map((each) => each.text).join('\u0000');
}

/// Typing a destination, checked by the machine before anything is written.
class _DraftForm extends StatefulWidget {
  const _DraftForm({required this.draft, required this.backend, required this.onWritten, required this.onLeave});

  final _Draft draft;
  final FleetBackend backend;
  final Future<void> Function(Destination written) onWritten;
  final VoidCallback onLeave;

  @override
  State<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<_DraftForm> {
  /// What the machine said to the last check, and for what was typed then.
  Destination? _previewed;
  String? _previewedFor;
  String? _refused;
  bool _busy = false;

  String? _or(TextEditingController field) => field.text.trim().isEmpty ? null : field.text.trim();

  Future<void> _write({required bool dryRun}) async {
    final draft = widget.draft;
    setState(() {
      _busy = true;
      _refused = null;
    });
    try {
      final done = await widget.backend.writeDestination(
        name: draft.name.text.trim(),
        upstream: draft.upstream.text.trim(),
        label: _or(draft.label),
        authHeader: _or(draft.header),
        // Never trimmed: the space after "Bearer" is part of what goes before the key.
        authPrefix: draft.prefix.text.isEmpty ? null : draft.prefix.text,
        authQuery: _or(draft.query),
        dryRun: dryRun,
      );
      if (dryRun) {
        if (mounted) {
          setState(() {
            _previewed = done.destination;
            _previewedFor = draft.typed;
          });
        }
      } else {
        await widget.onWritten(done.destination);
      }
    } on VarlinkException catch (refusal) {
      if (mounted) {
        setState(() {
          _previewed = null;
          _refused = refusal.simpleName == 'DestinationRefused'
              ? '${refusal.parameters['message'] ?? 'The machine refused it.'}'
              : 'The machine refused it: ${refusal.simpleName}.';
        });
      }
    } on VarlinkDisconnected catch (ex) {
      if (mounted) setState(() => _refused = 'Lost contact with the machine: ${ex.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final previewed = _previewed;
    // Written only what the machine read back just now, and nothing typed since.
    final current = previewed != null && _previewedFor == draft.typed;
    Widget field(String key, String label, TextEditingController controller) => TextField(
      key: Key(key),
      controller: controller,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        field('destination-name', 'Name', draft.name),
        field('destination-label', 'What to call it (optional)', draft.label),
        field('destination-upstream', 'Where requests go, https://…', draft.upstream),
        field('destination-header', 'The header the key goes in', draft.header),
        field('destination-prefix', 'Text before the key in it (optional)', draft.prefix),
        field('destination-query', 'Or the URL parameter it goes in instead (optional)', draft.query),
        const SizedBox(height: Space.small),
        if (_refused != null)
          Text(
            _refused!,
            key: const Key('destination-refused'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (current)
          Text(
            'The machine would read it back as ${previewed.upstream}, the key ${previewed.keyGoes}.',
            key: const Key('destination-previewed'),
          ),
        Wrap(
          spacing: Space.small,
          children: <Widget>[
            OutlinedButton(
              key: const Key('check-destination'),
              onPressed: _busy ? null : () => unawaited(_write(dryRun: true)),
              child: const Text('Check it'),
            ),
            FilledButton(
              key: const Key('write-destination'),
              onPressed: _busy || !current ? null : () => unawaited(_write(dryRun: false)),
              child: const Text('Write it'),
            ),
            TextButton(key: const Key('leave-destination'), onPressed: widget.onLeave, child: const Text('Leave it')),
          ],
        ),
      ],
    );
  }
}
