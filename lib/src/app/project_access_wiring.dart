import 'package:path/path.dart' as path;

import 'desk.dart';
import 'identity.dart';
import 'machines.dart';
import 'project_access.dart';
import 'project_access_core.dart';
import 'project_access_transport.dart';
import 'project_copies.dart';
import 'registry.dart';
import 'registry_read_source.dart';
import 'run_here.dart';
import 'settings.dart';

/// The app's project access: for each project, Register and Add a developer through Core's verbs on this computer and
/// the host's sync through the person's own card tunnel, as the person Core's identity names.
///
/// It answers null while no registry was chosen, so the actions are listed as unavailable; once one is, the project's
/// [ProjectAccess] says why an action cannot run (no usable card, no admission, a tunnel that does not come up) in
/// the words of whoever refused. One [ProjectAccess] is kept per project and registry, so its receipts and the lock
/// that serializes its changes are the same wherever the shell asks for it.
ProjectAccess? Function(String project) appProjectAccess({
  required RegistryReadSource registry,
  required Settings settings,
  required Machines machines,
  Identity? identity,
  RunHere? run,
  String? root,
}) {
  final person = identity ?? Identity(run: run);
  final copies = ProjectCopies(root: root ?? path.join(desk.data, 'project-access'), run: run);
  final core = CoreProjectAccess(registry: () => registry.registry, identity: person.show, copies: copies, run: run);
  final transport = CardProjectAccessTransport(machines: machines, identity: person.show, copies: copies);
  final made = <String, ({Registry registry, ProjectAccess access})>{};
  return (project) {
    final current = registry.registry;
    if (current == null || project.isEmpty) return null;
    final kept = made[project];
    if (kept != null && identical(kept.registry, current)) return kept.access;
    final access = ProjectAccess(
      project: project,
      registry: current,
      settings: settings,
      core: core,
      transport: transport,
      rememberMachine: machines.add,
      personChangesUnavailable: CoreProjectAccess.notConnected,
    );
    made[project] = (registry: current, access: access);
    return access;
  };
}
