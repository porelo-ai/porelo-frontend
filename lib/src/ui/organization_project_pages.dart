import 'dart:async';

import 'package:flutter/material.dart';

import '../app/commands.dart';
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
    ? 'project admin'
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

  @override
  State<OrganizationProjectsPage> createState() => _OrganizationProjectsPageState();
}

class _OrganizationProjectsPageState extends State<OrganizationProjectsPage> {
  /// What `project list` answered; a refusal is said by the organization's own read, so this stays as it was.
  List<ListedProject> _listed = const [];

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
    listenable: widget.organization,
    builder: (context, _) {
      final view = widget.organization.view;
      final mine = view == null
          ? const <OrganizationProject>[]
          : [
              for (final project in view.projects)
                if (_roleIn(view, project) != null) project,
            ];
      return ListView(
        key: const Key('organization-projects-page'),
        padding: const EdgeInsets.all(Space.normal),
        children: [
          OrganizationChangeMark(widget.organization),
          if (widget.organization.problem case final problem?) _Problem(problem),
          if (view != null)
            FilteredListSection(
              title: 'Projects',
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
                        '${project.host == null ? 'on no host yet' : 'on ${project.host}'}',
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Space.normal,
                        children: [
                          if (project.host case final host?
                              when widget.onHost != null && view.holdsRoles && !_isLocked(project))
                            OutlinedButton(
                              key: ValueKey('organization.openOnHost ${project.name}'),
                              onPressed: () => widget.onHost!(project.name, host),
                              child: Text('Open it on $host'),
                            ),
                          Chip(label: Text(_isLocked(project) ? 'locked' : _roleIn(view, project)!)),
                          if (project.host case final host? when !_isLocked(project))
                            if (widget.menuFor?.call(project.name, host) case final commands? when commands.isNotEmpty)
                              CommandMenu(
                                key: ValueKey('organization.projectMenu ${project.name}'),
                                commands: commands,
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
                        subtitle: const Text('on this computer alone, outside the organization'),
                        onTap: widget.onOthers,
                      ),
                    ),
              ],
            ),
          if (view != null && mine.isEmpty)
            const Text(
              'You are in no project yet. Nobody joins on their own: a project admin adds you. Every project of the '
              'organization is listed under Organization.',
            ),
          if (widget.onOthers case final others?)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('projects-of-machines'),
                onPressed: others,
                child: const Text('Projects on your machines, outside the organization'),
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
/// the same page and changes nothing. Work on it starts from its row under Projects, which names its host.
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

  @override
  void initState() {
    super.initState();
    unawaited(_read());
    widget.organization.addListener(_organizationChanged);
    if (widget.organization.view == null) unawaited(widget.organization.refresh());
  }

  @override
  void dispose() {
    widget.organization.removeListener(_organizationChanged);
    super.dispose();
  }

  // A change was asked for and the store answered: what is shown is read again, never assumed.
  late bool _wasBusy = widget.organization.busy;
  int _reads = 0;
  void _organizationChanged() {
    final busy = widget.organization.busy;
    if (_wasBusy && !busy) unawaited(_read());
    _wasBusy = busy;
    if (mounted) setState(() {});
  }

  Future<void> _read() async {
    final read = ++_reads;
    try {
      final view = await widget.organization.source.readProject(widget.project);
      // A read that answers after a later one was asked for may be the older.
      if (!mounted || read != _reads) return;
      setState(() {
        _view = view;
        _problem = null;
      });
    } on OrganizationRefused catch (refused) {
      if (mounted && read == _reads) setState(() => _problem = refused.words);
    }
  }

  void _show(Widget dialog) => unawaited(showDialog<void>(context: context, builder: (_) => dialog));

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
            label: const Text('Projects'),
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.small,
          children: [
            Text(widget.project, style: Theme.of(context).textTheme.headlineSmall),
            if (view != null && organization != null) Chip(label: Text(_myRole(view, organization))),
          ],
        ),
        if (_problem case final problem?) _Problem(problem),
        if (view != null) ...[
          if (!isAdmin) Text('${_adminsWords(view)} Only they change this project.'),
          const SizedBox(height: Space.normal),
          if (!view.opened) _notOpened(view, isAdmin),
          _address(view, changes),
          if (view.repositoriesProblem case final problem?) _Problem(problem),
          _repositories(view, changes),
          _members(view, organization, changes),
          if (isAdmin) const Text('A change is signed with your key.'),
        ],
      ],
    );
  }

  String _adminsWords(ProjectView view) => view.admins.isEmpty
      ? 'It has no project admin.'
      : '${view.admins.length == 1 ? 'Project admin' : 'Project admins'} ${view.admins.join(', ')}.';

  Widget _address(ProjectView view, bool isAdmin) => Padding(
    padding: const EdgeInsets.only(bottom: Space.normal),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.normal,
      runSpacing: Space.small,
      children: [
        Text('Project repository: ${view.address ?? 'none named yet'}'),
        if (isAdmin)
          OutlinedButton(
            key: const ValueKey('organization.changeAddress'),
            onPressed: () => _show(_AddressDialog(widget.organization, view)),
            child: const Text('Change the address…'),
          ),
      ],
    ),
  );

  Widget _notOpened(ProjectView view, bool isAdmin) => Padding(
    padding: const EdgeInsets.only(bottom: Space.normal),
    child: isAdmin
        ? Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.normal,
            runSpacing: Space.small,
            children: [
              const Text(
                'This project has not been opened yet. Opening it makes its project repository, signed by you.',
              ),
              FilledButton(
                key: const ValueKey('organization.openProject'),
                onPressed: () => _show(
                  OrganizationConfirmDialog(
                    widget.organization,
                    base: view.revision,
                    title: 'Open ${view.name}?',
                    words: 'Porelo makes the project repository and signs its first project.yml with your key. Then you add its repositories and members.',
                    confirm: 'Open the project',
                    change: OrganizationChange.openProject,
                    input: {'project': view.name},
                  ),
                ),
                child: const Text('Open the project'),
              ),
            ],
          )
        : Text(
            '${view.admins.isEmpty ? 'Its project admin' : view.admins.join(' or ')} has not opened this project yet.',
          ),
  );

  String _myRole(ProjectView view, OrganizationView organization) {
    final me = view.members.where((member) => member.login == organization.me).firstOrNull;
    if (me == null) return 'not a member';
    if (!organization.holdsRoles || me.standing == CardStanding.revoked || me.standing == CardStanding.refused) {
      return 'no role';
    }
    if (me.locked) return 'locked';
    return me.role == ProjectView.adminRole ? 'project admin' : me.role;
  }

  Widget _repositories(ProjectView view, bool isAdmin) => FilteredListSection(
    title: 'Repositories',
    storageId: 'project-repositories ${view.name}',
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
            subtitle: Text(repository.address ?? 'no upstream named'),
            trailing: isAdmin
                ? TextButton(
                    key: ValueKey('organization.removeRepository/${repository.name}'),
                    onPressed: () => _show(
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
                    child: const Text('Remove'),
                  )
                : null,
          ),
        ),
    ],
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
                          'They are admitted on its host, as ${view.roles.firstOrNull ?? 'a member'}; '
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
              changes: isAdmin,
              roles: view.roles,
              organization: widget.organization,
              view: view,
              onRemove: () => _show(
                OrganizationConfirmDialog(
                  widget.organization,
                  base: view.revision,
                  title: 'Remove ${member.login} from ${view.name}?',
                  words:
                      '${member.login} is out of this project, and its host locks them when it takes the change: '
                      'within five minutes, or at once on its Refresh.',
                  confirm: 'Remove',
                  change: OrganizationChange.removeProjectMember,
                  input: {'project': view.name, 'login': member.login},
                ),
              ),
            ),
          ),
      ],
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

  Future<void> _change(String role) async {
    final refusal = await widget.organization.write(OrganizationChange.changeProjectMemberRole, {
      'project': widget.view.name,
      'login': widget.member.login,
      'role': role,
    }, base: widget.view.revision);
    if (mounted) setState(() => _refusal = refusal);
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
              if (widget.changes && widget.roles.contains(member.role))
                DropdownButton<String>(
                  key: ValueKey('organization.memberRole/${member.login}'),
                  value: member.role,
                  // Set back by the read after the store's answer, never by choosing.
                  onChanged: widget.organization.busy
                      ? null
                      : (role) {
                          if (role != null && role != member.role) unawaited(_change(role));
                        },
                  items: [for (final role in widget.roles) DropdownMenuItem(value: role, child: Text(role))],
                )
              else
                Text(member.role),
              Text(standing.$1, style: TextStyle(color: standing.$2)),
              if (member.locked) Text('locked', style: TextStyle(color: colors.error)),
              if (widget.changes)
                TextButton(
                  key: ValueKey('organization.lockMember/${member.login}'),
                  onPressed: widget.organization.busy ? null : () => unawaited(_lock(!member.locked)),
                  child: Text(member.locked ? 'Unlock' : 'Lock'),
                ),
              if (widget.changes)
                TextButton(
                  key: ValueKey('organization.removeMember/${member.login}'),
                  onPressed: widget.onRemove,
                  child: const Text('Remove'),
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
      ],
    ),
    invalid: () {
      if (!_repositoryName.hasMatch(_name.text.trim())) {
        return 'A repository name holds letters, digits, ".", "_" and "-", and opens with a letter or digit.';
      }
      return _addressRefused(_address.text.trim());
    },
    ask: () => _name.text.trim().isEmpty || _address.text.trim().isEmpty
        ? null
        : (
            change: OrganizationChange.addProjectRepository,
            input: {'project': widget.view.name, 'repository': _name.text.trim(), 'address': _address.text.trim()},
          ),
  );
}
