import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:guided_walk/guided_walk.dart';

import 'src/app/egress.dart';
import 'src/app/gate.dart';
import 'src/app/host_readiness.dart';
import 'src/app/logs.dart';
import 'src/app/notifications.dart';
import 'src/app/machines.dart';
import 'src/app/narrowing.dart';
import 'src/app/newer_version.dart';
import 'src/app/one_instance.dart';
import 'src/app/where_you_were.dart';
import 'src/app/agent_inventory.dart';
import 'src/app/authentication.dart';
import 'src/app/emergency_stop.dart';
import 'src/app/start_work.dart';
import 'src/app/templates.dart';
import 'src/app/keystore.dart';
import 'src/app/vault.dart';
import 'src/app/widening.dart';
import 'src/app/work_held.dart';
import 'src/app/window.dart';
import 'src/app/operations.dart';
import 'src/app/backups.dart';
import 'src/app/connections.dart';
import 'src/app/project_following.dart';
import 'src/app/project_deletion.dart';
import 'src/app/desk.dart';
import 'src/app/fleet_backend.dart';
import 'src/app/registry.dart';
import 'src/app/registry_checkout.dart';
import 'src/app/registry_pages.dart';
import 'src/app/registry_read_source.dart';
import 'src/app/session.dart';
import 'src/app/settings.dart';
import 'src/app/shell_model.dart';
import 'src/app/porelo_app.dart';
import 'src/app/roles.dart';
import 'src/ui/choice_field.dart';
import 'src/ui/terminal_diagnosis.dart';
import 'src/ui/theme.dart';
import 'src/ui/walk_texts.dart';

/// Starts the interface with the roles supplied for this process.
Future<void> main(List<String> arguments) async {
  try {
    roles = Roles.fromArguments(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  // What reaches the terminal widget on this system, shown and logged; no task, nothing changed.
  if (arguments.contains('--diagnose-terminal')) {
    runApp(const TerminalDiagnosisApp());
    return;
  }
  // Started by the interface as the guided walk's own window: the panel and nothing else, before the
  // interface's one-instance lock would send it away.
  if (walkWindowPath() case final path?) {
    runApp(WalkWindowApp(path, theme: PoreloTheme.light, darkTheme: PoreloTheme.dark, texts: poreloWalkTexts));
    return;
  }
  runApp(await porelo());
}

/// The interface, composed once per process and handed back again on every later call.
///
/// An integration test shows it anew for each scenario, because the test framework clears the
/// widget tree between them; composing it again would find its own instance lock and leave.
Future<PoreloApp> porelo() => _composed ??= _compose();

/// The guided walk named by `PORELO_WALK`, in a development build started with one; else null. A
/// step waiting for one of Porelo's own choices to be made sees it made.
WalkSession? _walk() {
  final walk = WalkSession.fromEnvironment(variable: 'PORELO_WALK');
  if (walk == null) return null;
  walkChoices.add((widget) => widget is ChoiceField ? widget.value != null : null);
  return walk..start();
}

Future<PoreloApp>? _composed;

/// Every registry list, read by this computer's daemon from a private checkout of the address chosen once.
RegistryPages? _registryPages(Settings settings, Machines machines) {
  final repository = settings.registryRepository;
  if (repository == null) return null;
  final registry = Registry(
    checkout: RegistryCheckout(root: '${desk.data}/registry', repository: repository),
    core: DaemonRegistryCore(PoreloBackend(Machines.backendFor(Machine.local()))),
  );
  return RegistryPages(
    source: RegistryReadSource(registry: registry, repository: repository, machines: () => machines.all),
    features: const RegistryPageFeatures(operations: {RegistryOperation.refresh}),
  );
}

Future<PoreloApp> _compose() async {
  final settings = Settings(FileSettingsStore());
  await settings.load();

  final shell = ShellModel();
  // Read rather than awaited: a named job that arrives a frame late costs nothing, and the
  // window opening does not wait on a file.
  final templates = Templates(settings);
  unawaited(templates.load());
  final machines = Machines(settings, lookFor: Machine.mock());

  // Two interfaces watching the same machines raise every question twice and answer it from
  // whichever window somebody happened to see. A second launch asks the first to come forward and
  // then leaves, saying so — a launch that simply vanished would read as one that crashed.
  final only = await OneInstance.take(comeForward: Window.comeForward);
  if (!only.inCharge) {
    stderr.writeln(
      'Porelo is already open, and has been brought to the front. '
      'One interface watches each machine: a second would raise every decision twice.',
    );
    exit(0);
  }

  final newerVersion = NewerVersion()..watch();
  // Nothing is opened here: a session exists only once somebody asks for one, and the list is
  // what makes several of them tellable apart.
  final sessions = Sessions();
  final whereYouWere = WhereYouWere(settings, machines, shell);
  final operations = Operations(store: FileOperationsStore());
  await operations.load();
  final notifications = Notifications(DesktopNotifier(), settings)..watchOperations(operations, open: (_) {});
  await notifications.load();
  final app = PoreloApp(
    machines: machines,
    shell: shell,
    settings: settings,
    operations: operations,
    logs: Logs(),
    gate: Gate(),
    notifications: notifications,
    egress: Egress(),
    widening: Widening(),
    starting: StartWork(),
    inventory: AgentInventory(),
    templates: templates,
    stopping: EmergencyStop(),
    vault: Vault(keys: PlatformDeviceKeyStore()),
    newerVersion: newerVersion,
    sessions: sessions,
    deleting: ProjectDeletion(),
    readiness: HostReadiness(),
    authentication: Authentication(),
    following: ProjectFollowing(),
    connections: Connections(),
    backups: Backups(),
    narrowing: Narrowing(),
    held: WorkHeld(),
    registryPages: _registryPages(settings, machines),
    // A development build started with PORELO_WALK=<folder>; a release build never has one.
    walk: _walk(),
  );

  // Deliberately after the first frame: the window opens and says it is connecting, rather
  // than staying blank until a socket answers or does not. Every machine at once, because a
  // clearance prompt has a deadline and one nobody is connected to expires unseen.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(
      machines.load().then((_) async {
        await whereYouWere.restore();
        // Every machine, including one added later: a question has a deadline and is asked once.
        notifications.watchMachines(machines, open: (_) => shell.goTo(Section.attention));
      }),
    ),
  );
  return app;
}
