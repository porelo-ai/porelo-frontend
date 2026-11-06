import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_backend.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Shows what [task]'s image was built with, read from [backend] when it opens.
Future<void> showImageSettings(BuildContext context, {required FleetBackend backend, required String task}) =>
    showDialog<void>(
      context: context,
      builder: (_) => ImageSettingsDialog(backend: backend, task: task),
    );

/// A setting's source in a person's words; one this window does not know, as it came.
///
/// A real machine names a project's file by its whole path and where in it; the folder only repeats itself
/// on every line, so it is left out, and what the file says stays.
String imageSourceWords(String source) {
  final inTheFile = RegExp(r'^/\S*/(project|porelo)\.yml\b').hasMatch(source)
      ? source.replaceFirst(RegExp(r'^/\S*/'), '')
      : source;
  return switch (inTheFile) {
    'project.yml' => "from the project's project.yml",
    'porelo.yml' => "from the repository's porelo.yml",
    'porelo' => "from Porelo's settings",
    'agent package' => "from the agent's package",
    'the project' || 'the local override' || "Porelo's default" => 'from $inTheFile',
    '' => 'source not recorded',
    _ when inTheFile.startsWith('project.yml') => "from the project's $inTheFile",
    // The machine names the repository: `porelo.yml of x`.
    _ when inTheFile.startsWith('porelo.yml of ') => 'from $inTheFile',
    _ when inTheFile.startsWith('porelo.yml') => "from the repository's $inTheFile",
    _ => source,
  };
}

/// A setting the repository took away, and what took it away as the machine names it.
String removedWords(RemovedSetting removed) =>
    removed.by.isEmpty ? '${removed.key}  removed' : '${removed.key}  removed by ${removed.by}';

/// The dialog [showImageSettings] shows: every setting, and where it comes from.
class ImageSettingsDialog extends StatefulWidget {
  /// Constructor taking the machine and the task.
  const ImageSettingsDialog({required this.backend, required this.task, super.key});

  /// The machine the task is on.
  final FleetBackend backend;

  /// The task whose image is asked about.
  final String task;

  @override
  State<ImageSettingsDialog> createState() => _ImageSettingsDialogState();
}

class _ImageSettingsDialogState extends State<ImageSettingsDialog> {
  ImageSettings? _said;

  /// Why nothing could be read, in words.
  String? _problem;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    String? problem;
    ImageSettings? said;
    try {
      said = await widget.backend.imageSettings(widget.task);
    } on FeatureNotSupported {
      problem = 'Reading what an image was built with needs a newer Porelo on this machine.';
    } on VarlinkException catch (refusal) {
      problem = refusal.simpleName == 'NoSuchTask'
          ? 'This machine does not know a task called ${widget.task} any more.'
          : 'The machine refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (lost) {
      problem = 'Lost contact with the machine: ${lost.message}';
    }
    if (!mounted) return;
    setState(() {
      _said = said;
      _problem = problem;
    });
  }

  Widget _heading(BuildContext context, String words) => Padding(
    padding: const EdgeInsets.only(top: Space.normal, bottom: Space.tight),
    child: Text(words, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _setting(BuildContext context, ImageSetting setting, {String? value}) => Padding(
    padding: const EdgeInsets.only(bottom: Space.tight),
    child: SelectableText.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: value ?? setting.value),
          TextSpan(
            text: '  ${imageSourceWords(setting.source)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );

  List<Widget> _group(BuildContext context, String heading, List<ImageSetting> settings) => <Widget>[
    _heading(context, heading),
    if (settings.isEmpty) const Text('None recorded.'),
    for (final setting in settings) _setting(context, setting),
  ];

  Widget _body(BuildContext context) {
    if (_problem case final problem?) return SelectableText(problem, key: const Key('image-settings-problem'));
    final said = _said;
    if (said == null) {
      return const Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator());
    }
    if (!said.known) {
      // Not "built with nothing": the image only does not say.
      return const SelectableText(
        'This image does not say what it was built with: it is older than this reading, or its record cannot be '
        'read. A new start of this work builds one that does.',
        key: Key('image-settings-unknown'),
      );
    }
    final agent = said.agentVersion.isEmpty ? said.agent.value : '${said.agent.value} ${said.agentVersion}';
    return DialogScroll(
      child: Column(
        key: const Key('image-settings'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _heading(context, 'Base image'),
          _setting(context, said.baseImage),
          ..._group(context, 'Packages', said.packages),
          ..._group(context, 'Tools', said.tools),
          if (said.lines.isNotEmpty) ..._group(context, 'Lines added to the image', said.lines),
          _heading(context, 'Agent'),
          _setting(context, said.agent, value: agent),
          _heading(context, 'Security class'),
          _setting(context, said.securityClass),
          if (said.removed.isNotEmpty) ...<Widget>[
            _heading(context, 'Taken away from the project\'s settings'),
            for (final each in said.removed) SelectableText(removedWords(each)),
          ],
          if (said.recorded.isNotEmpty) ...<Widget>[_heading(context, 'Built'), SelectableText(said.recorded)],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('image-settings-dialog'),
    title: Text('What ${widget.task} was built with'),
    content: SizedBox(width: Sizes.dialog, child: _body(context)),
    actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
  );
}
