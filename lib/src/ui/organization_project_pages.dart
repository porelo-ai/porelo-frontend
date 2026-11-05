import 'dart:async';

import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/host_progress.dart';
import '../app/organization_source.dart';
import '../app/repository_address.dart';
import '../app/run_here.dart' show WorkspaceRefused;
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'organization_dialogs.dart';
import 'tokens.dart';

/// What is true of a repository's name, as for any folder it becomes.
final _repositoryName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

/// The role a person has in [project], or null where they have none.
String? _roleIn(OrganizationView view, OrganizationProject project) => !view.holdsRoles
    ? null
    : project.admins.contains(view.me)
    ? 'Project Admin'
    : project.members.contains(view.me)
    ? 'developer'
    : null;

/// The projects a person is a project admin or a member of, each with the one host carrying it.
class OrganizationProjectsPage extends StatefulWidget {
  /// Lists [organization]'s projects for the person reading.
  const OrganizationProjectsPage({
    required this.organization,
    required this.onProject,
    this.onHost,
    this.menuFor,
    this.connections,
    this.onOthers,
    super.key,
  });

  /// Opens the projects of a machine this computer watches, which no organization holds: `default` and local ones.
  final VoidCallback? onOthers;

  /// The organization.
  final Organization organization;

  /// Opens a project's page.
  final void Function(String project) onProject;

  /// Opens the project on its host, where work, agents, messages and saved jobs start.
  final void Function(String project, String host)? onHost;

  /// What can be done with a project on its host from here: a host lists a project only after the person's first start
  /// there, so no machine's list holds these until then.
  final List<Command> Function(String project, String host)? menuFor;

  /// Asks a connected machine how a project stands with the central forge, absent where this computer cannot.
  final HostConnections? connections;

  @override
  State<OrganizationProjectsPage> createState() => _OrganizationProjectsPageState();
}

class _OrganizationProjectsPageState extends State<OrganizationProjectsPage> {
  /// What `project list` answered; a refusal is said by the organization's own read, so this stays as it was.
  List<ListedProject> _listed = const [];
  final _central = <String, CentralState>{};
  final _connecting = <String>{};
  final _refusals = <String, String>{};

  Future<void> _connect(String host) async {
    if (!_connecting.add(host)) return;
    setState(() => _refusals.remove(host));
    String? refusal;
    try {
      await widget.connections!.connect(host);
    } on OrganizationRefused catch (refused) {
      refusal = refused.words;
    }
    if (!mounted) return;
    setState(() {
      _connecting.remove(host);
      if (refusal case final words?) _refusals[host] = words;
    });
  }

  /// Asks once per project and connection, as the machine's own answer only changes at its follow.
  void _askCentral(OrganizationProject project) {
    final connections = widget.connections;
    final host = project.host;
    if (connections == null || host == null || !connections.connected(host)) return;
    if (_central.containsKey(project.name)) return;
    _central[project.name] = const CentralState();
    unawaited(
      connections.central(host, project.name).then((state) {
        if (mounted) setState(() => _central[project.name] = state);
      }),
    );
  }

  String? _centralWords(OrganizationView view, CentralState? state) {
    if (state == null) return null;
    final age = state.readAt == null ? null : DateTime.now().toUtc().difference(state.readAt!.toUtc()).inMinutes;
    return [
      state.words(view.forge ?? 'the central forge'),
      if (age != null && age >= 0)
        'read ${age == 0
            ? 'just now'
            : age == 1
            ? 'a minute ago'
            : '$age minutes ago'}',
    ].join(', ');
  }

  bool _isLocked(OrganizationProject project) => _listed.any((listed) => listed.name == project.name && listed.locked);

  @override
  void initState() {
    super.initState();
    unawaited(widget.organization.refresh());
    unawaited(_list());
  }

  Future<void> _list() async {
    try {
      final listed = await widget.organization.source.myProjects();
      if (mounted) setState(() => _listed = listed);
    } on OrganizationRefused {
      // Said by the organization's own read, whose words are the same.
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.organization, ?widget.connections]),
    builder: (context, _) {
      final view = widget.organization.view;
      final mine = view == null
          ? const <OrganizationProject>[]
          : [
              for (final project in view.projects)
                if (view.isMine(project)) project,
            ];
      for (final project in mine) {
        _askCentral(project);
      }
      return ListView(
        key: const Key('organization-projects-page'),
        padding: const EdgeInsets.all(Space.normal),
        children: [
          OrganizationChangeMark(widget.organization),
          if (widget.organization.problem case final problem?) _Problem(problem),
          if (view != null)
            FilteredListSection(
              title: 'My projects',
              storageId: 'my-projects',
              rows: [
                for (final project in mine)
                  (
                    words: project.name,
                    child: ListTile(
                      key: ValueKey('my-project ${project.name}'),
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(project.name),
                      subtitle: Text(
                        '${project.repositories == null ? '' : '${_count(project.repositories!, 'repository', 'repositories')} · '}'
                        '${peopleOf(project)} · '
                        '${project.host == null ? 'not on a machine yet · a Machine Admin puts it on one' : 'on ${project.host}'}'
                        '${_centralWords(view, _central[project.name]) == null ? '' : ' · ${_centralWords(view, _central[project.name])}'}'
                        '${_refusals[project.host] == null ? '' : ' · ${_refusals[project.host]}'}',
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Space.normal,
                        children: [
                          Chip(label: Text(_isLocked(project) ? 'locked' : _roleIn(view, project)!)),
                          if (_central[project.name]?.offersPush ?? false)
                            if (project.host case final host? when !_isLocked(project))
                              for (final command in widget.menuFor?.call(project.name, host) ?? const <Command>[])
                                if (command.id == 'project.pushApprovedMain')
                                  Tooltip(
                                    message: command.unavailable ?? command.label,
                                    child: OutlinedButton(
                                      key: ValueKey('organization.pushApprovedMain ${project.name}'),
                                      onPressed: command.available ? command.run : null,
                                      child: Text(command.label),
                                    ),
                                  ),
                          if (project.host case final host? when !_isLocked(project))
                            if (view.holdsRoles && !(widget.connections?.connected(host) ?? false))
                              Tooltip(
                                message: widget.connections == null
                                    ? 'This computer has no way to connect yet.'
                                    : _connecting.contains(host)
                                    ? 'Connecting to $host…'
                                    : 'Connect to $host',
                                child: FilledButton(
                                  key: ValueKey('organization.connectToHost ${project.name}'),
                                  onPressed: widget.connections == null || _connecting.contains(host)
                                      ? null
                                      : () => unawaited(_connect(host)),
                                  child: Text('Connect to $host'),
                                ),
                              ),
                          if (project.host case final host? when !_isLocked(project))
                            CommandMenu(
                              key: ValueKey('organization.projectMenu ${project.name}'),
                              commands: [
                                if (widget.onHost != null && view.holdsRoles && (widget.connections?.up(host) ?? false))
                                  organizationCommand(
                                    id: 'openOnHost ${project.name}',
                                    label: 'Work on it',
                                    run: () => widget.onHost!(project.name, host),
                                  ),
                                ...?widget.menuFor?.call(project.name, host),
                              ],
                              tooltip: 'What can be done with ${project.name}',
                            ),
                        ],
                      ),
                      onTap: () => widget.onProject(project.name),
                    ),
                  ),
                for (final listed in _listed)
                  if (listed.source == 'local')
                    (
                      words: listed.name,
                      child: ListTile(
                        key: ValueKey('my-project ${listed.name}'),
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(listed.name),
                        subtitle: const Text('only on this computer'),
                        onTap: widget.onOthers,
                      ),
                    ),
              ],
            ),
          if (view != null && mine.isEmpty)
            const Text(
              'You are in no project yet. Nobody joins on their own: a Project Admin adds you. Every project of the '
              'Porelo organization is listed under Organization.',
            ),
          if (widget.onOthers case final others?)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('projects-of-machines'),
                onPressed: others,
                child: const Text('All projects on your machines'),
              ),
            ),
        ],
      );
    },
  );
}

String _count(int count, String one, String many) => '$count ${count == 1 ? one : many}';

class _Problem extends StatelessWidget {
  const _Problem(this.words);

  final String words;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.small),
    child: Text(words, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );
}

/// One project: its repositories and its members with their role. Its project admins change them here; a member reads
/// the same page and changes nothing. Work on it starts from its row under My projects, which names its host.
class OrganizationProjectPage extends StatefulWidget {
  /// Reads [project] from [organization].
  const OrganizationProjectPage({required this.organization, required this.project, required this.onBack, super.key});

  /// The organization.
  final Organization organization;

  /// The project's name.
  final String project;

  /// Returns to the list.
  final VoidCallback onBack;

  @override
  State<OrganizationProjectPage> createState() => _OrganizationProjectPageState();
}

class _OrganizationProjectPageState extends State<OrganizationProjectPage> {
  ProjectView? _view;
  String? _problem;
  bool _reading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
    widget.organization.addListener(_organizationChanged);
    widget.organization.addWriteRead(_read);
    if (widget.organization.view == null) unawaited(widget.organization.refresh());
  }

  @override
  void dispose() {
    widget.organization.removeListener(_organizationChanged);
    widget.organization.removeWriteRead(_read);
    super.dispose();
  }

  int _reads = 0;
  void _organizationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _read() async {
    if (!mounted) return;
    final read = ++_reads;
    setState(() => _reading = true);
    try {
      final view = await widget.organization.source.readProject(widget.project);
      // A read that answers after a later one was asked for may be the older.
      if (!mounted || read != _reads) return;
      widget.organization.rememberProjectRevision(view);
      setState(() {
        _view = view;
        _problem = null;
      });
    } on OrganizationRefused catch (refused) {
      if (mounted && read == _reads) setState(() => _problem = refused.words);
    } on Exception {
      if (mounted && read == _reads) setState(() => _problem = 'The project could not be read.');
    } finally {
      if (mounted && read == _reads) setState(() => _reading = false);
    }
  }

  void _show(Widget dialog) => unawaited(
    showDialog<void>(
      context: context,
      builder: (_) => widget.organization.busy
          ? const AlertDialog(content: Text('Another change is still being asked for.'))
          : dialog,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final organization = widget.organization.view;
    final isAdmin =
        view != null &&
        organization != null &&
        organization.holdsRoles &&
        view.members.any(
          (member) =>
              member.login == organization.me &&
              member.role == ProjectView.adminRole &&
              (member.standing == CardStanding.trusted || member.standing == CardStanding.notYet) &&
              !member.locked,
        );
    // Before it is opened there is no project.yml to change: opening it is all there is to do.
    final changes = isAdmin && view.opened;
    return ListView(
      key: ValueKey('organization-project ${widget.project}'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('organization-project-back'),
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('My projects'),
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.small,
          children: [
            Text(widget.project, style: Theme.of(context).textTheme.headlineSmall),
            if (view != null && organization != null) Chip(label: Text(_myRole(view, organization))),
            if (changes)
              CommandMenu(
                tooltip: 'What can be done with ${view.name}',
                commands: [
                  for (final policy in ['required', 'optional'])
                    if (view.review != policy) _reviewCommand(view, policy),
                ],
              ),
          ],
        ),
        if (_problem case final problem?) _Problem(problem),
        if (_reading) Text('Reading ${widget.project}: its address, repositories, and members…'),
        OrganizationChangeMark(widget.organization),
        for (final change in widget.organization.rowChanges)
          if (change.input['project'] == widget.project &&
              (view == null || change.change == OrganizationChange.createProjectRepository))
            OrganizationPendingRow(widget.organization, change, onReview: () => unawaited(_read())),
        if (view != null && !view.opened) _notOpened(view),
        if (view != null && view.opened) ...[
          Text(_reviewWords(view.review)),
          if (!isAdmin) Text('${_adminsWords(view)} Only they change this project.'),
          const SizedBox(height: Space.normal),
          _address(view, changes),
          if (view.repositoriesProblem case final problem?) _Problem(problem),
          _repositories(view, changes),
          _members(view, organization, changes),
          if (isAdmin) const Text('A change is signed with your key.'),
        ],
      ],
    );
  }

  String _reviewWords(String? review) => switch (review) {
    'required' => 'Review is required.',
    'optional' => 'Review is optional.',
    null => 'Porelo does not name the current review policy, so this page cannot say whether review is required.',
    final word => 'Porelo calls the review policy “$word”; this page cannot say whether review is required.',
  };

  String _adminsWords(ProjectView view) => view.admins.isEmpty
      ? 'It has no Project Admin.'
      : '${view.admins.length == 1 ? 'Project Admin' : 'Project Admins'} ${view.admins.join(', ')}.';

  Command _reviewCommand(ProjectView view, String policy, {String? repository}) {
    final target = repository == null ? view.name : '$repository in ${view.name}';
    return organizationCommand(
      id: repository == null ? 'projectReview/$policy' : 'repositoryReview/$repository/$policy',
      label: policy == 'required' ? 'Require review…' : 'Make review optional…',
      unavailable: widget.organization.busy
          ? 'Another change is still being asked for.'
          : view.repositoriesRevision == null || view.repositoriesRevision!.isEmpty
          ? 'The project repository revision is unknown. Read the project again before signing.'
          : null,
      run: () => _show(
        OrganizationConfirmDialog(
          widget.organization,
          base: view.repositoriesRevision,
          title: policy == 'required' ? 'Require review in $target?' : 'Make review optional in $target?',
          words: policy == 'required'
              ? 'Work must be reviewed before it leaves the gate. This change is signed with your key.'
              : 'Work may leave the gate without a review. This change is signed with your key.',
          confirm: policy == 'required' ? 'Require review' : 'Make review optional',
          change: OrganizationChange.changeProjectReview,
          input: {'project': view.name, 'repository': ?repository, 'review': policy},
        ),
      ),
    );
  }

  Widget _address(ProjectView view, bool isAdmin) => Padding(
    padding: const EdgeInsets.only(bottom: Space.normal),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.normal,
      runSpacing: Space.small,
      children: [
        Text('Project repository: ${view.address ?? 'none named yet'}'),
        if (isAdmin)
          CommandMenu(
            tooltip: 'What can be done with the project address',
            commands: [
              organizationCommand(
                id: 'changeAddress',
                label: 'Change the address…',
                unavailable: widget.organization.busy ? 'Another change is still being asked for.' : null,
                run: () => _show(_AddressDialog(widget.organization, view)),
              ),
            ],
          ),
      ],
    ),
  );

  /// A page reached with an old link or a stale list: its repository is made on the Organization page.
  Widget _notOpened(ProjectView view) => Padding(
    padding: const EdgeInsets.only(bottom: Space.normal),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.normal,
      runSpacing: Space.small,
      children: [
        Text(
          '${view.name} has no Git repository yet. '
          'It waits for ${view.admins.isEmpty ? 'its Project Admin' : view.admins.join(' or ')}, on the Organization page.',
        ),
        OutlinedButton(
          key: const ValueKey('organization.backFromProject'),
          onPressed: widget.onBack,
          child: const Text('Go back'),
        ),
      ],
    ),
  );

  String _myRole(ProjectView view, OrganizationView organization) {
    final me = view.members.where((member) => member.login == organization.me).firstOrNull;
    if (me == null) return 'not a member';
    if (!organization.holdsRoles || me.standing == CardStanding.revoked || me.standing == CardStanding.refused) {
      return 'no role';
    }
    if (me.locked) return 'locked';
    return me.role == ProjectView.adminRole ? 'Project Admin' : me.role;
  }

  Widget _repositories(ProjectView view, bool isAdmin) =>
      FilteredListSection(
        title: 'Repositories',
        storageId: 'project-repositories ${view.name}',
        emptyWords: isAdmin ? 'No repositories yet. Add one with Add.' : 'No repositories yet.',
        actions: [
          if (isAdmin)
            OutlinedButton.icon(
              key: const ValueKey('organization.addRepository'),
              onPressed: () => _show(_AddRepositoryDialog(widget.organization, view)),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
        ],
        rows: [
          for (final repository in view.repositories)
            (
              words: '${repository.name} ${repository.address ?? ''}',
              child: ListTile(
                leading: const Icon(Icons.book_outlined),
                title: Text(repository.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${repository.address ?? 'no upstream named'} · ${_reviewWords(repository.review)}'),
                    if (repository.namesNoCentral)
                      Text(
                        'It names no central address, so a machine takes nothing from it. '
                        '${(repository.address ?? '').isEmpty
                            ? 'It names no address to take either, so it has to be removed and added again.'
                            : isAdmin
                            ? 'Name one from its menu.'
                            : 'Its Project Admin can name one.'}',
                      ),
                  ],
                ),
                trailing: isAdmin
                    ? CommandMenu(
                        commands: [
                          for (final policy in ['required', 'optional'])
                            _reviewCommand(view, policy, repository: repository.name),
                          if (repository.namesNoCentral && (repository.address ?? '').isNotEmpty)
                            organizationCommand(
                              id: 'nameCentral/${repository.name}',
                              label: 'Name its central address…',
                              run: () => _show(
                                OrganizationConfirmDialog(
                                  widget.organization,
                                  base: view.repositoriesRevision ?? view.revision,
                                  title: 'Name where a machine takes ${repository.name} from?',
                                  words:
                                      'A machine takes it from ${repository.address}, its own address. '
                                      'This change is signed with your key.',
                                  confirm: 'Name it',
                                  change: OrganizationChange.nameRepositoryCentral,
                                  input: {
                                    'project': view.name,
                                    'repository': repository.name,
                                    'central': repository.address!,
                                  },
                                ),
                              ),
                            ),
                          organizationCommand(
                            id: 'removeRepository/${repository.name}',
                            label: 'Remove…',
                            danger: true,
                            run: () => _show(
                              OrganizationConfirmDialog(
                                widget.organization,
                                base: view.repositoriesRevision ?? view.revision,
                                title: 'Remove ${repository.name} from ${view.name}?',
                                words: 'It is no longer part of the project. The repository itself stays where it is.',
                                confirm: 'Remove',
                                change: OrganizationChange.removeProjectRepository,
                                input: {'project': view.name, 'repository': repository.name},
                              ),
                            ),
                          ),
                        ],
                        tooltip: 'What can be done with ${repository.name}',
                      )
                    : null,
              ),
            ),
        ],
      ).withOrganizationChanges(
        widget.organization,
        names: [for (final repository in view.repositories) repository.name],
        reviewProject: (_) => unawaited(_read()),
      );

  Widget _members(ProjectView view, OrganizationView? organization, bool isAdmin) {
    final have = {for (final member in view.members) member.login};
    final candidates = [
      if (organization != null)
        for (final person in organization.holdingRoles)
          if (!have.contains(person.login)) person.login,
    ];
    return FilteredListSection(
      title: 'Members',
      storageId: 'project-members ${view.name}',
      actions: [
        if (isAdmin)
          OutlinedButton.icon(
            key: const ValueKey('organization.addMember'),
            onPressed: candidates.isEmpty || view.roles.isEmpty
                ? null
                : () => _show(
                    OrganizationPersonDialog(
                      widget.organization,
                      base: view.revision,
                      people: candidates,
                      title: 'Add a member to ${view.name}',
                      personLabel: 'Person',
                      words:
                          'They are admitted on its machine, as ${view.roles.firstOrNull ?? 'a member'}; '
                          'the role can be changed in their row.',
                      confirm: 'Add',
                      change: OrganizationChange.addProjectMember,
                      input: (_, person) => {
                        'project': view.name,
                        'login': person,
                        'role': view.roles.firstOrNull ?? '',
                      },
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
      ],
      rows: [
        for (final member in view.members)
          (
            words: '${member.login} ${member.role}',
            child: _MemberRow(
              key: ValueKey(member.login),
              member: member,
              me: organization?.me,
              // Removing or demoting the last project admin is the store's to refuse.
              // A developer is their Project Admin's; an admin, or a role to or from it, the Organization Admin's.
              changes: organization?.mayChangeMember(member.role, isProjectAdmin: isAdmin) ?? isAdmin,
              roles: [
                for (final role in view.roles)
                  if (organization?.mayChangeMember(role, isProjectAdmin: isAdmin) ?? isAdmin) role,
              ],
              organization: widget.organization,
              view: view,
              onRemove: () => _show(
                OrganizationConfirmDialog(
                  widget.organization,
                  base: view.revision,
                  title: 'Remove ${member.login} from ${view.name}?',
                  words:
                      '${member.login} is out of this project, and its machine locks them when it takes the change: '
                      'within five minutes, or at once on its Refresh.',
                  confirm: 'Remove',
                  change: OrganizationChange.removeProjectMember,
                  input: {'project': view.name, 'login': member.login},
                ),
              ),
            ),
          ),
      ],
    ).withOrganizationChanges(
      widget.organization,
      names: [for (final member in view.members) member.login],
      reviewProject: (_) => unawaited(_read()),
    );
  }
}

class _MemberRow extends StatefulWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.me,
    required this.changes,
    required this.roles,
    required this.organization,
    required this.view,
    required this.onRemove,
  });

  final ProjectMember member;
  final String? me;
  final bool changes;
  final List<String> roles;
  final Organization organization;
  final ProjectView view;
  final VoidCallback onRemove;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  String? _refusal;

  Future<void> _lock(bool lock) async {
    final refusal = await widget.organization.write(
      lock ? OrganizationChange.lockProjectMember : OrganizationChange.unlockProjectMember,
      {'project': widget.view.name, 'login': widget.member.login},
      base: widget.view.revision,
    );
    if (mounted) setState(() => _refusal = refusal);
  }

  void _changeRole() {
    var role = widget.member.role;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => OrganizationChangeDialog(
          organization: widget.organization,
          title: 'Change the role of ${widget.member.login}',
          confirm: 'Change the role',
          base: widget.view.revision,
          body: (_, changed) => DropdownButtonFormField<String>(
            key: const Key('organization-member-role'),
            initialValue: role,
            items: [for (final choice in widget.roles) DropdownMenuItem(value: choice, child: Text(choice))],
            onChanged: (choice) {
              if (choice != null) role = choice;
              changed();
            },
          ),
          ask: () => role == widget.member.role
              ? null
              : (
                  change: OrganizationChange.changeProjectMemberRole,
                  input: {'project': widget.view.name, 'login': widget.member.login, 'role': role},
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final colors = Theme.of(context).colorScheme;
    final standing = switch (member.standing) {
      CardStanding.trusted => ('trusted', colors.primary),
      CardStanding.notYet => ('not yet', colors.tertiary),
      CardStanding.refused => ('refused', colors.error),
      CardStanding.revoked => ('revoked', colors.error),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.normal,
            runSpacing: Space.small,
            children: [
              const Icon(Icons.person_outline),
              Text(member.login == widget.me ? '${member.login} (you)' : member.login),
              Text(member.role),
              Text(standing.$1, style: TextStyle(color: standing.$2)),
              if (member.locked) Text('locked', style: TextStyle(color: colors.error)),
              if (widget.changes)
                CommandMenu(
                  commands: [
                    organizationCommand(
                      id: 'lockMember/${member.login}',
                      label: member.locked ? 'Unlock' : 'Lock',
                      run: () => unawaited(_lock(!member.locked)),
                      unavailable: widget.organization.busy ? 'A change is being written.' : null,
                    ),
                    organizationCommand(
                      id: 'removeMember/${member.login}',
                      label: 'Remove…',
                      danger: true,
                      run: widget.onRemove,
                    ),
                    if (widget.roles.contains(member.role))
                      organizationCommand(
                        id: 'memberRole/${member.login}',
                        label: 'Change the role…',
                        run: _changeRole,
                        unavailable: widget.organization.busy ? 'Another change is still being asked for.' : null,
                      ),
                  ],
                  tooltip: 'What can be done with ${member.login}',
                ),
            ],
          ),
          if (_refusal case final refusal?) Text(refusal, style: TextStyle(color: colors.error)),
        ],
      ),
    );
  }
}

/// Refuses what is no plain repository address, without repeating what was given: it may hold a token.
String? _addressRefused(String address) {
  try {
    checkRepositoryAddress(address);
    return null;
  } on WorkspaceRefused {
    return 'The address must be a git@ or https address without a user name, password or token.';
  }
}

const _addressHelp = 'On the forge, under Code: the SSH one (git@…) or the HTTPS one. The address only, no token.';

class _AddressDialog extends StatefulWidget {
  const _AddressDialog(this.organization, this.view);

  final Organization organization;
  final ProjectView view;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final _address = TextEditingController(text: widget.view.address);

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrganizationChangeDialog(
    organization: widget.organization,
    base: widget.view.revision,
    title: 'The project repository of ${widget.view.name}',
    confirm: 'Change the address',
    body: (context, changed) => TextField(
      key: const Key('organization-project-address'),
      controller: _address,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Address', helperText: _addressHelp, helperMaxLines: 2),
      onChanged: (_) => changed(),
    ),
    invalid: () => _addressRefused(_address.text.trim()),
    ask: () => _address.text.trim().isEmpty
        ? null
        : (
            change: OrganizationChange.changeProjectRepository,
            input: {'project': widget.view.name, 'address': _address.text.trim()},
          ),
  );
}

class _AddRepositoryDialog extends StatefulWidget {
  const _AddRepositoryDialog(this.organization, this.view);

  final Organization organization;
  final ProjectView view;

  @override
  State<_AddRepositoryDialog> createState() => _AddRepositoryDialogState();
}

class _AddRepositoryDialogState extends State<_AddRepositoryDialog> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  late bool _requireReview = widget.organization.reviewForNewRepositories(widget.view) != 'optional';

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrganizationChangeDialog(
    organization: widget.organization,
    base: widget.view.repositoriesRevision ?? widget.view.revision,
    title: 'Add a repository to ${widget.view.name}',
    confirm: 'Add',
    body: (context, changed) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('organization-repository-name'),
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name', helperText: 'What it is called in this project.'),
          onChanged: (_) => changed(),
        ),
        const SizedBox(height: Space.small),
        TextField(
          key: const Key('organization-repository-address'),
          controller: _address,
          decoration: const InputDecoration(labelText: 'Address', helperText: _addressHelp, helperMaxLines: 2),
          onChanged: (_) => changed(),
        ),
        SwitchListTile(
          key: const Key('organization-repository-review'),
          title: const Text('Require review'),
          subtitle: Text(
            _requireReview
                ? 'Work must be reviewed before it leaves the gate.'
                : 'Work may leave the gate without a review.',
          ),
          value: _requireReview,
          onChanged: (value) {
            _requireReview = value;
            changed();
          },
        ),
      ],
    ),
    invalid: () {
      if (!_repositoryName.hasMatch(_name.text.trim())) {
        return 'A repository name holds letters, digits, ".", "_" and "-", and opens with a letter or digit.';
      }
      if (_name.text.trim() == widget.view.name) {
        return 'A project cannot hold a repository of its own name. Give this one another name.';
      }
      return _addressRefused(_address.text.trim());
    },
    ask: () => _name.text.trim().isEmpty || _address.text.trim().isEmpty
        ? null
        : (
            change: OrganizationChange.addProjectRepository,
            input: {
              'project': widget.view.name,
              'repository': _name.text.trim(),
              // On a machine a task reads the machine's own forge; the address given is where the machine takes it from.
              ...switch (widget.organization.view?.localAddress(widget.view.name, _address.text.trim())) {
                final local? => {'address': local, 'central': _address.text.trim()},
                // With no machine yet what was typed is both, so the row needs no refiling when one comes.
                null => {'address': _address.text.trim(), 'central': _address.text.trim()},
              },
              'review': _requireReview ? 'required' : 'optional',
            },
          ),
  );
}
