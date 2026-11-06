import 'dart:async';

import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/organization_source.dart';
import 'choice_field.dart';
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'placing_project_dialog.dart';
import 'project_file_entry.dart';
import 'tokens.dart';

/// List changes close onto a provisional row; other changes keep their progress and refusal in the dialog.
class OrganizationChangeDialog extends StatefulWidget {
  /// Asks [organization] for the change [ask] answers.
  const OrganizationChangeDialog({
    super.key,
    required this.organization,
    required this.title,
    required this.confirm,
    required this.body,
    required this.ask,
    this.invalid,
    this.base,
  });

  /// The organization the change is asked of.
  final Organization organization;

  /// The dialog's title.
  final String title;

  /// The confirming button's label.
  final String confirm;

  /// The dialog's content, told again when a choice changes.
  final Widget Function(BuildContext context, VoidCallback changed) body;

  /// The change as it now stands, or null while something is still to be chosen.
  final ({OrganizationChange change, Map<String, String> input})? Function() ask;

  /// The revision it is made against, where it is not the organization's as last read.
  final String? base;

  /// Why what was given cannot be asked for, or null where it can; said on confirming, before the store is asked.
  final String? Function()? invalid;

  @override
  State<OrganizationChangeDialog> createState() => _OrganizationChangeDialogState();
}

class _OrganizationChangeDialogState extends State<OrganizationChangeDialog> {
  String? _refusal;
  bool _asking = false;
  ProjectFileByHand? _byHand;

  // Counts what was typed since the entry was asked for: an entry for what is no longer typed is never shown.
  int _edits = 0;

  Future<void> _confirm() async {
    if (widget.organization.busy) {
      setState(() => _refusal = 'Another change is still being asked for.');
      return;
    }
    if (widget.invalid?.call() case final words?) {
      setState(() => _refusal = words);
      return;
    }
    final asked = widget.ask();
    if (asked == null) return;
    if (asked.change.byHand) return _askForTheEntry(asked.change, asked.input);
    if (widget.organization.view != null && OrganizationRowChange.target(asked.change, asked.input) != null) {
      unawaited(widget.organization.write(asked.change, asked.input, base: widget.base, provisional: true));
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _asking = true;
      _refusal = null;
    });
    final refusal = await widget.organization.write(asked.change, asked.input, base: widget.base);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _asking = false;
        _refusal = refusal;
      });
    }
  }

  // A project file is the project admin's to change: the dialog stays open on the entry Porelo says to write.
  Future<void> _askForTheEntry(OrganizationChange change, Map<String, String> input) async {
    setState(() {
      _asking = true;
      _refusal = null;
    });
    final asked = _edits;
    final answer = await widget.organization.entryFor(change, input);
    if (!mounted) return;
    if (answer.byHand == null && answer.refusal == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _asking = false;
      if (asked == _edits) {
        _byHand = answer.byHand;
        _refusal = answer.refusal;
      }
    });
  }

  @override
  // Open until its change is answered, or the store's refusal would have nowhere to be said.
  Widget build(BuildContext context) => PopScope(
    canPop: !_asking,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: Sizes.dialogSmall,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A refusal answers what was asked, not what is being typed since.
              widget.body(
                context,
                () => setState(() {
                  _refusal = null;
                  _byHand = null;
                  _edits++;
                }),
              ),
              if (_asking) ...[
                const SizedBox(height: Space.small),
                Text('${widget.confirm}…'),
                OrganizationChangeMark(widget.organization),
                const Text('Any failure will appear here.'),
              ],
              if (_refusal case final refusal?) ...[
                const SizedBox(height: Space.small),
                Text(refusal, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (_byHand case final byHand?) ...[const SizedBox(height: Space.small), ProjectFileEntry(byHand)],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _asking ? null : () => Navigator.of(context).pop(),
          child: Text(_byHand == null ? 'Cancel' : 'Close'),
        ),
        if (_byHand == null)
          FilledButton(
            key: const Key('organization-confirm'),
            onPressed: _asking || widget.ask() == null ? null : () => unawaited(_confirm()),
            child: Text(widget.confirm),
          ),
      ],
    ),
  );
}

/// Says that a change was asked for and has not been answered: a write takes seconds, and nothing else shows it.
class OrganizationChangeMark extends StatelessWidget {
  /// Shows while [organization] waits for its store's answer.
  const OrganizationChangeMark(this.organization, {super.key});

  /// The organization whose change is being asked for.
  final Organization organization;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: organization,
    builder: (context, _) => organization.busy
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(
                key: Key('organization-change-running'),
                semanticsLabel: 'A change is under way',
              ),
              Text(organization.changeProgress ?? 'A change is under way…'),
            ],
          )
        : const SizedBox.shrink(),
  );
}

/// Keeps a list's real rows until a read answers, replacing only rows with a provisional change.
extension OrganizationSectionChanges on FilteredListSection {
  /// Marks requests without changing this list's source rows, filters, or sort keys.
  Widget withOrganizationChanges(
    Organization organization, {
    required List<String> names,
    void Function(String project)? reviewProject,
  }) => OrganizationListSection(organization, names: names, section: this, reviewProject: reviewProject);
}

/// A list with its running or refused requests kept alongside its source rows.
class OrganizationListSection extends StatelessWidget {
  /// Uses [names] in the same order as [section]'s source rows.
  const OrganizationListSection(
    this.organization, {
    required this.names,
    required this.section,
    this.reviewProject,
    super.key,
  });

  /// The source of pending changes.
  final Organization organization;

  /// Each source row's name, independent of its displayed words.
  final List<String> names;

  /// The list's existing presentation and actions.
  final FilteredListSection section;

  /// Opens or rereads the project before retrying an answered refusal.
  final void Function(String project)? reviewProject;

  @override
  Widget build(BuildContext context) {
    final changes = {
      for (final change in organization.rowChanges)
        if (change.inList(section.storageId) case final target?) target.name: change,
    };
    final added = changes.keys.where((name) => !names.contains(name)).toList();
    Widget pending(OrganizationRowChange change) => OrganizationPendingRow(
      organization,
      change,
      name: change.inList(section.storageId)!.name,
      onReview: reviewProject == null || change.input['project'] == null
          ? null
          : () => reviewProject!(change.input['project']!),
    );
    return FilteredListSection(
      title: section.title,
      storageId: section.storageId,
      emptyWords: section.emptyWords,
      greyWords: section.greyWords,
      drawnCommands: section.drawnCommands,
      collapsible: section.collapsible,
      initiallyOpen: section.initiallyOpen,
      openWhenCompact: section.openWhenCompact,
      reveal: changes.isEmpty ? section.reveal : '${changes.values.last.change.name} ${changes.keys.last}',
      actions: [for (final action in section.actions) _WhileIdle(organization, child: action)],
      commands: [
        for (final command in section.commands)
          command.unless(organization.busy ? 'Another change is still being asked for.' : null),
      ],
      sorts: section.sorts == null
          ? null
          : [
              for (final sort in section.sorts!)
                SectionSort(
                  sort.label,
                  (index) => index < names.length ? sort.keyOf(index) : added[index - names.length],
                ),
            ],
      rows: [
        for (final (index, row) in section.rows.indexed)
          (
            words: row.words,
            child: changes.containsKey(names[index])
                ? pending(changes[names[index]]!)
                : _WhileIdle(organization, child: row.child),
          ),
        for (final name in added) (words: name, child: pending(changes[name]!)),
      ],
    );
  }
}

class _WhileIdle extends StatelessWidget {
  const _WhileIdle(this.organization, {required this.child});

  final Organization organization;
  final Widget child;

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: organization.busy,
    child: ExcludeFocus(
      excluding: organization.busy,
      child: Opacity(opacity: organization.busy ? 0.5 : 1, child: child),
    ),
  );
}

/// The running or refused row, with retry and drop in its menu.
class OrganizationPendingRow extends StatelessWidget {
  /// Shows [change] independently of the page that started it.
  const OrganizationPendingRow(this.organization, this.change, {this.name, this.onReview, super.key});

  /// The organization keeping the request.
  final Organization organization;

  /// The provisional request.
  final OrganizationRowChange change;

  /// The containing row's name where it stands for a nested list change.
  final String? name;

  /// Lets the person read the project's current state before another attempt.
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final target = OrganizationRowChange.target(change.change, change.input)!;
    return ListTile(
      key: ValueKey('organization-pending ${target.scope} ${target.name}'),
      leading: Icon(change.running ? Icons.hourglass_top : Icons.error_outline),
      title: Text(name ?? target.name),
      subtitle: Text(change.running ? '${target.doing} Any failure will appear in this row.' : change.refusal!),
      trailing: change.running
          ? null
          : CommandMenu(
              tooltip: 'What can be done with ${target.name}',
              commands: [
                organizationCommand(
                  id: 'retryChange/${target.scope}/${target.name}',
                  label: 'Try again',
                  unavailable: organization.whyNoRetry(change),
                  run: () => unawaited(organization.retryRowChange(change)),
                ),
                if (onReview != null)
                  organizationCommand(
                    id: 'reviewChange/${target.scope}/${target.name}',
                    label: 'Review the project',
                    unavailable: organization.busy ? 'Another change is still being asked for.' : null,
                    run: onReview!,
                  ),
                organizationCommand(
                  id: 'dropChange/${target.scope}/${target.name}',
                  label: 'Drop this request',
                  run: () => organization.dropRowChange(change),
                ),
              ],
            ),
    );
  }
}

/// Asks to confirm a change that takes something away.
class OrganizationConfirmDialog extends StatelessWidget {
  /// Says [words], and asks for [change] once confirmed.
  const OrganizationConfirmDialog(
    this.organization, {
    super.key,
    required this.title,
    required this.words,
    required this.confirm,
    required this.change,
    required this.input,
    this.base,
  });

  /// The organization the change is asked of.
  final Organization organization;

  /// The revision it is made against, where it is not the organization's as last read.
  final String? base;

  /// The dialog's title.
  final String title;

  /// What the change does, in a sentence or two.
  final String words;

  /// The confirming button's label.
  final String confirm;

  /// What is asked for.
  final OrganizationChange change;

  /// The change's values.
  final Map<String, String> input;

  @override
  Widget build(BuildContext context) => OrganizationChangeDialog(
    organization: organization,
    title: title,
    confirm: confirm,
    base: base,
    body: (_, _) => Text(words),
    ask: () => (change: change, input: input),
  );
}

/// Asks for a trusted person and, for something new, its name.
class OrganizationPersonDialog extends StatefulWidget {
  /// Asks for a person, and for a name where [nameLabel] is given.
  const OrganizationPersonDialog(
    this.organization, {
    super.key,
    required this.title,
    required this.personLabel,
    required this.words,
    required this.confirm,
    required this.change,
    required this.input,
    this.nameLabel,
    this.nameHint,
    this.check,
    this.people,
    this.base,
    this.changeFor,
    this.helper = 'Any person of the organization whose card is not revoked.',
    this.below,
    this.ready,
  });

  /// What else this person is asked, under the words.
  final Widget? Function(String? person, VoidCallback changed)? below;

  /// Whether what else was asked of this person is answered.
  final bool Function(String person)? ready;

  /// The organization the change is asked of.
  final Organization organization;

  /// The dialog's title.
  final String title;

  /// The person field's label.
  final String personLabel;

  /// What the change does, in a sentence or two.
  final String words;

  /// The confirming button's label.
  final String confirm;

  /// What is asked for.
  final OrganizationChange change;

  /// What is asked for with this person, where it depends on who they are; [change] otherwise.
  final OrganizationChange Function(String person)? changeFor;

  /// The change's values.
  final Map<String, String> Function(String name, String person) input;

  /// The name field's label, absent where no name is asked.
  final String? nameLabel;

  /// An example for the name field.
  final String? nameHint;

  /// What the choice is among.
  final String helper;

  /// Who can be chosen, where it is not every person whose card holds roles.
  final List<String>? people;

  /// The revision it is made against, where it is not the organization's as last read.
  final String? base;

  /// Why a name cannot be taken, or null where it can.
  final String? Function(String name)? check;

  @override
  State<OrganizationPersonDialog> createState() => _OrganizationPersonDialogState();
}

class _OrganizationPersonDialogState extends State<OrganizationPersonDialog> {
  final _name = TextEditingController();
  String? _person;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.organization.view!;
    return OrganizationChangeDialog(
      organization: widget.organization,
      title: widget.title,
      confirm: widget.confirm,
      base: widget.base,
      body: (context, changed) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.nameLabel != null)
            TextField(
              key: const Key('organization-name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: widget.nameLabel, hintText: widget.nameHint),
              onChanged: (_) => changed(),
            ),
          const SizedBox(height: Space.small),
          // A long list of people or machines narrows as one types.
          ChoiceField<String>(
            id: 'organization-person',
            label: widget.personLabel,
            helper: widget.helper,
            value: _person,
            choices: [
              for (final login in widget.people ?? [for (final person in view.holdingRoles) person.login])
                Choice(login, login == view.me ? '$login (you)' : login, id: 'organization-person-$login'),
            ],
            onChanged: (person) {
              _person = person;
              changed();
            },
          ),
          const SizedBox(height: Space.small),
          Text(widget.words),
          ?widget.below?.call(_person, changed),
        ],
      ),
      invalid: () => widget.check?.call(_name.text.trim()),
      ask: () {
        final person = _person;
        final name = _name.text.trim();
        if (person == null || (widget.nameLabel != null && name.isEmpty)) return null;
        if (!(widget.ready?.call(person) ?? true)) return null;
        return (change: widget.changeFor?.call(person) ?? widget.change, input: widget.input(name, person));
      },
    );
  }
}

/// Whether work on a project needs another person's review, chosen by nobody until it is chosen: it goes
/// into the first `project.yml`, so a side taken already would answer what nobody has read.
class ProjectReviewChoice extends StatelessWidget {
  /// Shows [review], `required`, `optional` or null, and tells [onChosen].
  const ProjectReviewChoice({super.key, required this.review, required this.onChosen});

  /// What is chosen so far.
  final String? review;

  /// Told what is chosen.
  final void Function(String review) onChosen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.small),
    child: Wrap(
      spacing: Space.small,
      runSpacing: Space.small,
      children: [
        ChoiceChip(
          key: const Key('organization-review-required'),
          label: const Text('Someone else reviews: review required'),
          selected: review == 'required',
          onSelected: (_) => onChosen('required'),
        ),
        ChoiceChip(
          key: const Key('organization-review-optional'),
          label: const Text('I work alone: review optional'),
          selected: review == 'optional',
          onSelected: (_) => onChosen('optional'),
        ),
      ],
    ),
  );
}

/// Creates a project's Git repository, against the project's own revision, read here where it is not given.
class CreateRepositoryDialog extends StatefulWidget {
  /// Asks [organization] to create the repository of [project].
  const CreateRepositoryDialog(this.organization, this.project, {super.key, this.base});

  /// The organization the change is asked of.
  final Organization organization;

  /// The project's name.
  final String project;

  /// The project's revision, where it was read already.
  final String? base;

  @override
  State<CreateRepositoryDialog> createState() => _CreateRepositoryDialogState();
}

class _CreateRepositoryDialogState extends State<CreateRepositoryDialog> {
  String? _review;
  late String? _base = widget.base;
  String? _problem;

  @override
  void initState() {
    super.initState();
    if (_base == null) unawaited(_read());
  }

  Future<void> _read() async {
    try {
      final read = await widget.organization.source.readProject(widget.project);
      if (mounted) setState(() => _base = read.revision);
    } on OrganizationRefused catch (refused) {
      if (mounted) setState(() => _problem = refused.words);
    }
  }

  @override
  Widget build(BuildContext context) => OrganizationChangeDialog(
    organization: widget.organization,
    base: _base,
    title: 'Create the Git repository of ${widget.project}?',
    confirm: "Create the project's Git repository",
    body: (context, changed) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Porelo makes the project repository on the organization's forge, private and empty, and signs its "
          'first project.yml with your key.',
        ),
        if (_problem case final problem?) Text(problem),
        if (_base == null && _problem == null) const Text('Reading the organization, before this can be made.'),
        ProjectReviewChoice(
          review: _review,
          onChosen: (review) {
            _review = review;
            changed();
          },
        ),
        const Text('You can change the review policy later from the project menu.'),
      ],
    ),
    ask: () => _review == null || _base == null
        ? null
        : (change: OrganizationChange.createProjectRepository, input: {'project': widget.project, 'review': _review!}),
  );
}

/// The machines [view]'s person administers, read from the organization, connected or not.
List<OrganizationHost> hostsAdministeredBy(OrganizationView view) => !view.holdsRoles
    ? const []
    : [
        for (final host in view.hosts)
          if (host.admins.contains(view.me)) host,
      ];

/// Puts [project] on one of the machines this person administers, then follows that machine until it carries the
/// project or says why not. A project just put on a machine waits for a token: once it was taken, the machine is
/// asked to fetch at once.
Future<void> putProjectOnAMachine(
  BuildContext context, {
  required Organization organization,
  required String project,
  HostConnections? connections,
  Future<String?> Function(String host)? onGiveToken,
}) async {
  final view = organization.view;
  if (view == null) return;
  final carrying = CarryingChoice(view, project);
  await showDialog<void>(
    context: context,
    builder: (_) => OrganizationPersonDialog(
      organization,
      people: [for (final host in hostsAdministeredBy(view)) host.name],
      helper: 'A repository is on one machine at a time.',
      title: 'Put $project on a machine',
      personLabel: 'Machine',
      words:
          'Every member comes with the project. Next this follows the machine: it connects, offers to give the '
          'machine your token once if it waits for one, and says when the project is carried or why not. '
          'This can take up to five minutes.',
      confirm: 'Put it on the machine',
      change: OrganizationChange.addProjectToHost,
      below: (_, changed) => CarryChoice(organization: organization, carrying: carrying, changed: changed),
      ready: (_) => carrying.whole || carrying.chosen.isNotEmpty,
      input: (_, machine) => {
        'host': carrying.machine = machine,
        'project': project,
        if (!carrying.whole) 'repositories': carrying.chosen.join(','),
      },
    ),
  );
  await organization.whenIdle;
  // The machine chosen, once what it carries of the project changed: a dialog cancelled or refused changed nothing,
  // and the machine may carry a part already.
  String carried(OrganizationView? view, String machine) {
    final host = view?.hosts.where((each) => each.name == machine).firstOrNull;
    return host == null || !host.projects.contains(project)
        ? ''
        : (host.repositories[project] ?? ['(whole)']).join(',');
  }

  final machine = carrying.machine;
  if (machine == null || carried(organization.view, machine) == carried(view, machine)) return;
  if (connections == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => PlacingProjectDialog(
      project: project,
      host: machine,
      view: organization.view,
      connections: connections,
      onGiveToken: onGiveToken,
    ),
  );
}

/// Asks before [project], or only its [repository], is taken off [machine], and says what goes with it and what
/// stays.
Widget takeProjectOffTheMachine(
  Organization organization, {
  required String project,
  required String machine,
  String? repository,
}) => repository == null
    ? OrganizationConfirmDialog(
        organization,
        title: 'Take $project off $machine?',
        words:
            'Its members can no longer work on it there, once it holds no unpushed work. Its copy there '
            'goes then, with its conversation, where the machine runs its own. The project itself stays '
            'in the organization. This can take up to five minutes.',
        confirm: 'Take it off',
        change: OrganizationChange.removeProjectFromHost,
        input: {'host': machine, 'project': project},
      )
    : OrganizationConfirmDialog(
        organization,
        title: 'Take $repository of $project off $machine?',
        words:
            'Nobody can work in $repository there any more, once it holds no unpushed work; its copy there goes '
            'then. At its next follow the machine also deletes its read key for $repository, and takes that key '
            'off the central forge. The project and its other repositories stay on $machine, and taking off the '
            'last one takes the project off. This can take up to five minutes.',
        confirm: 'Take it off',
        change: OrganizationChange.removeProjectFromHost,
        input: {'host': machine, 'project': project, 'repositories': repository},
      );

/// What of a project is put on a machine: the whole project, or some of its repositories.
class CarryingChoice {
  /// Starts from the whole project where no machine carries any of it, from a choice of repositories otherwise.
  CarryingChoice(OrganizationView view, this.project)
    : elsewhere = {
        for (final host in view.hosts)
          for (final name in host.repositories[project] ?? const <String>[]) name: host.name,
      } {
    whole = elsewhere.isEmpty;
  }

  /// The project's name.
  final String project;

  /// Each repository of it a machine carries already, with that machine: none can go on a second one.
  final Map<String, String> elsewhere;

  /// Whether the whole project is put on the machine.
  late bool whole;

  /// The repositories chosen, where not the whole project.
  final Set<String> chosen = <String>{};

  /// The machine it was asked to go on.
  String? machine;
}

/// Offers the whole project, chosen to begin with, or some of its repositories, read from the project's own
/// repository; one already on a machine is named with it and not offered.
class CarryChoice extends StatefulWidget {
  /// Shows [carrying] and tells [changed] of each choice.
  const CarryChoice({super.key, required this.organization, required this.carrying, required this.changed});

  /// Where the project's repositories are read.
  final Organization organization;

  /// What is chosen.
  final CarryingChoice carrying;

  /// Told of each choice.
  final VoidCallback changed;

  @override
  State<CarryChoice> createState() => _CarryChoiceState();
}

class _CarryChoiceState extends State<CarryChoice> {
  List<String>? _names;
  String? _problem;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    try {
      final project = await widget.organization.source.readProject(widget.carrying.project);
      if (!mounted) return;
      setState(() {
        _names = [for (final repository in project.repositories) repository.name];
        _problem = project.repositoriesProblem;
      });
    } on OrganizationRefused catch (refused) {
      if (mounted) setState(() => _problem = 'Its repositories could not be read: ${refused.words}');
    }
  }

  void _choose(void Function() change) {
    setState(change);
    widget.changed();
  }

  @override
  Widget build(BuildContext context) {
    final carrying = widget.carrying;
    final names = _names;
    return Padding(
      padding: const EdgeInsets.only(top: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: Space.small,
            children: [
              ChoiceChip(
                key: const Key('organization-carry-whole'),
                label: const Text('The whole project'),
                selected: carrying.whole,
                onSelected: carrying.elsewhere.isNotEmpty ? null : (_) => _choose(() => carrying.whole = true),
              ),
              ChoiceChip(
                key: const Key('organization-carry-some'),
                label: const Text('Some of its repositories'),
                selected: !carrying.whole,
                onSelected: (_) => _choose(() => carrying.whole = false),
              ),
            ],
          ),
          if (carrying.elsewhere.isNotEmpty)
            Text(
              'Already on a machine, so the project cannot go on another whole: '
              '${[for (final MapEntry(:key, :value) in carrying.elsewhere.entries) '$key on $value'].join(', ')}.',
            ),
          if (!carrying.whole) ...[
            const SizedBox(height: Space.small),
            if (names == null && _problem == null)
              const Text('Reading its repositories…')
            else if (_problem case final problem?)
              Text(problem)
            else
              Wrap(
                spacing: Space.small,
                runSpacing: Space.small,
                children: [
                  for (final name in names!)
                    if (!carrying.elsewhere.containsKey(name))
                      FilterChip(
                        key: Key('organization-carry-repository-$name'),
                        label: Text(name),
                        selected: carrying.chosen.contains(name),
                        onSelected: (on) =>
                            _choose(() => on ? carrying.chosen.add(name) : carrying.chosen.remove(name)),
                      ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
