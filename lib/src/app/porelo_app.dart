import 'package:flutter/material.dart';
import 'package:guided_walk/guided_walk.dart';

import '../ui/theme.dart';

import '../ui/shell.dart';
import 'egress.dart';
import 'product.dart';
import 'agent_inventory.dart';
import 'authentication.dart';
import 'backups.dart';
import 'emergency_stop.dart';
import 'forge_connection.dart';
import 'start_work.dart';
import 'templates.dart';
import 'vault.dart';
import 'widening.dart';
import 'work_held.dart';
import 'gate.dart';
import 'host_readiness.dart';
import 'logs.dart';
import 'machines.dart';
import 'narrowing.dart';
import 'newer_version.dart';
import 'notifications.dart';
import 'operations.dart';
import 'connections.dart';
import '../ui/pick_a_file.dart';
import '../ui/walk_texts.dart';
import 'project_following.dart';
import 'project_deletion.dart';
import 'session.dart';
import 'settings.dart';
import 'shell_model.dart';
import 'registry_pages.dart';

/// The application: one window, one frame, one backend at a time.
class PoreloApp extends StatelessWidget {
  /// Constructor taking the state the whole interface is drawn from.
  const PoreloApp({
    required this.machines,
    required this.shell,
    required this.settings,
    required this.operations,
    required this.logs,
    required this.gate,
    required this.notifications,
    required this.egress,
    required this.widening,
    required this.starting,
    required this.inventory,
    required this.templates,
    required this.stopping,
    required this.vault,
    required this.newerVersion,
    required this.sessions,
    required this.deleting,
    required this.readiness,
    required this.authentication,
    required this.following,
    required this.connections,
    this.forges,
    this.registryPages,
    this.pickAFile = pickWithTheDesktop,
    required this.backups,
    required this.narrowing,
    required this.held,
    this.walk,
    super.key,
  });

  /// A guided walk beside the window, in a development build started with one; else null.
  final WalkSession? walk;

  /// The optional verified registry adapter used by item pages.
  final RegistryPages? registryPages;

  /// Every machine being watched.
  final Machines machines;

  /// What is open and where the keyboard is.
  final ShellModel shell;

  /// How the interface looks.
  final Settings settings;

  /// What this session has run.
  final Operations operations;

  /// What this session is reading.
  final Logs logs;

  /// What is waiting at the gate of the project being looked at.
  final Gate gate;

  /// What gets told to somebody who is not looking at the window.
  final Notifications notifications;

  /// What the project being looked at may reach.
  final Egress egress;

  /// Letting work that is already running reach something new.
  final Widening widening;

  /// Starting work, and continuing a finished run.
  final StartWork starting;

  /// What agents are installed on the machine being watched.
  final AgentInventory inventory;

  /// The recurring jobs somebody named.
  final Templates templates;

  /// Cutting every form of access at once.
  final EmergencyStop stopping;

  /// What the vault holds.
  final Vault vault;

  /// Whether a newer build has been installed underneath this one.
  final NewerVersion newerVersion;

  /// The shells somebody has open inside running work.
  final Sessions sessions;

  /// Removing what Porelo built for a project.
  final ProjectDeletion deleting;

  /// Whether the machine being acted on can run anything.
  final HostReadiness readiness;

  /// What the machine being acted on can authenticate against.
  final Authentication authentication;

  /// Following a repository, which is how a project comes to a machine.
  final ProjectFollowing following;

  /// How a machine connects out.
  final Connections connections;

  /// A person's forge login and what it reaches, or null for the platform's own, made when first used.
  final ForgeConnection? forges;

  /// Asks the desktop for a file of this computer. Replaced in tests, which have no desktop.
  final PickAFile pickAFile;

  /// What has been backed up of the project being looked at.
  final Backups backups;

  /// Taking a name back from work that is already running.
  final Narrowing narrowing;

  /// What the work being looked at holds that never reached the gate.
  final WorkHeld held;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Only the appearance rebuilds the application; everything else rebuilds the frame.
    // A status line changing must not rebuild a theme.
    listenable: settings,
    builder: (context, _) => MaterialApp(
      title: productName,
      debugShowCheckedModeBanner: false,
      theme: PoreloTheme.light,
      darkTheme: PoreloTheme.dark,
      themeMode: settings.appearance,
      // Around the navigator, so the walk's panel stays usable while a dialog is open.
      builder: walk == null ? null : (context, child) => WalkFrame(walk: walk!, texts: poreloWalkTexts, child: child!),
      home: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          machines,
          shell,
          operations,
          logs,
          gate,
          notifications,
          egress,
          widening,
          starting,
          inventory,
          templates,
          stopping,
          vault,
          vault.devices,
          newerVersion,
          sessions,
          deleting,
          readiness,
          authentication,
          following,
          connections,
          backups,
          narrowing,
          held,
        ]),
        builder: (context, _) => Shell(
          machines: machines,
          shell: shell,
          settings: settings,
          operations: operations,
          logs: logs,
          gate: gate,
          notifications: notifications,
          egress: egress,
          widening: widening,
          starting: starting,
          inventory: inventory,
          templates: templates,
          stopping: stopping,
          vault: vault,
          newerVersion: newerVersion,
          sessions: sessions,
          deleting: deleting,
          readiness: readiness,
          authentication: authentication,
          following: following,
          connections: connections,
          forges: forges,
          registryPages: registryPages,
          pickAFile: pickAFile,
          backups: backups,
          narrowing: narrowing,
          held: held,
          walk: walk,
        ),
      ),
    ),
  );
}
