import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart' show checkHostName;

import '../app/commands.dart';
import '../app/identity.dart';
import '../app/key_recovery.dart' show BackupScope;
import '../app/organization_source.dart';
import '../client/models.dart' show defaultProject;
import 'command_menu.dart';
import 'identity_view.dart';
import 'filtered_list_section.dart';
import 'organization_token_words.dart' show forgeOrganizationWords;
import 'organization_dialogs.dart';
import 'how_long.dart';
import 'key_recovery_dialog.dart';
import 'organization_host_pages.dart';
import 'pick_a_file.dart';
import 'placing_project_dialog.dart';
import 'project_init_dialog.dart';
import 'tokens.dart';
import 'window_size.dart';

/// What is true of a project's name, as for any folder it becomes.
final _projectName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

/// The organization: who manages it, its people, its projects and its machines. Everyone reads all of it; a row's actions stand
/// behind its ⋮, for the person whose role they belong to.
class OrganizationPage extends StatefulWidget {
  /// Reads [organization].
  const OrganizationPage({
    required this.organization,
    this.onProject,
    this.onHost,
    this.connections,
    this.onGiveToken,
    this.identity,
    this.prepareMachine,
    this.onPrepare,
    this.takeOff,
    this.keys,
    this.pickFile = pickWithTheDesktop,
    this.pickFolder = pickFolderWithTheDesktop,
    super.key,
  });

  /// The organization.
  final Organization organization;

  /// The local card, shared with the card dialog when this page runs in the frame.
  final IdentityModel? identity;

  /// Opens a project the person is in under *Projects*.
  final void Function(String project)? onProject;

  /// Opens a host's page for its host admin.
  final void Function(String host)? onHost;

  /// This person's connections to the machines, absent where this computer has none to make.
  final HostConnections? connections;

  /// Gives the host admin's token to a machine; answers the words to show, if any.
  final Future<String?> Function(String host)? onGiveToken;

  /// *Prepare a machine…*, absent where this computer offers none.
  final Command? prepareMachine;

  /// Prepares the machine named, absent where this computer offers none.
  final void Function(String host)? onPrepare;

  /// Taking Porelo off a machine, or returning its rental, as its row offers it to who may.
  final Command Function(OrganizationHost host)? takeOff;

  /// Runs the person's key commands in a terminal, absent where this computer offers none.
  final KeyCommands? keys;

  /// Chooses the file of a card someone handed over.
  final PickAFile pickFile;

  /// Chooses a checkout folder to preview before signing it into a project.
  final PickAFolder pickFolder;

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.organization.refresh());
    final identity = widget.identity;
    if (identity != null && !identity.busy) unawaited(identity.load());
  }

  @override
  Widget build(BuildContext context) {
    final organization = widget.organization;
    return ListenableBuilder(
      listenable: organization,
      builder: (context, _) {
        final view = organization.view;
        return ListView(
          key: const Key('organization-page'),
          padding: const EdgeInsets.all(Space.normal),
          children: [
            if (widget.identity case final identity?) IdentityRenewal(model: identity, showProblems: true),
            OrganizationChangeMark(organization),
            if (!organization.explanationClosed)
              _Explanation(view: view, onHide: () => setState(() => organization.explanationClosed = true)),
            if (organization.noOrganization && view == null)
              _NoOrganization(
                onChoose: () => _show(context, _AddressDialog(organization)),
                onCreate: () => _show(context, _AddressDialog(organization, creating: true)),
                onCard: () => _show(context, _KeyDialog(organization, adding: true)),
              )
            else if (organization.problem case final problem?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.small),
                child: Text(problem, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (view != null) ..._organization(context, organization, view),
          ],
        );
      },
    );
  }

  void _show(BuildContext context, Widget dialog) =>
      unawaited(showDialog<void>(context: context, builder: (_) => dialog));

  Future<void> _replaceLostKey(OrganizationView view, Organization organization) async {
    await widget.keys!.replaceLostKey(
      context,
      places: [
        if (view.owners.contains(view.me)) const BackupScope.organization(),
        for (final host in view.hosts)
          if (host.admins.contains(view.me)) BackupScope.host(host.name),
      ],
      base: view.revision,
    );
    await organization.refresh();
  }

  Future<void> _makeBackupKey(OrganizationView view, Organization organization) async {
    await widget.keys!.makeBackup(context, scope: const BackupScope.organization(), base: view.revision);
    await organization.refresh();
  }

  List<Widget> _organization(BuildContext context, Organization organization, OrganizationView view) {
    final text = Theme.of(context).textTheme;
    void show(Widget dialog) => unawaited(showDialog<void>(context: context, builder: (_) => dialog));
    final read = howLongSince(organization.readAt);
    return [
      if (view.myCard == null) _NoCard(view: view, onAdd: () => show(_KeyDialog(organization, adding: true))),
      Text(view.name, style: text.headlineSmall),
      Text('Kept in ${view.keptIn} · keys vouched for by ${view.vouchedBy}'),
      Text([_myCardWords(view), ?_rolesWords(view), if (read != null) 'read $read ago'].join(' · ')),
      if (view.stale)
        Text(
          key: const Key('organization-stale'),
          'The store could not be reached, so this is the last state read; it may have moved on.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      for (final note in view.notes) Text(note),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('chooseOrganization'),
          onPressed: () => show(_AddressDialog(organization, replacing: true)),
          child: const Text('Choose another Porelo organization…'),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('createAnotherOrganization'),
          onPressed: () => show(_AddressDialog(organization, creating: true, replacing: true)),
          child: const Text('Create another Porelo organization…'),
        ),
      ),
      const SizedBox(height: Space.normal),
      _people(view, organization, show),
      _projects(view, organization, show),
      _hosts(view, organization, show),
      _owners(view, organization, show),
      ?_organizationAdmins(view, organization, show),
    ];
  }

  Widget _people(OrganizationView view, Organization organization, void Function(Widget) show) => FilteredListSection(
    title: 'People',
    storageId: 'organization-people',
    collapsible: true,
    sorts: [
      SectionSort('Name', (row) => view.persons[row].login),
      SectionSort('State', (row) => _standingWords(view.persons[row])),
    ],
    rows: [
      for (final person in view.persons)
        (
          words: person.login,
          child: _Row(
            icon: person.standing == CardStanding.revoked ? Icons.person_off_outlined : Icons.person_outline,
            title: person.login == view.me ? '${person.login} (you)' : person.login,
            subtitle: _personWords(view, person),
            state: _standingWords(person),
            tone: _toneOf(person.standing),
            actions: [
              if (person.login == view.me && view.holdsRoles) ...[
                _command('changeCard', 'Change my key', () => show(_KeyDialog(organization, adding: false))),
                _command(
                  'withdrawCard',
                  'Withdraw my card',
                  danger: true,
                  () => show(
                    OrganizationConfirmDialog(
                      organization,
                      title: 'Withdraw your card?',
                      words:
                          'Your key is revoked, and each machine takes that within five minutes, or at once on its '
                          'Refresh. You hold no role until you come back with a new card and a new key. Your places '
                          'in projects and on machines stay under your login: to leave them for good, have yourself '
                          'removed from each as well.',
                      confirm: 'Withdraw my card',
                      change: OrganizationChange.revokeCard,
                      input: {'login': view.me},
                    ),
                  ),
                ),
              ],
              // Not gated on the card's standing: a revoked key is what this replaces.
              if (person.login == view.me && widget.keys != null)
                _command('replaceLostKey', 'Replace a lost key…', () => unawaited(_replaceLostKey(view, organization))),
              if (person.login != view.me && view.isOrganizationAdmin)
                _command(
                  'replaceCard/${person.login}',
                  'Accept a new card…',
                  () => show(_AcceptCardDialog(organization, login: person.login, pickFile: widget.pickFile)),
                ),
              if (person.login != view.me && view.isOrganizationAdmin && person.standing != CardStanding.revoked)
                _command(
                  'revokeCard/${person.login}',
                  'Revoke the card…',
                  danger: true,
                  () => show(
                    OrganizationConfirmDialog(
                      organization,
                      title: "Revoke ${person.login}'s card?",
                      words:
                          "${person.login}'s key is revoked, and each machine takes that within five minutes, or at once "
                          'on its Refresh. They hold no role until they come back with a new card and a new key. Their '
                          'places in projects and on machines stay under their login: to put them out, also remove them '
                          'from each project and machine.',
                      confirm: 'Revoke the card',
                      change: OrganizationChange.revokeCard,
                      input: {'login': person.login},
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  ).withOrganizationChanges(organization, names: [for (final person in view.persons) person.login]);

  /// A project just put on a machine waits for a token: once it was taken, the machine is asked to fetch at once.
  Future<void> _putOn(OrganizationProject project, OrganizationView view, void Function(Widget) show) async {
    await showDialog<void>(
      context: context,
      builder: (_) => OrganizationPersonDialog(
        widget.organization,
        people: [for (final host in _hostsOf(view)) host.name],
        helper: 'A project is on one machine at a time.',
        title: 'Put ${project.name} on a machine',
        personLabel: 'Machine',
        words:
            'Every member comes with the project. Next this follows the machine: it connects, offers to give the '
            'machine your token once if it waits for one, and says when the project is carried or why not. '
            'This can take up to five minutes.',
        confirm: 'Put it on the machine',
        change: OrganizationChange.addProjectToHost,
        input: (_, machine) => {'host': machine, 'project': project.name},
      ),
    );
    await widget.organization.whenIdle;
    final machine = widget.organization.view?.hosts
        .where((host) => host.projects.contains(project.name))
        .firstOrNull
        ?.name;
    final connections = widget.connections;
    if (machine == null || connections == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => PlacingProjectDialog(
        project: project.name,
        host: machine,
        view: widget.organization.view,
        connections: connections,
        onGiveToken: widget.onGiveToken,
      ),
    );
  }

  Widget _projects(OrganizationView view, Organization organization, void Function(Widget) show) =>
      FilteredListSection(
        title: 'Projects',
        storageId: 'organization-projects',
        collapsible: true,
        openWhenCompact: false,
        sorts: [
          SectionSort('Name', (row) => view.projects[row].name),
          SectionSort('State', (row) => _standingIn(view, view.projects[row])),
          SectionSort(
            'Machine',
            (row) =>
                view.hosts.where((host) => host.projects.contains(view.projects[row].name)).firstOrNull?.name ?? '',
          ),
        ],
        commands: [
          if (view.isOrganizationAdmin)
            _command('addProject', 'Add a project', () => show(_AddProjectDialog(organization, view))).command,
        ],
        rows: [
          for (final project in view.projects)
            (
              words: '${project.name} ${project.admins.join(' ')}',
              child: _Row(
                icon: Icons.folder_outlined,
                title: project.name,
                subtitle: _projectWords(project),
                state: _standingIn(view, project),
                below: view.saysNoRepository(project) ? _noRepository(view, organization, project, show) : null,
                actions: [
                  if (!view.saysNoRepository(project) &&
                      view.holdsRoles &&
                      widget.onProject != null &&
                      _isIn(view, project))
                    _command('goToProject/${project.name}', 'Go to the project', () => widget.onProject!(project.name)),
                  // It files what a checkout holds in the project's own repository, so that comes first.
                  if (!view.saysNoRepository(project) &&
                      (view.isOrganizationAdmin || (view.holdsRoles && project.admins.contains(view.me))))
                    _command(
                      'initializeProject/${project.name}',
                      'Fill it from a checkout…',
                      () => show(
                        ProjectInitDialog(
                          organization: organization,
                          project: project.name,
                          pickFolder: widget.pickFolder,
                        ),
                      ),
                    ),
                  if (project.host == null && _hostsOf(view).isNotEmpty)
                    _command(
                      'putOnMachine/${project.name}',
                      'Put it on a machine…',
                      () => unawaited(_putOn(project, view, show)),
                    ),
                  if (project.host case final machine? when _hostsOf(view).any((host) => host.name == machine))
                    _command(
                      'takeOffMachine/${project.name}',
                      'Take it off the machine…',
                      danger: true,
                      () => show(
                        OrganizationConfirmDialog(
                          organization,
                          title: 'Take ${project.name} off $machine?',
                          words:
                              'Its members can no longer work on it there, once it holds no unpushed work. Its copy there '
                              'goes then, with its conversation, where the machine runs its own. The project itself stays '
                              'in the organization. This can take up to five minutes.',
                          confirm: 'Take it off',
                          change: OrganizationChange.removeProjectFromHost,
                          input: {'host': machine, 'project': project.name},
                        ),
                      ),
                    ),
                  if (view.isOrganizationAdmin) ...[
                    _command(
                      'addProjectAdmin/${project.name}',
                      'Add an admin…',
                      () => show(
                        OrganizationPersonDialog(
                          organization,
                          people: [
                            for (final person in view.holdingRoles)
                              if (!project.admins.contains(person.login)) person.login,
                          ],
                          title: 'Another admin of ${project.name}',
                          personLabel: 'Project Admin',
                          words:
                              'They may change its members and repositories. An owner may do this much in a project, for '
                              'when its admins have lost their keys, and nothing else there.',
                          confirm: 'Add them',
                          change: OrganizationChange.addProjectMember,
                          // A member already there is added by nothing: their role is what changes.
                          changeFor: (person) => project.members.contains(person)
                              ? OrganizationChange.changeProjectMemberRole
                              : OrganizationChange.addProjectMember,
                          input: (_, person) => {'project': project.name, 'login': person, 'role': 'admin'},
                        ),
                      ),
                    ),
                    for (final admin in project.admins)
                      _command(
                        'removeProjectAdmin/${project.name}/$admin',
                        'Remove $admin as admin…',
                        danger: true,
                        () => show(
                          OrganizationConfirmDialog(
                            organization,
                            title: 'Remove $admin as an admin of ${project.name}?',
                            words: project.admins.length == 1
                                ? '$admin is its last admin: nobody can change this project until you add another.'
                                : '$admin leaves the project, and its other admins go on.',
                            confirm: 'Remove',
                            change: OrganizationChange.removeProjectMember,
                            input: {'project': project.name, 'login': admin},
                          ),
                        ),
                      ),
                    _command(
                      'changeProjectAdmin/${project.name}',
                      'Change the Project Admin…',
                      () => show(
                        OrganizationPersonDialog(
                          organization,
                          title: 'Another Project Admin for ${project.name}',
                          personLabel: 'Project Admin',
                          words:
                              'They become the first admin on its card, and may change its members and repositories.',
                          confirm: 'Name them',
                          change: OrganizationChange.changeProjectAdmin,
                          input: (_, person) => {'project': project.name, 'admin': person},
                        ),
                      ),
                    ),
                    _command(
                      'removeProject/${project.name}',
                      'Remove the project…',
                      danger: true,
                      () => show(
                        OrganizationConfirmDialog(
                          organization,
                          title: 'Remove ${project.name}?',
                          words: _removingProjectWords(project),
                          confirm: 'Remove the project',
                          change: OrganizationChange.removeProject,
                          input: {'project': project.name},
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ).withOrganizationChanges(
        organization,
        names: [for (final project in view.projects) project.name],
        reviewProject: widget.onProject,
      );

  /// What comes next for a project with no Git repository: its Project Admin makes it, here.
  Widget _noRepository(
    OrganizationView view,
    Organization organization,
    OrganizationProject project,
    void Function(Widget) show,
  ) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: Space.normal,
    runSpacing: Space.small,
    children: [
      if (view.holdsRoles && project.admins.contains(view.me)) ...[
        Text('${project.name} has no Git repository yet.', key: ValueKey('no-repository ${project.name}')),
        FilledButton(
          key: ValueKey('organization.createRepository ${project.name}'),
          onPressed: () => show(CreateRepositoryDialog(organization, project.name)),
          child: const Text("Create the project's Git repository"),
        ),
      ] else
        Text(
          '${project.name} has no Git repository yet. It waits for ${project.admins.isEmpty ? 'its Project Admin' : project.admins.join(' or ')}.',
          key: ValueKey('no-repository ${project.name}'),
        ),
    ],
  );

  Widget _hosts(OrganizationView view, Organization organization, void Function(Widget) show) => FilteredListSection(
    title: 'Machines',
    storageId: 'organization-hosts',
    collapsible: true,
    openWhenCompact: false,
    sorts: [
      SectionSort('Name', (row) => view.hosts[row].name),
      SectionSort('State', (row) => _hostWords(view.hosts[row])),
    ],
    commands: [
      ?widget.prepareMachine,
      if (view.isOrganizationAdmin)
        _command(
          'addHost',
          'Add a machine',
          () => show(
            OrganizationPersonDialog(
              organization,
              title: 'Add a machine to ${view.name}',
              nameLabel: 'Name',
              nameHint: 'e.g. build-2',
              personLabel: 'First Machine Admin',
              words:
                  "The machine's card is added with its name and first Machine Admin. The Machine Admin enters its address "
                  "and SSH key when they set the machine up, then puts projects on it and names further Machine "
                  "Admins, all on the machine's page under My machines.",
              confirm: 'Add the machine',
              check: (name) {
                try {
                  checkHostName(name);
                  return null;
                } on FormatException {
                  return 'Use one DNS label for the machine name.';
                }
              },
              change: OrganizationChange.addHost,
              input: (name, person) => {'host': name, 'admin': person},
            ),
          ),
        ).command,
    ],
    rows: [
      for (final host in view.hosts)
        (
          words: '${host.name} ${host.admins.join(' ')} ${host.projects.join(' ')}',
          child: OrganizationMachineRow(
            key: ValueKey('organization-machine ${host.name}'),
            view: view,
            host: host,
            words: _hostWords(host),
            connections: widget.connections,
            onOpen: () => widget.onHost?.call(host.name),
            onPrepare: widget.onPrepare == null ? null : () => widget.onPrepare!(host.name),
            commands: [
              if (widget.takeOff != null &&
                  (view.mayRemove(host) || (view.holdsRoles && host.admins.contains(view.me))))
                widget.takeOff!(host),
              for (final action in <_Action>[
                if (view.holdsRoles && widget.onHost != null && host.admins.contains(view.me) && host.address != null)
                  _command('openHost/${host.name}', 'Go to the machine', () => widget.onHost!(host.name)),
                if (view.holdsRoles && host.admins.contains(view.me) && host.hasNoReach)
                  _command(
                    'enterHost/${host.name}',
                    'Enter address and key…',
                    () => show(HostAddressDialog(organization, host)),
                  ),
                if (view.mayRemove(host))
                  _command(
                    'removeHost/${host.name}',
                    'Remove the machine…',
                    danger: true,
                    () => show(
                      OrganizationConfirmDialog(
                        organization,
                        title: 'Remove ${host.name}?',
                        words: _removingHostWords(host),
                        confirm: 'Remove the machine',
                        change: OrganizationChange.removeHost,
                        input: {'host': host.name},
                      ),
                    ),
                  ),
              ])
                action.command,
            ],
          ),
        ),
    ],
  ).withOrganizationChanges(organization, names: [for (final host in view.hosts) host.name]);

  Widget _owners(OrganizationView view, Organization organization, void Function(Widget) show) => FilteredListSection(
    title: 'Organization owners',
    storageId: 'organization-owners',
    collapsible: true,
    openWhenCompact: false,
    commands: [
      if (view.isOwner)
        _command(
          'addOrganizationOwner',
          'Add an organization owner',
          () => show(
            OrganizationPersonDialog(
              organization,
              title: 'Another organization owner of ${view.name}',
              personLabel: 'Organization owner',
              people: [
                for (final person in view.holdingRoles)
                  if (!view.owners.contains(person.login)) person.login,
              ],
              words: 'They may change its projects, its machines and its owners, as you may.',
              confirm: 'Name them',
              change: OrganizationChange.addOrganizationOwner,
              input: (_, person) => {'login': person},
            ),
          ),
        ).command,
    ],
    rows: [
      for (final owner in view.owners)
        (
          words: owner,
          child: _Row(
            icon: Icons.shield_outlined,
            title: owner == view.me ? '$owner (you)' : owner,
            subtitle: view.ownersWithBackup.contains(owner)
                ? 'organization owner · has a backup key'
                : 'organization owner',
            actions: [
              if (owner == view.me && view.isOwner && widget.keys != null)
                _command('makeBackupKey', 'Make a backup key…', () => unawaited(_makeBackupKey(view, organization))),
              // The last owner cannot be removed, so nothing offers it.
              if (view.isOwner && view.owners.length > 1)
                _command(
                  'removeOrganizationOwner/$owner',
                  'Remove',
                  danger: true,
                  () => show(
                    OrganizationConfirmDialog(
                      organization,
                      title: 'Remove $owner as an organization owner?',
                      words: owner == view.me
                          ? 'You no longer change its projects, its machines or its owners.'
                          : '$owner no longer changes its projects, its machines or its owners.',
                      confirm: 'Remove',
                      change: OrganizationChange.removeOrganizationOwner,
                      input: {'login': owner},
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  ).withOrganizationChanges(organization, names: view.owners);
}

/// One action in a row of the organization's page.
Widget? _organizationAdmins(OrganizationView view, Organization organization, void Function(Widget) show) {
  final listed = view.organizationAdmins;
  if (listed == null && !view.isOwner) return null;
  final admins = listed ?? const <String>[];
  return FilteredListSection(
    title: 'Organization Admins',
    storageId: 'organization-admins',
    collapsible: true,
    openWhenCompact: false,
    commands: [
      if (view.isOwner)
        _command(
          'addOrganizationAdmin',
          'Add an Organization Admin',
          () => show(
            OrganizationPersonDialog(
              organization,
              title: 'List an Organization Admin of ${view.name}',
              personLabel: 'Organization Admin',
              people: [
                for (final person in view.holdingRoles)
                  if (!admins.contains(person.login)) person.login,
              ],
              words: listed == null
                  ? 'From this first listing on, only the people listed do this work: an owner not listed no longer '
                        'does, and may list themselves.'
                  : 'They may change its cards, projects and machines, and name the admins of those.',
              confirm: 'List them',
              change: OrganizationChange.addOrganizationAdmin,
              input: (_, person) => {'login': person},
            ),
          ),
        ).command,
    ],
    rows: [
      for (final admin in admins)
        (
          words: admin,
          child: _Row(
            icon: Icons.admin_panel_settings_outlined,
            title: admin == view.me ? '$admin (you)' : admin,
            subtitle: 'Organization Admin',
            actions: [
              if (view.isOwner)
                _command(
                  'removeOrganizationAdmin/$admin',
                  'Remove…',
                  danger: true,
                  () => show(
                    OrganizationConfirmDialog(
                      organization,
                      title: 'Remove $admin as an Organization Admin?',
                      words: admins.length == 1
                          ? '$admin is the last one listed: nobody does this work until you list another.'
                          : '$admin no longer changes its cards, projects or machines.',
                      confirm: 'Remove',
                      change: OrganizationChange.removeOrganizationAdmin,
                      input: {'login': admin},
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  ).withOrganizationChanges(organization, names: admins);
}

/// Adds a project; whoever names themselves makes its repository in the same step, and says about review here.
class _AddProjectDialog extends StatefulWidget {
  const _AddProjectDialog(this.organization, this.view);

  final Organization organization;
  final OrganizationView view;

  @override
  State<_AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<_AddProjectDialog> {
  String? _review;

  @override
  Widget build(BuildContext context) => OrganizationPersonDialog(
    widget.organization,
    title: 'Add a project to ${widget.view.name}',
    nameLabel: 'Name',
    nameHint: 'e.g. sprint7-demo',
    personLabel: 'Project Admin',
    words:
        "The project's card is added to the Porelo organization now. Its Project Admin makes the project's Git "
        'repository and signs its first project.yml when they create its Git repository, on its row here, then adds '
        "its members. No machine is chosen here: a machine's admin puts the project on it. A project cannot hold a "
        'repository of its own name, so name it apart from its first repository.',
    confirm: 'Add the project',
    check: (name) => name.toLowerCase() == defaultProject
        ? 'Default is the project every machine has. Give this one another name.'
        : _projectName.hasMatch(name)
        ? null
        : 'A project name holds letters, digits, ".", "_" and "-", and opens with a letter or digit.',
    change: OrganizationChange.addProject,
    input: (name, person) => {'project': name, 'admin': person, if (person == widget.view.me) 'review': _review!},
    ready: (person) => person != widget.view.me || _review != null,
    below: (person, changed) => person != widget.view.me
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Space.small),
              const Text("You are its Project Admin, so its Git repository is created with it, with your forge token."),
              ProjectReviewChoice(
                review: _review,
                onChosen: (review) {
                  setState(() => _review = review);
                  changed();
                },
              ),
            ],
          ),
  );
}

class _Action {
  const _Action(this.command, {required this.danger});

  final Command command;
  final bool danger;
}

_Action _command(String id, String label, VoidCallback run, {bool danger = false}) => _Action(
  organizationCommand(id: id, label: label, run: run, danger: danger),
  danger: danger,
);

/// The machines this person administers, read from the organization, connected or not.
List<OrganizationHost> _hostsOf(OrganizationView view) => !view.holdsRoles
    ? const []
    : [
        for (final host in view.hosts)
          if (host.admins.contains(view.me)) host,
      ];

bool _isIn(OrganizationView view, OrganizationProject project) =>
    project.admins.contains(view.me) || project.members.contains(view.me);

String _myCardWords(OrganizationView view) => switch (view.myCard?.standing) {
  null => 'My card: none yet',
  CardStanding.trusted => 'My card: filed, trusted',
  CardStanding.notYet => 'My card: filed, not yet vouched for',
  CardStanding.refused => 'My card: refused',
  CardStanding.revoked => 'My card: revoked',
};

String? _rolesWords(OrganizationView view) {
  if (!view.holdsRoles) return null;
  final roles = [
    if (view.isOwner) 'an organization owner',
    if (view.isOrganizationAdmin) 'an Organization Admin',
    for (final host in view.hosts)
      if (host.admins.contains(view.me)) 'Machine Admin of ${host.name}',
  ];
  return roles.isEmpty ? null : 'you are ${roles.join(' and ')}';
}

String _personWords(OrganizationView view, OrganizationPerson person) => [
  person.key ?? 'its key could not be read',
  if (person.expires case final expires?) 'until $expires',
  if (view.owners.contains(person.login)) 'organization owner',
  for (final host in view.hosts)
    if (host.admins.contains(person.login)) 'Machine Admin of ${host.name}',
  for (final project in view.projects)
    if (project.admins.contains(person.login))
      'Project Admin of ${project.name}'
    else if (project.members.contains(person.login))
      'developer of ${project.name}',
].join(' · ');

String _standingWords(OrganizationPerson person) => switch (person.standing) {
  CardStanding.trusted => (person.words?.isEmpty ?? true) ? 'trusted' : person.words!,
  CardStanding.notYet => (person.words?.isEmpty ?? true) ? 'not yet vouched for' : person.words!,
  CardStanding.refused => (person.words?.isEmpty ?? true) ? 'refused' : person.words!,
  CardStanding.revoked => 'revoked',
};

_Tone _toneOf(CardStanding standing) => switch (standing) {
  CardStanding.trusted => _Tone.good,
  CardStanding.notYet => _Tone.waiting,
  CardStanding.refused => _Tone.bad,
  CardStanding.revoked => _Tone.bad,
};

String _projectWords(OrganizationProject project) => [
  if (project.admins.isEmpty)
    'no Project Admin'
  else
    '${project.admins.length == 1 ? 'Project Admin' : 'Project Admins'} ${project.admins.join(', ')}',
  peopleOf(project),
  if (project.host case final host?) 'on $host' else 'on no machine yet',
].join(' · ');

String _standingIn(OrganizationView view, OrganizationProject project) => !view.holdsRoles
    ? 'your card holds no role'
    : project.admins.contains(view.me)
    ? 'you are its admin'
    : project.members.contains(view.me)
    ? 'you are a member'
    : 'you are not a member';

String _hostWords(OrganizationHost host) => [
  if (host.address case final address?) host.port == null ? address : _reach(address, host.port!) else 'no address yet',
  if (host.admins.isEmpty)
    'no Machine Admin'
  else if (host.admins.length == 1)
    'Machine Admin ${host.admins.single}'
  else
    'Machine Admins ${host.admins.join(', ')}',
  if (host.projects.isEmpty) 'carries no project' else 'carries ${host.projects.join(', ')}',
].join(' · ');

String _reach(String address, int port) => address.contains(':') ? '[$address]:$port' : '$address:$port';

String _removingProjectWords(OrganizationProject project) => [
  'Its card and its members leave the organization.',
  if (project.host case final host?) 'It is still on $host, and its Machine Admins take it off.',
  'Its repositories stay where they are.',
].join(' ');

String _removingHostWords(OrganizationHost host) => [
  'Its card leaves the organization.',
  if (host.projects.isNotEmpty) 'It still carries ${host.projects.join(', ')}.',
  'The machine itself keeps running.',
].join(' ');

class _Explanation extends StatelessWidget {
  const _Explanation({required this.view, required this.onHide});

  final OrganizationView? view;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget part(String title, String words) => SizedBox(
      width: Sizes.dialogSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall),
          Text(words),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.normal),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: Space.normal),
            Expanded(
              child: Wrap(
                spacing: Space.normal,
                runSpacing: Space.small,
                children: [
                  part(
                    'What is the Porelo organization?',
                    'Who manages it, its people with their cards, its projects with their members, and its machines. '
                        'Porelo asks it whom to trust before anyone gets onto a machine.',
                  ),
                  part(
                    'Where it is kept',
                    'In a repository inside ${forgeOrganizationWords(view)}: one is not the other. The repository holds '
                        'the Porelo organization, and its name is yours to choose.',
                  ),
                  part(
                    'What you can do here',
                    'Everyone reads all of it. Each action shows only for the role it belongs to.',
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('organization-explanation-hide'),
              tooltip: 'Hide this explanation',
              onPressed: onHide,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCard extends StatelessWidget {
  const _NoCard({required this.view, required this.onAdd});

  final OrganizationView view;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.normal),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.normal,
        runSpacing: Space.small,
        children: [
          const Icon(Icons.person_add_outlined),
          SizedBox(
            width: Sizes.dialogSmall,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are not in ${view.name} yet', style: Theme.of(context).textTheme.titleSmall),
                const Text(
                  'Add your card so that a Project Admin can add you to a project and a machine can admit you.',
                ),
              ],
            ),
          ),
          FilledButton(key: const ValueKey('organization.addCard'), onPressed: onAdd, child: const Text('Add me')),
        ],
      ),
    ),
  );
}

enum _Tone { plain, good, waiting, bad }

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.state,
    this.tone = _Tone.plain,
    this.actions = const [],
    this.below,
  });

  /// What stands under its words, where the next step is said on the row.
  final Widget? below;

  final IconData icon;
  final String title;
  final String subtitle;
  final String? state;
  final _Tone tone;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _Tone.plain => null,
      _Tone.good => colors.primary,
      _Tone.waiting => colors.tertiary,
      _Tone.bad => colors.error,
    };
    final compact = WindowSize.fromContext(context) == WindowSize.compact;
    final small = Theme.of(context).textTheme.bodySmall;
    final said = state != null && state!.isNotEmpty ? state : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sizes.listRowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.small),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: Space.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title),
                  Text(subtitle, style: small),
                  if (compact && said != null) Text(said, style: small?.copyWith(color: color)),
                  if (below case final next?)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.small),
                      child: next,
                    ),
                ],
              ),
            ),
            if (!compact && said != null) ...[
              const SizedBox(width: Space.normal),
              Text(said, style: small?.copyWith(color: color)),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(width: Space.small),
              CommandMenu(
                commands: [for (final action in actions) action.command],
                tooltip: 'What can be done with $title',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What a computer naming no organization offers: to name one, to make one, and the card making one needs.
class _NoOrganization extends StatelessWidget {
  const _NoOrganization({required this.onChoose, required this.onCreate, required this.onCard});

  final VoidCallback onChoose;
  final VoidCallback onCreate;
  final VoidCallback onCard;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This computer reads no Porelo organization yet', style: Theme.of(context).textTheme.titleSmall),
          const Text(
            'Name the one you belong to by its repository. To start a new one you need a card on this computer first.',
          ),
          const SizedBox(height: Space.small),
          Wrap(
            spacing: Space.small,
            runSpacing: Space.small,
            children: [
              FilledButton(
                key: const ValueKey('chooseOrganization'),
                onPressed: onChoose,
                child: const Text('Choose the Porelo organization…'),
              ),
              OutlinedButton(
                key: const ValueKey('createOrganization'),
                onPressed: onCreate,
                child: const Text('Create the Porelo organization…'),
              ),
              OutlinedButton(key: const ValueKey('makeCard'), onPressed: onCard, child: const Text('Make my card…')),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Asks for an organization's address: to read it here, or to fill the empty repository at it as a new one.
class _AddressDialog extends StatefulWidget {
  const _AddressDialog(this.organization, {this.creating = false, this.replacing = false});

  final Organization organization;
  final bool creating;
  final bool replacing;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _address = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrganizationChangeDialog(
    organization: widget.organization,
    title: widget.creating
        ? (widget.replacing ? 'Create another Porelo organization' : 'Create the Porelo organization')
        : widget.replacing
        ? 'Choose another Porelo organization'
        : 'Choose the Porelo organization',
    confirm: widget.creating ? 'Create it' : 'Choose it',
    body: (context, changed) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.creating && widget.replacing)
          const Text(
            'Make an empty repository on your forge first: Porelo does not make it. This computer reads one Porelo organization, '
            'so it will read the new one instead of this one. This one stays on its forge, and you can choose it again.',
          )
        else if (widget.creating)
          const Text(
            'Make an empty repository on your forge first: Porelo does not make it. Give its address here, and your '
            'card goes in as its first, and only, owner.',
          )
        else if (widget.replacing)
          const Text(
            'This computer reads one Porelo organization, so it will read that one instead of this one. An empty repository '
            'cannot be chosen here: it is filled by *Create another Porelo organization…*.',
          )
        else
          const Text(
            'An empty repository is not chosen but filled: cancel this and use *Create the Porelo organization…*.',
          ),
        const SizedBox(height: Space.small),
        Text(
          "A Porelo organization lives in a repository inside ${forgeOrganizationWords(null)}, outside every machine: a machine follows it, and cannot hold it.",
        ),
        const SizedBox(height: Space.small),
        TextField(
          key: const Key('organization-address'),
          controller: _address,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "The Porelo organization's repository address",
            errorText: _holdsCredential(_address.text.trim())
                ? 'The address only: no password or token, so it stays out of what other programs can read.'
                : null,
          ),
          onChanged: (_) => changed(),
        ),
      ],
    ),
    ask: () => _address.text.trim().isEmpty || _holdsCredential(_address.text.trim())
        ? null
        : (
            change: widget.creating ? OrganizationChange.createOrganization : OrganizationChange.chooseOrganization,
            input: {'address': _address.text.trim(), if (widget.replacing) 'replace': 'yes'},
          ),
  );
}

/// The fingerprint of the key a card names, as the person's own view shows it; null where it names none.
@visibleForTesting
String? fingerprintOfCard(String card) {
  final key = RegExp(r'^key: "ssh-ed25519 ([A-Za-z0-9+/=]+)', multiLine: true).firstMatch(card)?.group(1);
  if (key == null) return null;
  final hash = base64Encode(sha256.convert(base64Decode(key)).bytes);
  return 'SHA256:${hash.replaceAll('=', '')}';
}

/// Puts the new card a person handed over in place of their lost key's. It shows what the card says first, since
/// accepting lets whoever holds that key in wherever the person was.
class _AcceptCardDialog extends StatefulWidget {
  const _AcceptCardDialog(this.organization, {required this.login, required this.pickFile});

  final Organization organization;
  final String login;
  final PickAFile pickFile;

  @override
  State<_AcceptCardDialog> createState() => _AcceptCardDialogState();
}

class _AcceptCardDialogState extends State<_AcceptCardDialog> {
  String? _file;
  String? _fingerprint;
  String? _unread;

  Future<void> _choose(VoidCallback changed) async {
    final file = await widget.pickFile(title: "Choose ${widget.login}'s new card");
    if (file == null) return;
    String? fingerprint;
    String? unread;
    try {
      fingerprint = fingerprintOfCard(await File(file).readAsString());
      if (fingerprint == null) unread = 'This is no card: it names no key.';
    } on FileSystemException catch (error) {
      unread = 'It could not be read: ${error.osError?.message ?? error.message}.';
    } on FormatException {
      unread = 'This is no card: it names no key.';
    }
    if (!mounted) return;
    _file = file;
    _fingerprint = fingerprint;
    _unread = unread;
    changed();
  }

  @override
  Widget build(BuildContext context) => OrganizationChangeDialog(
    organization: widget.organization,
    title: "Accept ${widget.login}'s new card?",
    confirm: 'Accept the card',
    body: (context, changed) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: [
        Text(
          'For a person who lost their key. Ask ${widget.login}, by a way you trust, whether this key is theirs: '
          'whoever holds it comes in wherever they were.',
        ),
        OutlinedButton(
          key: const Key('organization-card-file'),
          onPressed: () => unawaited(_choose(changed)),
          child: Text(_file ?? 'Choose the card file…'),
        ),
        if (_unread case final unread?) Text(unread, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_fingerprint case final fingerprint?)
          SelectableText('Its key: $fingerprint', key: const Key('organization-card-key')),
      ],
    ),
    ask: () => _fingerprint == null
        ? null
        : (change: OrganizationChange.replaceCard, input: {'login': widget.login, 'card': _file!}),
  );
}

/// Files the person's own card, or changes its key, from the keys this computer offers.
class _KeyDialog extends StatefulWidget {
  const _KeyDialog(this.organization, {required this.adding});

  final Organization organization;
  final bool adding;

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  String _me(OrganizationView? view) =>
      widget.adding || view == null ? (_login.text.trim().isEmpty ? 'you' : _login.text.trim()) : view.me;

  late final Future<List<OrganizationKey>> _keys = widget.organization.source.myKeys();
  String? _chosen;
  final _login = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _login.text = widget.organization.view?.me ?? '';
  }

  @override
  void dispose() {
    _login.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No organization read yet: a card can still be made here, which creating one needs.
    final view = widget.organization.view;
    final vouchedBy = view?.vouchedBy ?? 'Your forge';
    return FutureBuilder<List<OrganizationKey>>(
      future: _keys,
      builder: (context, snapshot) {
        // Changing the key offers no key the card already has: Core refuses that as no change.
        final keys = [
          for (final key in snapshot.data ?? const <OrganizationKey>[])
            if (widget.adding || key.fingerprint != view?.myCard?.key) key,
        ];
        // Asked each time: choosing rebuilds only the dialog around this, so a value kept here would stay the first.
        OrganizationKey? chosenKey() => keys.where((key) => key.fingerprint == _chosen).firstOrNull ?? keys.firstOrNull;
        return OrganizationChangeDialog(
          organization: widget.organization,
          title: !widget.adding
              ? 'Change my key'
              : view == null
              ? 'Make my card'
              : 'Add me to ${view.name}',
          confirm: !widget.adding
              ? 'Change my key'
              : view == null
              ? 'Make my card'
              : 'Add my card',
          body: (context, changed) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.adding) ...[
                TextField(
                  key: const Key('organization-card-login'),
                  controller: _login,
                  decoration: InputDecoration(
                    labelText: view == null ? 'Your login at your forge' : 'Your login at $vouchedBy',
                  ),
                  onChanged: (_) => changed(),
                ),
                TextField(
                  key: const Key('organization-card-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  onChanged: (_) => changed(),
                ),
                TextField(
                  key: const Key('organization-card-email'),
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Your email, if you want it on your card'),
                  onChanged: (_) => changed(),
                ),
              ] else
                Text('Login: ${view?.me ?? ''}'),
              const SizedBox(height: Space.small),
              if (snapshot.hasError)
                Text('${snapshot.error}')
              else if (snapshot.connectionState != ConnectionState.done)
                const Text('Asking for your keys…')
              else if (keys.isEmpty)
                Text(
                  widget.adding
                      ? 'No key is in your ssh agent. Add one to it, then open this again.'
                      : 'Your ssh agent holds no other key. Add the new one to it, then open this again.',
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: const Key('organization-key'),
                  isExpanded: true,
                  initialValue: chosenKey()?.fingerprint,
                  decoration: const InputDecoration(labelText: 'Your key'),
                  items: [
                    for (final key in keys)
                      DropdownMenuItem(
                        value: key.fingerprint,
                        child: Text(
                          key.label.isEmpty ? key.fingerprint : '${key.fingerprint} (${key.label})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (fingerprint) {
                    _chosen = fingerprint;
                    changed();
                  },
                ),
                const SizedBox(height: Space.small),
                Text(switch (chosenKey()?.vouched) {
                  true => '$vouchedBy lists this key for ${_me(view)}',
                  false => '$vouchedBy does not list this key for ${_me(view)}: add it there first.',
                  null => '$vouchedBy could not say whether this key is yours; the organization asks when it is filed.',
                }),
              ],
            ],
          ),
          ask: () {
            final key = chosenKey();
            if (key == null ||
                key.vouched == false ||
                (widget.adding && (_login.text.trim().isEmpty || _name.text.trim().isEmpty))) {
              return null;
            }
            return (
              change: widget.adding ? OrganizationChange.addCard : OrganizationChange.changeCard,
              input: {
                'key': key.fingerprint,
                if (widget.adding) ...{
                  'login': _login.text.trim(),
                  'name': _name.text.trim(),
                  if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
                },
              },
            );
          },
        );
      },
    );
  }
}

/// Whether [address] carries more before its host than the `git@` an ssh address has.
bool _holdsCredential(String address) {
  final carried = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://([^/@]*)@').firstMatch(address)?.group(1);
  return carried != null && carried != 'git';
}
