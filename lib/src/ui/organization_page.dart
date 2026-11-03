import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart' show checkHostName;

import '../app/commands.dart';
import '../app/key_recovery.dart' show BackupScope;
import '../app/organization_source.dart';
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'organization_dialogs.dart';
import 'how_long.dart';
import 'key_recovery_dialog.dart';
import 'pick_a_file.dart';
import 'tokens.dart';
import 'window_size.dart';

/// What is true of a project's name, as for any folder it becomes.
final _projectName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

/// The organization: who manages it, its people, its projects and its hosts. Everyone reads all of it; every action stands
/// in its row, for the person whose role it belongs to.
class OrganizationPage extends StatefulWidget {
  /// Reads [organization].
  const OrganizationPage({
    required this.organization,
    this.onProject,
    this.onHost,
    this.keys,
    this.pickFile = pickWithTheDesktop,
    super.key,
  });

  /// The organization.
  final Organization organization;

  /// Opens a project the person is in under *Projects*.
  final void Function(String project)? onProject;

  /// Opens a host's page for its host admin.
  final void Function(String host)? onHost;

  /// Runs the person's key commands in a terminal, absent where this computer offers none.
  final KeyCommands? keys;

  /// Chooses the file of a card someone handed over.
  final PickAFile pickFile;

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.organization.refresh());
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
            OrganizationChangeMark(organization),
            if (!organization.explanationClosed)
              _Explanation(onHide: () => setState(() => organization.explanationClosed = true)),
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
          child: const Text('Choose another organization…'),
        ),
      ),
      const SizedBox(height: Space.normal),
      _people(view, organization, show),
      _projects(view, organization, show),
      _hosts(view, organization, show),
      _owners(view, organization, show),
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
                          'Your key is revoked, and each host takes that within five minutes, or at once on its '
                          'Refresh. You hold no role until you come back with a new card and a new key. Your places '
                          'in projects and on hosts stay under your login: to leave them for good, have yourself '
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
              if (person.login != view.me && view.isOwner)
                _command(
                  'replaceCard/${person.login}',
                  'Accept a new card…',
                  () => show(_AcceptCardDialog(organization, login: person.login, pickFile: widget.pickFile)),
                ),
              if (person.login != view.me && view.isOwner && person.standing != CardStanding.revoked)
                _command(
                  'revokeCard/${person.login}',
                  'Revoke the card…',
                  danger: true,
                  () => show(
                    OrganizationConfirmDialog(
                      organization,
                      title: "Revoke ${person.login}'s card?",
                      words:
                          "${person.login}'s key is revoked, and each host takes that within five minutes, or at once "
                          'on its Refresh. They hold no role until they come back with a new card and a new key. Their '
                          'places in projects and on hosts stay under their login: to put them out, also remove them '
                          'from each project and host.',
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
  );

  Widget _projects(OrganizationView view, Organization organization, void Function(Widget) show) => FilteredListSection(
    title: 'Projects',
    storageId: 'organization-projects',
    collapsible: true,
    openWhenCompact: false,
    sorts: [
      SectionSort('Name', (row) => view.projects[row].name),
      SectionSort('State', (row) => _standingIn(view, view.projects[row])),
      SectionSort(
        'Machine',
        (row) => view.hosts.where((host) => host.projects.contains(view.projects[row].name)).firstOrNull?.name ?? '',
      ),
    ],
    commands: [
      if (view.isOwner)
        _command(
          'addProject',
          'Add a project',
          () => show(
            OrganizationPersonDialog(
              organization,
              title: 'Add a project to ${view.name}',
              nameLabel: 'Name',
              nameHint: 'e.g. sprint7-demo',
              personLabel: 'Project admin',
              words:
                  "The project's card is added to the organization now. Its project admin makes the project "
                  'repository and signs its first project.yml when they first open the project under Projects, then '
                  'adds its members. No host is chosen here: a host admin puts the project on a host.',
              confirm: 'Add the project',
              check: (name) => _projectName.hasMatch(name)
                  ? null
                  : 'A project name holds letters, digits, ".", "_" and "-", and opens with a letter or digit.',
              change: OrganizationChange.addProject,
              input: (name, person) => {'project': name, 'admin': person},
            ),
          ),
        ).command,
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
            actions: [
              if (view.holdsRoles && widget.onProject != null && _isIn(view, project))
                _command('openProject/${project.name}', 'Open under Projects', () => widget.onProject!(project.name)),
              if (view.isOwner) ...[
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
                      personLabel: 'Project admin',
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
                  'Change the project admin…',
                  () => show(
                    OrganizationPersonDialog(
                      organization,
                      title: 'Another project admin for ${project.name}',
                      personLabel: 'Project admin',
                      words: 'They become the first admin on its card, and may change its members and repositories.',
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
  );

  Widget _hosts(OrganizationView view, Organization organization, void Function(Widget) show) => FilteredListSection(
    title: 'Hosts',
    storageId: 'organization-hosts',
    collapsible: true,
    openWhenCompact: false,
    sorts: [
      SectionSort('Name', (row) => view.hosts[row].name),
      SectionSort('State', (row) => _hostWords(view.hosts[row])),
    ],
    commands: [
      if (view.isOwner)
        _command(
          'addHost',
          'Add a host',
          () => show(
            OrganizationPersonDialog(
              organization,
              title: 'Add a host to ${view.name}',
              nameLabel: 'Name',
              nameHint: 'e.g. build-2',
              personLabel: 'First host admin',
              words:
                  "The host's card is added with its name and first host admin. The host admin enters its address "
                  "and host key when they set the machine up, then puts projects on it and names further host "
                  "admins, all on the host's page under Machines.",
              confirm: 'Add the host',
              check: (name) {
                try {
                  checkHostName(name);
                  return null;
                } on FormatException catch (refused) {
                  return refused.message;
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
          child: _Row(
            icon: Icons.dns_outlined,
            title: host.name,
            subtitle: _hostWords(host),
            actions: [
              if (view.holdsRoles && widget.onHost != null && host.admins.contains(view.me))
                _command('openHost/${host.name}', "Open the host's page", () => widget.onHost!(host.name)),
              if (view.isOwner)
                _command(
                  'removeHost/${host.name}',
                  'Remove the host…',
                  danger: true,
                  () => show(
                    OrganizationConfirmDialog(
                      organization,
                      title: 'Remove ${host.name}?',
                      words: _removingHostWords(host),
                      confirm: 'Remove the host',
                      change: OrganizationChange.removeHost,
                      input: {'host': host.name},
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );

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
              words: 'They may change its projects, its hosts and its owners, as you may.',
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
                          ? 'You no longer change its projects, its hosts or its owners.'
                          : '$owner no longer changes its projects, its hosts or its owners.',
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
  );
}

/// One action in a row of the organization's page.
class _Action {
  const _Action(this.command, {required this.danger});

  final Command command;
  final bool danger;
}

_Action _command(String id, String label, VoidCallback run, {bool danger = false}) => _Action(
  organizationCommand(id: id, label: label, run: run, danger: danger),
  danger: danger,
);

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
    for (final host in view.hosts)
      if (host.admins.contains(view.me)) 'host admin of ${host.name}',
  ];
  return roles.isEmpty ? null : 'you are ${roles.join(' and ')}';
}

String _personWords(OrganizationView view, OrganizationPerson person) => [
  person.key ?? 'its key could not be read',
  if (person.expires case final expires?) 'until $expires',
  if (view.owners.contains(person.login)) 'organization owner',
  for (final host in view.hosts)
    if (host.admins.contains(person.login)) 'host admin of ${host.name}',
  for (final project in view.projects)
    if (project.admins.contains(person.login))
      'project admin of ${project.name}'
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
    'no project admin'
  else
    '${project.admins.length == 1 ? 'project admin' : 'project admins'} ${project.admins.join(', ')}',
  peopleOf(project),
  if (project.host case final host?) 'on $host' else 'on no host yet',
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
    'no host admin'
  else if (host.admins.length == 1)
    'host admin ${host.admins.single}'
  else
    'host admins ${host.admins.join(', ')}',
  if (host.projects.isEmpty) 'carries no project' else 'carries ${host.projects.join(', ')}',
].join(' · ');

String _reach(String address, int port) => address.contains(':') ? '[$address]:$port' : '$address:$port';

String _removingProjectWords(OrganizationProject project) => [
  'Its card and its members leave the organization.',
  if (project.host case final host?) 'It is still on $host, and its host admins take it off.',
  'Its repositories stay where they are.',
].join(' ');

String _removingHostWords(OrganizationHost host) => [
  'Its card leaves the organization.',
  if (host.projects.isNotEmpty) 'It still carries ${host.projects.join(', ')}.',
  'The machine itself keeps running.',
].join(' ');

class _Explanation extends StatelessWidget {
  const _Explanation({required this.onHide});

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
                    'What is the organization?',
                    'Who manages it, its people with their cards, its projects with their members, and its hosts. '
                        'Porelo asks it whom to trust before anyone gets onto a host.',
                  ),
                  part(
                    'Where it is kept',
                    'Wherever the installed adapter keeps it; with GitHub, in the GitHub organization of the same '
                        'name.',
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
                const Text('Add your card so that a project admin can add you to a project and a host can admit you.'),
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
  });

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
          Text('This computer reads no organization yet', style: Theme.of(context).textTheme.titleSmall),
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
                child: const Text('Choose the organization…'),
              ),
              OutlinedButton(
                key: const ValueKey('createOrganization'),
                onPressed: onCreate,
                child: const Text('Create the organization…'),
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
        ? 'Create the organization'
        : widget.replacing
        ? 'Choose another organization'
        : 'Choose the organization',
    confirm: widget.creating ? 'Create it' : 'Choose it',
    body: (context, changed) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.creating)
          const Text(
            'Make an empty repository on your forge first: Porelo does not make it. Give its address here, and your '
            'card goes in as its first, and only, owner.',
          )
        else if (widget.replacing)
          const Text(
            'This computer reads one organization, so it will read that one instead of this one. An empty repository '
            'cannot be chosen here: only a computer that reads no organization yet can fill one.',
          )
        else
          const Text('An empty repository is not chosen but filled: cancel this and use *Create the organization…*.'),
        const SizedBox(height: Space.small),
        const Text(
          "An organization lives on a forge of its own, outside every host: a host follows it, and cannot hold it.",
        ),
        const SizedBox(height: Space.small),
        TextField(
          key: const Key('organization-address'),
          controller: _address,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "The organization's repository address",
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
