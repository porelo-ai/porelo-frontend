import 'dart:async';

import 'package:flutter/material.dart';

import '../app/organization_source.dart';
import 'pick_a_file.dart';
import 'project_file_entry.dart';
import 'tokens.dart';

/// Reads a checkout without writing, and says the entry a project admin adds to the project's file for it.
class ProjectInitDialog extends StatefulWidget {
  /// Reads a checkout chosen by [pickFolder] for [project].
  const ProjectInitDialog({
    required this.organization,
    required this.project,
    this.pickFolder = pickFolderWithTheDesktop,
    super.key,
  });

  /// The source of the draft and its entry.
  final Organization organization;

  /// The project to fill.
  final String project;

  /// The replaceable desktop folder picker.
  final PickAFolder pickFolder;

  @override
  State<ProjectInitDialog> createState() => _ProjectInitDialogState();
}

class _ProjectInitDialogState extends State<ProjectInitDialog> {
  String? _checkout;
  ProjectInitDraft? _draft;
  String? _problem;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_choose());
  }

  Future<void> _choose() async {
    if (_reading || widget.organization.busy) return;
    setState(() {
      _reading = true;
      _draft = null;
      _problem = null;
    });
    try {
      final checkout = await widget.pickFolder(title: 'Choose a checkout folder');
      if (!mounted || checkout == null) return;
      setState(() => _checkout = checkout);
      await _read(checkout);
    } on Exception {
      if (mounted) setState(() => _problem = 'The folder dialog could not be opened.');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  static String _orNone(String listed) => listed.isEmpty ? 'none' : listed;

  // Core names whose file a value comes from in one word of its own.
  static String _whose(String origin) => switch (origin) {
    'CHECKOUT' => 'From the checkout',
    'YOURS' => 'From your own files',
    'MACHINE' => 'From the machine or a default',
    _ => origin,
  };

  // Core's rule: a project cannot hold a repository of its own name, and a person's first ones often share one.
  String get _namedAsItsRepository =>
      'A project cannot hold a repository of its own name. Add the project under another name, such as '
      '${widget.project}-project, and fill that one from this checkout.';

  Future<void> _read(String checkout) async {
    try {
      var draft = await widget.organization.source.readProjectInit(checkout, project: widget.project);
      // The name comes from the first answer. On a machine a task reads the machine's own forge, and the checkout's
      // address is where the machine takes it from, so what is read and signed says so.
      final local = draft.repository == widget.project
          ? null
          : widget.organization.view?.localAddress(widget.project, draft.repository);
      if (local != null) {
        draft = await widget.organization.source.readProjectInit(checkout, project: widget.project, upstream: local);
      }
      if (!mounted) return;
      setState(() {
        if (draft.repository == widget.project) {
          _problem = _namedAsItsRepository;
        } else {
          _draft = draft;
          if (draft.entry == null) _problem = 'Porelo did not say the entry to write for this checkout.';
        }
      });
    } on OrganizationRefused catch (refused) {
      if (mounted) {
        setState(() {
          _problem = refused.words.contains("project's own")
              ? '${refused.words} $_namedAsItsRepository'
              : 'Porelo cannot say the entry. ${refused.words}';
        });
      }
    } on Exception {
      if (mounted) setState(() => _problem = 'Porelo cannot say the entry: the checkout draft could not be read.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final entry = draft?.entry;
    return AlertDialog(
      title: Text('Fill ${widget.project} from a checkout'),
      content: SizedBox(
        width: Sizes.dialogSmall,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reading the checkout writes nothing. Porelo says the entry to add for it; you commit it.'),
              if (_checkout case final checkout?) Text('Checkout: $checkout'),
              if (_reading) const Text('Reading the checkout…'),
              if (_problem case final problem?)
                Text(problem, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (draft == null)
                OutlinedButton(
                  key: const Key('project-init-choose'),
                  onPressed: _reading || widget.organization.busy ? null : () => unawaited(_choose()),
                  child: const Text('Choose a checkout folder…'),
                ),
              if (draft != null) ...[
                if (entry != null) ...[
                  const SizedBox(height: Space.small),
                  ProjectFileEntry(ProjectFileByHand(project: widget.project, entry: entry)),
                ],
                const SizedBox(height: Space.small),
                Text('What Porelo read', style: Theme.of(context).textTheme.titleSmall),
                Text('Repository: ${draft.repository}'),
                Text('Upstream: ${draft.upstream ?? 'none named'}'),
                const SizedBox(height: Space.small),
                Text('Disagreements', style: Theme.of(context).textTheme.titleSmall),
                if (draft.disagreements.isEmpty) const Text('None reported.'),
                for (final disagreement in draft.disagreements) Text('${disagreement.key}: ${disagreement.values}'),
                Text('Credentials needed: ${_orNone(draft.credentialsNeeded)}'),
                const Text('Enter credentials only through Porelo’s own terminal or the provider’s sign-in.'),
                Text('Plugins', style: Theme.of(context).textTheme.titleSmall),
                if (draft.plugins.isEmpty) const Text('None reported.'),
                for (final plugin in draft.plugins)
                  Text('${plugin.name}: ${plugin.state}${plugin.why == null ? '' : ' · ${plugin.why}'}'),
                Text('Unplaced: ${_orNone(draft.unplaced)}'),
                Text('Not placed: ${_orNone(draft.notPlaced)}'),
                const SizedBox(height: Space.small),
                Text('Values', style: Theme.of(context).textTheme.titleSmall),
                if (draft.values.isEmpty) const Text('No values reported.'),
                for (final value in draft.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${value.key}${value.value.isEmpty ? '' : ': ${value.value}'}${value.unknown ? ' · unknown' : ''}',
                    ),
                    subtitle: Text(
                      [
                        if (value.file != null) '${value.file}${value.line == null ? '' : ':${value.line}'}',
                        if (value.origin != null) _whose(value.origin!),
                        if (value.file == null && value.origin == null) 'Origin not named.',
                        if (value.note != null) 'Note: ${value.note}',
                        if (value.plugin != null) 'Plugin: ${value.plugin}',
                      ].join('\n'),
                    ),
                  ),
                Text('Draft', style: Theme.of(context).textTheme.titleSmall),
                SelectableText(draft.draft),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('project-init-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
