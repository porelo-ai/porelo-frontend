import 'package:flutter/foundation.dart';

import 'machines.dart';

/// A place in the product, reached from the rail.
///
/// Daily work first - what runs, and what needs a person - and setting up apart from it: machines
/// (where work runs) and projects (how it runs) are set up rarely and are out of the way once they
/// are. An action lives where it acts, and the finder goes there and
/// shows it.
enum Section {
  /// Every piece of work on every machine: running, waiting for a person, or stopped.
  work('Work'),

  /// What needs a person, from every machine at once.
  attention('Needs you'),

  /// Every machine watched, to set one up or look after it.
  machines('My machines'),

  /// Every forge set up on this computer: where the repositories are, and the tokens reaching them.
  forges('My forges'),

  /// Every project on every machine, to set one up or look after it.
  projects('My projects'),

  /// This person's card and key, kept in today's dialog.
  cards('My cards & keys'),

  /// The organizations read on this computer.
  organizations('Organizations'),

  /// The organization: its people, its projects, its hosts and its owners.
  organization('Organization'),

  /// One machine's details: what it is and how it stands, and its tools. Which one is
  /// `Machines.current`.
  machine('Machine'),

  /// One project's details, on its machine: its repositories, its state and its tools. Which one is
  /// the current machine's selected project.
  project('Project'),

  /// One forge's repositories. Which one is the forge connection's current entry.
  forge('Forge');

  const Section(this.label);

  /// What the rail calls it.
  final String label;
}

/// The tools and lists belonging to one machine.
enum MachineSection {
  /// Work on this machine.
  tasks('Tasks'),

  /// Projects known to this machine.
  projects('Projects'),

  /// Names and kinds held by its vault.
  vault('Vault'),

  /// Its outbound connections and destinations.
  credentials('Credentials'),

  /// Its installed agents and authentication providers.
  agents('Agents & providers'),

  /// Its readiness checks.
  health('Health'),

  /// Its lifecycle and preparation actions.
  managing('Managing this machine');

  const MachineSection(this.label);

  /// The words shown in the tree.
  final String label;

  /// What the tree calls this section on one machine: a machine with an organization's card is managed by its Machine
  /// Admins, so its managing leaf is their list, while this computer and a machine of its own keep [label].
  String labelOn({required bool organizationCard}) =>
      this == MachineSection.managing && organizationCard ? 'Machine Admins' : label;
}

/// The lists belonging to one organization.
enum OrganizationSection {
  /// Its people's cards.
  people('People'),

  /// Its registered projects.
  projects('Projects'),

  /// Its registered machines.
  machines('Machines'),

  /// The people who own the organization.
  owners('Organization owners'),

  /// The people who administer the organization.
  admins('Organization Admins');

  const OrganizationSection(this.label);

  /// The words shown in the tree.
  final String label;
}

/// An exact destination, including the owner of a machine or organization section.
@immutable
class ShellPlace {
  /// Keeps a destination without depending on the current machine selection.
  const ShellPlace(this.section, {this.machine, this.machineSection, this.organization, this.organizationSection});

  /// The top-level page or item kind.
  final Section section;

  /// The machine this place belongs to.
  final Machine? machine;

  /// Its tool or list, absent on its facts page.
  final MachineSection? machineSection;

  /// The organization's name, absent on the organizations facts page.
  final String? organization;

  /// Its list, absent on its facts page.
  final OrganizationSection? organizationSection;

  /// A machine name cannot be mistaken for a section of another machine.
  static String machineKey(String name) => 'machine ${Uri.encodeComponent(name)}';

  /// Organization names use the same unambiguous component encoding.
  static String organizationKey(String name) => 'organization ${Uri.encodeComponent(name)}';

  /// A stable tree row identity.
  String get key => switch (section) {
    Section.machine when machine != null =>
      '${machineKey(machine!.name)}${machineSection == null ? '' : ' ${machineSection!.name}'}',
    Section.organization when organization != null =>
      '${organizationKey(organization!)}${organizationSection == null ? '' : ' ${organizationSection!.name}'}',
    _ => section.name,
  };

  /// Ancestors opened to reveal this place.
  List<String> get ancestors => [
    if (machine != null) 'machines',
    if (machineSection != null) machineKey(machine!.name),
    if (organization != null) 'organizations',
    if (organizationSection != null) organizationKey(organization!),
  ];
}

/// What is open over the frame.
///
/// A closed set rather than a flag per thing: the frame is the one place everything opens over,
/// and a boolean per screen becomes a set of states that contradict each other the moment there
/// are three of them.
sealed class Opened {
  const Opened();
}

/// The frame itself, with nothing over it.
class NothingOpened extends Opened {
  /// Constructor.
  const NothingOpened();
}

/// One piece of work.
class WorkOpened extends Opened {
  /// Constructor.
  const WorkOpened();
}

/// What one operation printed.
class OperationOpened extends Opened {
  /// Constructor taking which one.
  const OperationOpened(this.id);

  /// The operation's id.
  final String id;
}

/// What is waiting at a project's gate.
class GateOpened extends Opened {
  /// Constructor.
  const GateOpened();
}

/// What a project's work may reach.
class EgressOpened extends Opened {
  /// Constructor.
  const EgressOpened();
}

/// What has been backed up of a project's mirror.
class BackupsOpened extends Opened {
  /// Constructor.
  const BackupsOpened();
}

/// What this session ran on the machine.
class OperationsOpened extends Opened {
  /// Constructor.
  const OperationsOpened();
}

/// One waiting push, being judged.
class ReviewOpened extends Opened {
  /// Constructor.
  const ReviewOpened();
}

/// One of a task's logs.
class LogOpened extends Opened {
  /// Constructor taking which log of which task.
  const LogOpened(this.task, this.log, {this.formatted = false});

  /// Whether it is read as the task's agent shows it.
  final bool formatted;

  /// The container.
  final String task;

  /// The file within its state directory.
  final String log;
}

/// The frame's own state: where you are, what is open, and what the finder is showing.
///
/// Separate from the backend's state on purpose. Losing contact with a daemon must not move
/// anybody, and opening something must not ask the daemon anything.
class ShellModel extends ChangeNotifier {
  ShellPlace _place = const ShellPlace(Section.work);
  final Set<String> _foldedOpen = {};
  bool _navigationInitialized = false;

  /// The chosen destination and its owner.
  ShellPlace get place => _place;

  /// The branches unfolded in the tree.
  Set<String> get foldedOpen => Set.unmodifiable(_foldedOpen);

  /// Opens the initial machine path before saved machines have finished loading.
  void initializeNavigation(Machine current) {
    if (!_navigationInitialized && _foldedOpen.isEmpty) {
      _foldedOpen.addAll(['machines', ShellPlace.machineKey(current.name)]);
    }
  }

  /// Restores checked navigation data, opening the first machine on a first start.
  void restoreNavigation(Map<String, Object?> saved, List<Machine> machines, Machine current) {
    try {
      if (_navigationInitialized) return;
      _navigationInitialized = true;
      _foldedOpen
        ..clear()
        ..addAll(['machines', ShellPlace.machineKey(current.name)]);
      final section = Section.values.where((value) => value.name == saved['section']).firstOrNull;
      final machine = machines.where((value) => value.name == saved['machine']).firstOrNull;
      final machineSection = MachineSection.values.where((value) => value.name == saved['machineSection']).firstOrNull;
      final organizationSection = OrganizationSection.values
          .where((value) => value.name == saved['organizationSection'])
          .firstOrNull;
      final organization = saved['organization'] is String ? saved['organization'] as String : null;
      if (section == null ||
          {Section.machine, Section.project}.contains(section) && machine == null ||
          section == Section.organization && (organization == null || organization.isEmpty) ||
          saved['organizationSection'] != null && (section != Section.organization || organizationSection == null) ||
          saved['machineSection'] != null && (section != Section.machine || machineSection == null)) {
        return;
      }
      _section = section;
      _place = ShellPlace(
        section,
        machine: {Section.machine, Section.project}.contains(section) ? machine : null,
        machineSection: section == Section.machine ? machineSection : null,
        organization: section == Section.organization ? organization : null,
        organizationSection: section == Section.organization ? organizationSection : null,
      );
      itemMachine = _place.machine;
      final validFolds = {
        'machines',
        'organizations',
        for (final each in machines) ShellPlace.machineKey(each.name),
        if (_place.organization != null) ShellPlace.organizationKey(_place.organization!),
      };
      if (saved['folded'] case final List<Object?> folds) {
        _foldedOpen
          ..clear()
          ..addAll(folds.whereType<String>().where((key) => validFolds.contains(key) || _isOrganizationFold(key)));
      }
    } finally {
      notifyListeners();
    }
  }

  bool _isOrganizationFold(String key) {
    if (!key.startsWith('organization ')) return false;
    try {
      final name = Uri.decodeComponent(key.substring('organization '.length));
      return name.isNotEmpty && ShellPlace.organizationKey(name) == key;
    } on FormatException {
      return false;
    }
  }

  /// Drops a destination whose organization has been confirmed absent or replaced.
  void checkOrganization(String? loadedName) {
    final staleFolds = _foldedOpen
        .where(
          (key) =>
              key.startsWith('organization ') && (loadedName == null || key != ShellPlace.organizationKey(loadedName)),
        )
        .toList();
    _foldedOpen.removeAll(staleFolds);
    if (_place.section == Section.organization && (_place.organization == null || _place.organization != loadedName)) {
      goTo(Section.organizations);
    } else if (staleFolds.isNotEmpty) {
      notifyListeners();
    }
  }

  /// The public navigation state kept across a restart.
  Map<String, Object?> get navigation => {
    'section': _section.name,
    if (_place.machine != null) 'machine': _place.machine!.name,
    if (_place.machineSection != null) 'machineSection': _place.machineSection!.name,
    if (_place.organization != null) 'organization': _place.organization,
    if (_place.organizationSection != null) 'organizationSection': _place.organizationSection!.name,
    'folded': _foldedOpen.toList(),
  };

  /// Folds a branch without changing the chosen page.
  void toggleFold(String key) {
    if (!_foldedOpen.remove(key)) _foldedOpen.add(key);
    notifyListeners();
  }

  /// Selects an exact place; selecting a chosen parent again folds it.
  void choosePlace(ShellPlace next, {bool branch = false}) {
    final same = _place.key == next.key;
    _foldedOpen.addAll(next.ancestors);
    if (branch && same) {
      toggleFold(next.key);
      return;
    }
    if (branch) _foldedOpen.add(next.key);
    _place = next;
    itemMachine = next.machine;
    itemProject = null;
    _goTo(next.section);
    notifyListeners();
  }

  /// Reveals the chosen row when a phone drawer opens.
  void revealPlace() {
    _foldedOpen.addAll(_place.ancestors);
    notifyListeners();
  }

  /// The explicitly opened item, including machines not followed locally.
  Machine? itemMachine;

  /// The explicitly opened project, followed here or not.
  String? itemProject;

  /// Opens a machine without substituting the current local selection.
  void openMachine(Machine machine) {
    itemMachine = machine;
    itemProject = null;
    _place = ShellPlace(Section.machine, machine: machine);
    _foldedOpen.addAll(['machines', ShellPlace.machineKey(machine.name)]);
    _goTo(Section.machine);
    notifyListeners();
  }

  /// Opens a project using the full machine/project identity.
  void openProject(Machine machine, String project) {
    itemMachine = machine;
    itemProject = project;
    _place = ShellPlace(Section.project, machine: machine);
    _foldedOpen.addAll(['machines', ShellPlace.machineKey(machine.name)]);
    _goTo(Section.project);
    notifyListeners();
  }

  Section _section = Section.work;
  Opened _opened = const NothingOpened();
  String? _highlight;

  /// Where in the product you are.
  Section get section => _section;

  /// What is open over the frame.
  Opened get opened => _opened;

  /// Whether anything is open over the frame.
  bool get anythingOpen => _opened is! NothingOpened;

  /// Whether the open thing is a piece of work.
  bool get detailOpen => _opened is WorkOpened;

  /// The command the finder went to, marked where it lives until something else happens.
  String? get highlight => _highlight;

  /// Goes to a section, closing whatever was open over the one before.
  void goTo(Section section) {
    final hadItem = itemMachine != null || itemProject != null;
    itemMachine = null;
    itemProject = null;
    _place = ShellPlace(section);
    if (section == Section.machines || section == Section.organizations) _foldedOpen.add(section.name);
    _goTo(section);
    if (hadItem) notifyListeners();
  }

  void _goTo(Section section) {
    if (_section == section && !anythingOpen && _highlight == null) return;
    _section = section;
    _opened = const NothingOpened();
    _highlight = null;
    notifyListeners();
  }

  /// Shows where [command] lives - [section], which the command's home says - with nothing open over
  /// it.
  void show(String command, {Section section = Section.machine}) {
    itemMachine = null;
    itemProject = null;
    _place = ShellPlace(section);
    _section = section;
    _opened = const NothingOpened();
    _highlight = command;
    notifyListeners();
  }

  /// Reveals [command] on the open item while it stays open.
  void showOnItem(String command) {
    _opened = const NothingOpened();
    _highlight = command;
    notifyListeners();
  }

  /// Stops marking where a command lives.
  void shown() {
    if (_highlight == null) return;
    _highlight = null;
    notifyListeners();
  }

  /// Opens the selected work over whatever is showing.
  void openDetail() => _open(const WorkOpened());

  /// Opens what one operation printed.
  void openOperation(String id) => _open(OperationOpened(id));

  /// Opens what this session ran on the machine.
  void openOperations() => _open(const OperationsOpened());

  /// Opens one of a task's logs.
  void openLog(String task, String log, {bool formatted = false}) => _open(LogOpened(task, log, formatted: formatted));

  /// Opens what is waiting at the selected project's gate.
  void openGate() => _open(const GateOpened());

  /// Opens the push being judged.
  void openReview() => _open(const ReviewOpened());

  /// Opens what the selected project's work may reach.
  void openEgress() => _open(const EgressOpened());

  /// Opens what has been backed up of the selected project.
  void openBackups() => _open(const BackupsOpened());

  /// Whether Escape can dismiss an overlay or return from a machine tool to its facts.
  bool get canClose => anythingOpen || _onMachineTool;

  bool get _onMachineTool =>
      _place.section == Section.machine &&
      _place.machine != null &&
      {
        MachineSection.vault,
        MachineSection.credentials,
        MachineSection.agents,
        MachineSection.health,
      }.contains(_place.machineSection);

  /// Closes an overlay, or returns from a machine tool to its named machine's facts.
  void close() {
    if (!canClose) return;
    final returnToMachine = !anythingOpen && _onMachineTool;
    _opened = const NothingOpened();
    if (returnToMachine) {
      openMachine(_place.machine!);
      return;
    }
    notifyListeners();
  }

  void _open(Opened what) {
    final open = _opened;
    final same = switch ((open, what)) {
      (OperationOpened(:final id), OperationOpened(id: final next)) => id == next,
      (LogOpened(:final task, :final log), LogOpened(task: final t, log: final l)) => task == t && log == l,
      (OperationOpened() || LogOpened(), _) => false,
      _ => open.runtimeType == what.runtimeType,
    };
    if (same && _highlight == null) return;
    _opened = what;
    _highlight = null;
    notifyListeners();
  }
}
