import 'package:flutter/material.dart';

import '../app/fleet_backend.dart';
import '../app/machines.dart';
import '../app/project_join.dart';
import '../app/session.dart';
import '../app/settings.dart';
import '../app/signed_host_actions.dart';
import 'tokens.dart';

/// Opens joining from verified admission without a public-value or key wizard.
Future<void> openProjectJoinDialog(
  BuildContext context, {
  required String project,
  required FleetBackend backend,
  required Machines machines,
  required Settings settings,
  OpenTerminal? openTerminal,
  SignedHostActions? actions,
}) => showDialog<void>(
  context: context,
  builder: (_) => ProjectJoinDialog(project: project, machines: machines, settings: settings, actions: actions),
);

/// Joins using Core's accepted state and the person's agent.
class ProjectJoinDialog extends StatefulWidget {
  /// Supplies the verified boundaries when their implementations are available.
  const ProjectJoinDialog({
    required this.project,
    required this.machines,
    required this.settings,
    this.actions,
    super.key,
  });

  /// The selected project.
  final String project;

  /// The watched accounts.
  final Machines machines;

  /// The confirmed host association.
  final Settings settings;

  /// The verified Core and host boundary.
  final SignedHostActions? actions;
  @override
  State<ProjectJoinDialog> createState() => _ProjectJoinDialogState();
}

class _ProjectJoinDialogState extends State<ProjectJoinDialog> {
  late final _action = ProjectJoin(
    project: widget.project,
    machines: widget.machines,
    settings: widget.settings,
    actions: widget.actions,
  );
  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _action,
    builder: (context, _) => AlertDialog(
      title: Text('Join ${widget.project}'),
      content: SizedBox(
        width: Sizes.dialogSmall,
        child: Text(
          _action.problem ??
              (_action.completed
                  ? 'The host confirmed joining.'
                  : widget.actions == null
                  ? 'Verified registry joining is not available yet.'
                  : 'Join this admitted project using your identity.'),
        ),
      ),
      actions: [
        TextButton(onPressed: _action.busy ? null : () => Navigator.pop(context), child: const Text('Close')),
        if (!_action.completed && widget.actions != null)
          FilledButton(onPressed: _action.busy ? null : _action.join, child: const Text('Join')),
      ],
    ),
  );
}
