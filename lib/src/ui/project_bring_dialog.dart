import 'package:flutter/material.dart';

import '../app/fleet_backend.dart';
import '../app/machines.dart';
import '../app/project_bring.dart';
import '../app/project_access.dart';
import '../app/settings.dart';
import '../app/registry.dart';
import '../app/signed_host_actions.dart';
import 'tokens.dart';

/// Runs registration from verified state without asking for host values or key paths.
class ProjectBringDialog extends StatefulWidget {
  /// Accepts the served Core and host boundary when available.
  const ProjectBringDialog({
    required this.project,
    required this.machines,
    required this.backend,
    required this.settings,
    this.actions,
    this.access,
    super.key,
  });

  /// The selected followed project.
  final String project;

  /// The source daemon.
  final FleetBackend backend;

  /// The watched accounts.
  final Machines machines;

  /// The confirmed host association.
  final Settings settings;

  /// Core and host operations; absent dependencies are explained.
  final SignedHostActions? actions;

  /// The registry admission and durable project access delivery service.
  final ProjectAccess? access;
  @override
  State<ProjectBringDialog> createState() => _ProjectBringDialogState();
}

class _ProjectBringDialogState extends State<ProjectBringDialog> {
  late final _action = ProjectBring(
    project: widget.project,
    machines: widget.machines,
    settings: widget.settings,
    actions: widget.access == null ? widget.actions : RegistryProjectRegistration(widget.access!),
  );
  String? _admissionProblem;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    if (widget.access != null) _readAdmission();
  }

  Future<void> _readAdmission() async {
    _reading = true;
    try {
      await widget.access!.read(widget.project);
    } on RegistryRefusal catch (refused) {
      _admissionProblem = refused.toString();
    } on Exception {
      _admissionProblem = 'The verified project admission could not be read.';
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _action,
    builder: (context, _) => AlertDialog(
      title: Text('Register ${widget.project}'),
      content: SizedBox(
        width: Sizes.dialogSmall,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.small,
          children: [
            if (_admissionProblem == null)
              if (widget.access?.admission case final words?) Text(words),
            Text(
              _action.problem ??
                  _admissionProblem ??
                  widget.access?.unavailable() ??
                  (_action.completed
                      ? 'The host confirmed registration.'
                      : widget.actions == null && widget.access == null
                      ? 'Verified registry registration is not available yet.'
                      : 'Register this admitted project using your identity.'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _action.busy ? null : () => Navigator.pop(context), child: const Text('Close')),
        if (!_action.completed && (widget.actions != null || widget.access != null))
          FilledButton(
            onPressed: _action.busy || _reading || _admissionProblem != null || widget.access?.unavailable() != null
                ? null
                : _action.bring,
            child: const Text('Register the project'),
          ),
      ],
    ),
  );
}
