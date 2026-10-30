import 'signed_host_actions.dart';

/// Joins an admitted project through signed state and the person's agent identity.
class ProjectJoin extends SignedHostAction {
  /// Supplies typed Core and host boundaries without accepting keys or secrets.
  ProjectJoin({required super.project, required super.machines, required super.settings, super.actions})
    : super(registering: false);

  /// Whether the host confirmed the intended project revision.
  bool get joined => completed;

  /// Joins the admitted project.
  Future<void> join() => run();
}
