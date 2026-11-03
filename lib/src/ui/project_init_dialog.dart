import 'dart:async';

import 'package:flutter/material.dart';

import '../app/organization_source.dart';
import 'organization_dialogs.dart';
import 'pick_a_file.dart';
import 'tokens.dart';

/// Previews a checkout without writing, then offers the usual signed project change.
class ProjectInitDialog extends StatefulWidget {
  /// Reads a checkout chosen by [pickFolder] for [project].
  const ProjectInitDialog({
    required this.organization,
    required this.project,
    this.pickFolder = pickFolderWithTheDesktop,
    super.key,
  });

  /// The source of the draft and its signed write.
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

  Future<void> _read(String checkout) async {
    try {
      final draft = await widget.organization.source.readProjectInit(checkout, project: widget.project);
      if (!mounted) return;
      setState(() {
        if (draft.revision == null || draft.revision!.isEmpty) {
          _problem = 'Porelo cannot say what to sign: the draft names no project revision.';
        } else {
          _draft = draft;
        }
      });
    } on OrganizationRefused catch (refused) {
      if (mounted) setState(() => _problem = 'Porelo cannot say what to sign. ${refused.words}');
    } on Exception {
      if (mounted) setState(() => _problem = 'Porelo cannot say what to sign: the checkout draft could not be read.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return OrganizationChangeDialog(
      // A new preview must not retain a refusal or an in-flight change from the earlier one.
      key: ObjectKey(draft),
      organization: widget.organization,
      base: draft?.revision,
      title: 'Fill ${widget.project} from a checkout',
      confirm: 'Sign it into the project',
      body: (context, changed) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reading the checkout writes nothing. Review the draft before signing it with your key.'),
          if (_checkout case final checkout?) Text('Checkout: $checkout'),
          if (_reading) const Text('Reading the checkout…'),
          if (_problem case final problem?) Text(problem, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (draft == null)
            OutlinedButton(
              key: const Key('project-init-choose'),
              onPressed: _reading || widget.organization.busy ? null : () => unawaited(_choose()),
              child: const Text('Choose a checkout folder…'),
            ),
          if (draft != null) ...[
            const Text(
              'If Porelo refuses because the project moved on, cancel and choose “Fill it from a checkout…” again '
              'to read a fresh draft. If no answer came, sign again here to retry the same change safely.',
            ),
            Text('Repository: ${draft.repository}'),
            Text('Upstream: ${draft.upstream ?? 'none named'}'),
            Text('Revision: ${draft.revision}'),
            const SizedBox(height: Space.small),
            Text('Disagreements', style: Theme.of(context).textTheme.titleSmall),
            if (draft.disagreements.isEmpty) const Text('None reported.'),
            for (final disagreement in draft.disagreements) Text('${disagreement.key}: ${disagreement.values}'),
            Text('Credentials needed: ${draft.credentialsNeeded}'),
            const Text('Enter credentials only through Porelo’s own terminal or the provider’s sign-in.'),
            Text('Plugins', style: Theme.of(context).textTheme.titleSmall),
            if (draft.plugins.isEmpty) const Text('None reported.'),
            for (final plugin in draft.plugins)
              Text('${plugin.name}: ${plugin.state}${plugin.why == null ? '' : ' · ${plugin.why}'}'),
            Text('Unplaced: ${draft.unplaced}'),
            Text('Not placed: ${draft.notPlaced}'),
            const SizedBox(height: Space.small),
            Text('Values', style: Theme.of(context).textTheme.titleSmall),
            if (draft.values.isEmpty) const Text('No values reported.'),
            for (final value in draft.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${value.key}: ${value.value}${value.unknown ? ' · unknown' : ''}'),
                subtitle: Text(
                  [
                    if (value.file != null) '${value.file}${value.line == null ? '' : ':${value.line}'}',
                    if (value.origin != null) value.origin!,
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
      ask: () => draft == null || _reading || _checkout == null
          ? null
          : (change: OrganizationChange.initializeProject, input: {'project': widget.project, 'checkout': _checkout!}),
    );
  }
}
