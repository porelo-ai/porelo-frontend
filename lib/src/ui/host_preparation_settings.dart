import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import 'tokens.dart';

/// Edits public runner limits and the person's local forward ports.
class HostPreparationSettingsForm extends StatefulWidget {
  /// Applies checked choices only after the person accepts them.
  const HostPreparationSettingsForm({
    required this.value,
    required this.onChanged,
    this.edits,
    this.onEdited,
    super.key,
  });

  /// The choices retained with this preparation.
  final HostPreparationSettings value;

  /// Receives validated settings, with empty limits left to role defaults.
  final ValueChanged<HostPreparationSettings> onChanged;

  /// What the fields held when the form was last shown, kept by its caller so that leaving the page drops no edit;
  /// null fills them from [value].
  final Map<String, String>? edits;

  /// Receives what the fields hold after each edit, so its caller can keep it and say what is not used yet.
  final ValueChanged<Map<String, String>>? onEdited;

  /// The fields' texts that say exactly [value].
  static Map<String, String> textsOf(HostPreparationSettings value) => {
    'forge_runner_capacity': value.forgeRunnerCapacity?.toString() ?? '',
    'forge_job_cpus': value.forgeJobCpus?.toString() ?? '',
    'forge_job_memory': value.forgeJobMemory ?? '',
    'forge_web_port': '${value.forgeWebPort}',
    'forge_git_port': '${value.forgeGitPort}',
    'matrix_port': '${value.matrixPort}',
  };

  /// The settings [texts] say, with [value]'s two plain choices; throws [FormatException] where they are refused.
  static HostPreparationSettings read(HostPreparationSettings value, Map<String, String> texts) {
    // A hidden field neither refuses nor counts: [value]'s own stands in for it, and what it holds is there again with
    // the forge.
    final shown = {
      ...textsOf(value),
      for (final entry in texts.entries)
        if (value.forge || !entry.key.startsWith('forge_')) entry.key: entry.value,
    };
    return HostPreparationSettings.read({
      'forge': value.forge,
      'kvm': value.kvm,
      for (final entry in shown.entries)
        if (entry.value.trim().isNotEmpty)
          entry.key: entry.key == 'forge_job_memory'
              ? entry.value.trim()
              : int.tryParse(entry.value.trim()) ?? entry.value.trim(),
    });
  }

  /// Why [edits] cannot go on beside the [value] in use: refused, or not used yet; null where they say [value].
  static String? whyNot(HostPreparationSettings value, Map<String, String>? edits) {
    if (edits == null) return null;
    try {
      if (listEquals(read(value, edits).arguments, value.arguments)) return null;
      return 'More settings holds a change not used yet: press Use settings, or set it back.';
    } on FormatException catch (error) {
      return 'More settings: ${error.message}';
    }
  }

  @override
  State<HostPreparationSettingsForm> createState() => _HostPreparationSettingsFormState();
}

class _HostPreparationSettingsFormState extends State<HostPreparationSettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _fields = {
    for (final entry in (widget.edits ?? HostPreparationSettingsForm.textsOf(widget.value)).entries)
      entry.key: TextEditingController(text: entry.value),
  };
  String? _problem;

  Map<String, String> get _texts => {for (final entry in _fields.entries) entry.key: entry.value.text};

  void _apply() {
    try {
      final value = HostPreparationSettingsForm.read(widget.value, _texts);
      setState(() => _problem = null);
      widget.onChanged(value);
    } on FormatException catch (error) {
      setState(() => _problem = error.message);
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('More settings'),
    // Open again where an edit waits, so what the page says of it can be seen.
    initiallyExpanded: HostPreparationSettingsForm.whyNot(widget.value, widget.edits) != null,
    children: [
      Form(
        key: _form,
        child: Column(
          spacing: Space.small,
          children: [
            for (final entry in const {
              'forge_runner_capacity': (
                'Concurrent forge jobs',
                'How many jobs run at once, each with its CPUs and memory. Leave empty and the machine\'s role '
                    'works it out from what the machine has.',
              ),
              'forge_job_cpus': ('CPUs per forge job', 'Leave empty for the machine role default.'),
              'forge_job_memory': (
                'Memory per forge job',
                'For example 768m; leave empty for the machine role default.',
              ),
              'forge_web_port': ('Local forge web port', 'The SSH forward on this computer.'),
              'forge_git_port': ('Local forge Git port', 'The SSH forward on this computer.'),
              'matrix_port': ('Local Matrix port', 'The SSH forward on this computer.'),
            }.entries)
              if (widget.value.forge || !entry.key.startsWith('forge_'))
                TextFormField(
                  key: Key(entry.key),
                  controller: _fields[entry.key],
                  decoration: InputDecoration(labelText: entry.value.$1, helperText: entry.value.$2),
                  onChanged: (_) {
                    // What was refused is no longer what the fields hold.
                    if (_problem != null) setState(() => _problem = null);
                    widget.onEdited?.call(_texts);
                  },
                ),
            if (_problem != null) Text(_problem!),
            OutlinedButton(onPressed: _apply, child: const Text('Use settings')),
          ],
        ),
      ),
    ],
  );
}
