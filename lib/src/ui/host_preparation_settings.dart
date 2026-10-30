import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import 'tokens.dart';

/// Edits public runner limits and the person's local forward ports.
class HostPreparationSettingsForm extends StatefulWidget {
  /// Applies checked choices only after the person accepts them.
  const HostPreparationSettingsForm({required this.value, required this.onChanged, super.key});

  /// The choices retained with this preparation.
  final HostPreparationSettings value;

  /// Receives validated settings, with empty limits left to role defaults.
  final ValueChanged<HostPreparationSettings> onChanged;

  @override
  State<HostPreparationSettingsForm> createState() => _HostPreparationSettingsFormState();
}

class _HostPreparationSettingsFormState extends State<HostPreparationSettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _fields = <String, TextEditingController>{
    'forge_runner_capacity': TextEditingController(text: widget.value.forgeRunnerCapacity?.toString() ?? ''),
    'forge_job_cpus': TextEditingController(text: widget.value.forgeJobCpus?.toString() ?? ''),
    'forge_job_memory': TextEditingController(text: widget.value.forgeJobMemory ?? ''),
    'forge_web_port': TextEditingController(text: '${widget.value.forgeWebPort}'),
    'forge_git_port': TextEditingController(text: '${widget.value.forgeGitPort}'),
    'matrix_port': TextEditingController(text: '${widget.value.matrixPort}'),
  };
  String? _problem;

  HostPreparationSettings _read() => HostPreparationSettings.read({
    for (final entry in _fields.entries)
      if (entry.value.text.trim().isNotEmpty)
        entry.key: entry.key == 'forge_job_memory'
            ? entry.value.text.trim()
            : int.tryParse(entry.value.text.trim()) ?? entry.value.text.trim(),
  });

  void _apply() {
    try {
      final value = _read();
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
    children: [
      Form(
        key: _form,
        child: Column(
          spacing: Space.small,
          children: [
            for (final entry in const {
              'forge_runner_capacity': ('Concurrent forge jobs', 'Leave empty for the host role default.'),
              'forge_job_cpus': ('CPUs per forge job', 'Leave empty for the host role default.'),
              'forge_job_memory': ('Memory per forge job', 'For example 768m; leave empty for the host role default.'),
              'forge_web_port': ('Local forge web port', 'The SSH forward on this computer.'),
              'forge_git_port': ('Local forge Git port', 'The SSH forward on this computer.'),
              'matrix_port': ('Local Matrix port', 'The SSH forward on this computer.'),
            }.entries)
              TextFormField(
                key: Key(entry.key),
                controller: _fields[entry.key],
                decoration: InputDecoration(labelText: entry.value.$1, helperText: entry.value.$2),
              ),
            if (_problem != null) Text(_problem!),
            OutlinedButton(onPressed: _apply, child: const Text('Use settings')),
          ],
        ),
      ),
    ],
  );
}
