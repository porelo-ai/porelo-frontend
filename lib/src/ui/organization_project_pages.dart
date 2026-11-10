import 'dart:async';

import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/task_certifying.dart';
import '../app/host_progress.dart';
import '../app/organization_source.dart';
import '../app/repository_address.dart';
import '../app/run_here.dart' show WorkspaceRefused;
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'page_explanation.dart';
import 'organization_dialogs.dart';
import 'organization_host_pages.dart';
import 'organization_token_words.dart';
import 'placing_project_dialog.dart' show GiveHostToken;
import 'tokens.dart';
import 'expandable_list_row.dart';

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
    this.onGiveToken,
    this.tokenBusy,
    this.onOthers,
    super.key,
  });

  /// Gives a machine waiting for one this person's token; null where it cannot be given from here.
  final GiveHostToken? onGiveToken;

  /// Why a machine cannot be given the token now, as while it is being given it; null where it can.
  final String? Function(String host)? tokenBusy;

  /// Opens the projects of every machine this computer watches, also those no organization holds: *Default* and a
  /// checkout's local copy stand only there.
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

  /// Why a grey button of [project]'s row is grey, said on the row: the same buttons, the same terms.
  String _greyWords(OrganizationProject project, OrganizationView view) {
    final host = project.host;
    if (host == null || _isLocked(project)) return '';
    final push = (_central[project.name]?.offersPush ?? false)
        ? widget.menuFor?.call(project.name, host).where((each) => each.id == 'project.pushApprovedMain').firstOrNull
        : null;
    final connects = view.holdsRoles && !(widget.connections?.connected(host) ?? false);
    return <String>[
      if (push?.unavailable case final why?) '${push!.label.replaceAll('…', '')}: ${printableForAPerson(why)}',
      if (connects && widget.connections == null) 'This computer has no way to connect yet.',
      if (connects && _connecting.contains(host)) 'Connecting to $host…',
    ].map((words) => ' · $words').join();
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
          if (view == null)
            FilteredListSection(
              title: 'My projects',
              titleInAppBar: true,
              storageId: 'my-projects',
              leaf: true,
              read: false,
              rows: const [],
              subtitle: 'not read',
              busy: widget.organization.problem == null,
              problem: widget.organization.problem,
              onRetry: () => unawaited(widget.organization.refresh()),
              emptyWords: 'No organization has been read.',
            ),
          // The organization's projects alone: Default and a checkout's local copy are no project of it.
          if (view != null)
            FilteredListSection(
              title: 'My projects',
              titleInAppBar: true,
              leaf: true,
              subtitle: counted(mine.length, 'project', 'projects'),
              busy: widget.organization.busy,
              readAt: widget.organization.readAt,
              problem: widget.organization.problem,
              onRetry: () => unawaited(widget.organization.refresh()),
              storageId: 'my-projects',
              rows: [for (final project in mine) (words: project.name, child: _row(view, project))],
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

  /// One of the person's projects: where it is, how it stands with central, and what its machine waits for.
  Widget _row(OrganizationView view, OrganizationProject project) {
    final waits = projectWaits(view, widget.connections, project.name);
    final forge = organizationForgeName(view);
    final tokens = [
      for (final wait in waits)
        if (wait.said.waitsForToken)
          giveTokenCommand(
            host: wait.host,
            project: project.name,
            forge: forge,
            give: widget.onGiveToken == null ? null : (host) => unawaited(widget.onGiveToken!(host)),
            busy: () => widget.tokenBusy?.call(wait.host),
            hidden: !hostsAdministeredBy(view).any((host) => host.name == wait.host),
          ),
    ];
    return LeafListRow(
      key: ValueKey('my-project ${project.name}'),
      state: _isLocked(project) ? 'locked' : _roleIn(view, project)!,
      leading: const Icon(Icons.folder_outlined),
      title: project.name,
      subtitle: Text(
        '${project.repositories == null ? '' : '${_count(project.repositories!, 'repository', 'repositories')} · '}'
        '${peopleOf(project)} · '
        '${project.host == null ? 'not on a machine yet · a Machine Admin puts it on one' : 'on ${project.host}'}'
        '${[for (final wait in waits) ' · ${wait.host} ${waitingWords(wait.said, forge)}'].join()}'
        '${_centralWords(view, _central[project.name]) == null ? '' : ' · ${_centralWords(view, _central[project.name])}'}'
        '${_refusals[project.host] == null ? '' : ' · ${_refusals[project.host]}'}'
        '${_greyWords(project, view)}',
      ),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.normal,
        children: [
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
            if (widget.connections case final held? when _refusals[host] != null && !_connecting.contains(host))
              LastConnectAttempt(held, host),
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
                ...tokens,
              ],
              tooltip: 'What can be done with ${project.name}',
            )
          // Carried in part, it names no one machine, yet one that waits for the token is offered it here too.
          else if (tokens.isNotEmpty && !_isLocked(project))
            CommandMenu(
              key: ValueKey('organization.projectMenu ${project.name}'),
              commands: tokens,
              tooltip: 'What can be done with ${project.name}',
            ),
        ],
      ),
      onTap: () => widget.onProject(project.name),
    );
  }
}

String _count(int count, String one, String many) => counted(count, one, many);

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
  const OrganizationProjectPage({
    required this.organization,
    required this.project,
    required this.onBack,
    this.path = const [],
    this.connections,
    this.onGiveToken,
    super.key,
  });

  /// The ancestors of the place this project was opened from.
  final List<LeafPathStep> path;

  /// The organization.
  final Organization organization;

  /// How this computer reaches the machines, to follow one the project was just put on; null where it cannot.
  final HostConnections? connections;

  /// Gives a machine waiting for one this person's token; null where it cannot be given from here.
  final GiveHostToken? onGiveToken;

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

  /// Whether [_view] is the session's last read, not yet confirmed by this page's own: a change would carry its
  /// revision, so none is offered.
  bool _lastRead = false;

  @override
  void initState() {
    super.initState();
    _view = widget.organization.lastReadOf(widget.project);
    _lastRead = _view != null;
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
        _lastRead = false;
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
    final changes = isAdmin && view.opened && !_lastRead;
    final commands = [
      if (changes)
        for (final policy in ['required', 'optional'])
          if (view.review != policy) _reviewCommand(view, policy),
      ..._machineCommands(organization),
    ];
    final repositoryWords = view == null || !view.opened
        ? 'not read'
        : view.repositoriesProblem ?? '${view.repositories.length} repositories';
    // Until its first read lands, the head says what the organization's list holds of it, as its row there does.
    final listed = view == null && _reading && organization != null
        ? organization.projects.where((each) => each.name == widget.project).firstOrNull
        : null;
    return ListView(
      key: ValueKey('organization-project ${widget.project}'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        PageHead(
          title: widget.project,
          titleInAppBar: false,
          path: widget.path.isEmpty ? [(label: 'My projects', go: widget.onBack)] : widget.path,
          pathKeys: const {
            'My projects': Key('organization-project-back'),
            'Projects': Key('organization-project-back'),
          },
          subtitle: view != null && (_lastRead || (_problem == null && !_reading))
              ? '$repositoryWords · ${counted(view.members.length, 'member', 'members')}'
              : listed != null
              ? '${listed.repositories == null ? '' : '${_count(listed.repositories!, 'repository', 'repositories')} · '}'
                    '${peopleOf(listed)}'
              : 'not read',
          status: view != null && organization != null
              ? StateChip(_myRole(view, organization))
              : listed != null && _roleIn(organization!, listed) != null
              ? StateChip(_roleIn(organization, listed)!)
              : null,
          action: commands.isEmpty
              ? null
              : CommandMenu(tooltip: 'What can be done with ${widget.project}', commands: commands),
        ),
        if (_problem case final problem?) _Problem(problem),
        if (_reading && _lastRead)
          Text('Reading ${widget.project} again…', key: const Key('organization-project-reading-again'))
        else if (_reading)
          Text('Reading ${widget.project}: its address, repositories, and members…'),
        if (_lastRead && !_reading)
          Text(
            'This is ${widget.project} as last read; it could not be read again.',
            key: const Key('organization-project-as-last-read'),
          ),
        OrganizationChangeMark(widget.organization),
        for (final change in widget.organization.rowChanges)
          // Putting it on a machine or taking it off is asked from here too: its refusal stands here.
          if (change.input['project'] == widget.project &&
              (view == null ||
                  change.change == OrganizationChange.createProjectRepository ||
                  change.change == OrganizationChange.addProjectToHost ||
                  change.change == OrganizationChange.removeProjectFromHost))
            OrganizationPendingRow(widget.organization, change, onReview: () => unawaited(_read())),
        if (view != null && !view.opened) _notOpened(view),
        if (view != null && view.opened) ...[
          Text(_reviewWords(view.review)),
          if (!isAdmin) Text('${_adminsWords(view)} Only they change this project.'),
          const SizedBox(height: Space.normal),
          _address(view, changes),
          _repositories(view, changes),
          _members(view, organization, changes),
          if (isAdmin) const Text('A change is signed with your key.'),
        ],
      ],
    );
  }

  /// Putting the project on a machine and taking it off, as its row on the Organization page offers them: to whoever
  /// administers a machine to put it on, or the one carrying it.
  List<Command> _machineCommands(OrganizationView? organization) {
    final project = organization?.projects.where((each) => each.name == widget.project).firstOrNull;
    if (organization == null || project == null) return const [];
    final hosts = hostsAdministeredBy(organization);
    // Its placing waiting for the token on a machine of this person's is followed again from here, as it was put on.
    final waits = projectWaits(organization, widget.connections, project.name);
    return [
      if ((!organization.carriedWhole(project.name) ||
              waits.any((wait) => hosts.any((host) => host.name == wait.host))) &&
          hosts.isNotEmpty)
        Command(
          id: 'project.putOnMachine',
          label: 'Put it on a machine…',
          group: 'Organization',
          home: Home.organizationRow,
          run: () => unawaited(
            putProjectOnAMachine(
              context,
              organization: widget.organization,
              project: widget.project,
              connections: widget.connections,
              onGiveToken: widget.onGiveToken,
            ),
          ),
        ),
      if (project.host case final machine? when hosts.any((host) => host.name == machine))
        Command(
          id: 'project.takeOffMachine',
          label: 'Take it off the machine…',
          group: 'Organization',
          home: Home.organizationRow,
          danger: true,
          run: () => _show(takeProjectOffTheMachine(widget.organization, project: widget.project, machine: machine)),
        ),
    ];
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
      unavailable: widget.organization.busy ? 'Another change is still being asked for.' : null,
      run: () => _show(
        OrganizationConfirmDialog(
          widget.organization,
          title: policy == 'required' ? 'Require review in $target?' : 'Make review optional in $target?',
          words: policy == 'required'
              ? 'Work must be reviewed before it leaves the gate. $_byHandWords'
              : 'Work may leave the gate without a review. $_byHandWords',
          confirm: _showTheEntry,
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
        leaf: true,
        subtitle: counted(view.repositories.length, 'repository', 'repositories'),
        read: view.opened,
        busy: _reading,
        problem: _problem ?? view.repositoriesProblem,
        onRetry: () => unawaited(_read()),
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
              child: LeafListRow(
                leading: const Icon(Icons.book_outlined),
                title: repository.name,
                state: repository.namesNoCentral
                    ? 'central not named'
                    : switch (repository.review) {
                        'required' => 'review required',
                        'optional' => 'review optional',
                        _ => 'review not read',
                      },
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
                                  title: 'Name where a machine takes ${repository.name} from?',
                                  words:
                                      'A machine takes it from ${repository.address}, its own address. '
                                      '$_byHandWords',
                                  confirm: _showTheEntry,
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
                                title: 'Remove ${repository.name} from ${view.name}?',
                                words:
                                    'It is no longer part of the project. The repository itself stays where it is. '
                                    '$_byHandWords',
                                confirm: _showTheEntry,
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
      leaf: true,
      subtitle: counted(view.members.length, 'member', 'members'),
      busy: _reading,
      problem: _problem,
      onRetry: () => unawaited(_read()),
      storageId: 'project-members ${view.name}',
      greyWords: [
        if (isAdmin && view.roles.isEmpty)
          'Add a member: ${view.name} has no role to give yet.'
        else if (isAdmin && candidates.isEmpty)
          'Add a member: everyone holding a role in the organization is in ${view.name} already.',
      ],
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
              // A last read not yet confirmed offers no change: it would carry that read's revision.
              changes: !_lastRead && (organization?.mayChangeMember(member.role, isProjectAdmin: isAdmin) ?? isAdmin),
              roles: [
                for (final role in view.roles)
                  if (!_lastRead && (organization?.mayChangeMember(role, isProjectAdmin: isAdmin) ?? isAdmin)) role,
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
            decoration: InputDecoration(helperText: 'Choose a role other than ${widget.member.role}.'),
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
              StateChip(standing.$1),
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
          if (_refusal case final refusal?) ...[
            Text(refusal, style: TextStyle(color: colors.error)),
            OrganizationVaultShut(widget.organization, key: ValueKey(refusal)),
          ],
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
    title: 'Add a repository to ${widget.view.name}',
    confirm: _showTheEntry,
    body: (context, changed) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(_byHandWords),
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

/// What a change to the project's own file does now: Porelo says the entry, and a project admin commits it.
const _byHandWords = 'Porelo changes no project file: it says the entry to write, and you commit it.';

/// The button that asks Porelo for that entry.
const _showTheEntry = 'Show the entry';
