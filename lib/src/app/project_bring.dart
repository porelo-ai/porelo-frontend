import 'signed_host_actions.dart';

/// Registers a project using its verified admission and the person's shared SSH tunnel.
class ProjectBring extends SignedHostAction {
  /// Supplies typed Core and host boundaries without accepting keys or secrets.
  ProjectBring({required super.project, required super.machines, required super.settings, super.actions})
    : super(registering: true);

  /// Whether registration of the intended revision was confirmed.
  bool get brought => completed;

  /// Registers the admitted project.
  Future<void> bring() => run();
}
