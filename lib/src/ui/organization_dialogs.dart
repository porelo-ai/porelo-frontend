import 'dart:async';

import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/organization_source.dart';
import 'choice_field.dart';
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'organization_token_words.dart';
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
    this.waitsForItsWrite = false,
  });

  /// The organization the change is asked of.
  final Organization organization;

  /// Whether a list change stays open until it is answered, too, and closes saying it was taken: where what
  /// follows the change goes on from this dialog, a row alone would not say it happened.
  final bool waitsForItsWrite;

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

  // A change being written: what it was asked with stays as it was until it is answered.
  bool _writing = false;
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
    if (!widget.waitsForItsWrite &&
        widget.organization.view != null &&
        OrganizationRowChange.target(asked.change, asked.input) != null) {
      unawaited(widget.organization.write(asked.change, asked.input, base: widget.base, provisional: true));
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _asking = true;
      _writing = true;
      _refusal = null;
    });
    final route = ModalRoute.of(context);
    final refusal = await widget.organization.write(asked.change, asked.input, base: widget.base);
    if (!mounted) return;
    if (refusal == null) {
      // The answer closes this dialog, never whatever came to lie over it.
      if (route != null && !route.isCurrent) Navigator.of(context).popUntil((each) => each == route);
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _asking = false;
        _writing = false;
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
              AbsorbPointer(
                absorbing: _writing,
                child: ExcludeFocus(
                  excluding: _writing,
                  child: widget.body(
                    context,
                    () => setState(() {
                      _refusal = null;
                      _byHand = null;
                      _edits++;
                    }),
                  ),
                ),
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
                OrganizationVaultShut(widget.organization, key: ValueKey(refusal)),
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

/// Under a refusal: where this computer's Porelo-Vault is shut, says so, with the button that opens it. Porelo reads the
/// person's forge token from it, and a refusal cannot tell a shut vault from a token not set. Nothing where it is open
/// or its state cannot be read.
class OrganizationVaultShut extends StatefulWidget {
  /// Asks [organization]'s hooks whether this computer's vault is shut.
  const OrganizationVaultShut(this.organization, {super.key});

  /// The organization whose hooks tell and open the vault.
  final Organization organization;

  @override
  State<OrganizationVaultShut> createState() => _OrganizationVaultShutState();
}

class _OrganizationVaultShutState extends State<OrganizationVaultShut> {
  bool _shut = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    unawaited(_ask());
  }

  Future<void> _ask() async {
    bool? shut;
    try {
      shut = await widget.organization.thisComputersVaultShut?.call();
    } catch (_) {
      shut = null;
    }
    if (mounted) setState(() => _shut = shut ?? false);
  }

  Future<void> _open() async {
    final open = widget.organization.openThisComputersVault;
    if (open == null) return;
    setState(() => _opening = true);
    try {
      await open();
    } catch (_) {
      // The vault is asked again below: what it says then is the word, not why the opening failed.
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (mounted) await _ask();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shut) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.small,
        children: [
          const Text(
            "This computer's Porelo-Vault is shut, and Porelo reads your forge token from it. Open it, then try again.",
            key: Key('organization-vault-shut'),
          ),
          if (widget.organization.openThisComputersVault != null)
            OutlinedButton(
              key: const Key('organization-open-vault'),
              onPressed: _opening ? null : () => unawaited(_open()),
              child: const Text("Open this computer's Porelo-Vault"),
            ),
        ],
      ),
    );
  }
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
      key: section.key,
      title: section.title,
      storageId: section.storageId,
      leaf: section.leaf,
      read: section.read,
      titleInAppBar: section.titleInAppBar,
      path: section.path,
      pathKeys: section.pathKeys,
      titleKey: section.titleKey,
      subtitle: section.subtitle,
      explanation: section.explanation,
      busy: section.busy,
      problem: section.problem,
      onRetry: section.onRetry,
      readAt: section.readAt,
      beforeRows: section.beforeRows,
      search: section.search,
      searchHint: section.searchHint,
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
  const OrganizationPendingRow(
    this.organization,
    this.change, {
    this.name,
    this.onReview,
    this.unconfirmed = false,
    super.key,
  });

  /// The organization keeping the request.
  final Organization organization;

  /// The provisional request.
  final OrganizationRowChange change;

  /// The containing row's name where it stands for a nested list change.
  final String? name;

  /// Lets the person read the project's current state before another attempt.
  final VoidCallback? onReview;

  /// Whether the project's page shows a read of it not yet confirmed: an answered refusal waits for its read.
  final bool unconfirmed;

  @override
  Widget build(BuildContext context) {
    final target = OrganizationRowChange.target(change.change, change.input)!;
    return ListTile(
      key: ValueKey('organization-pending ${target.scope} ${target.name}'),
      leading: Icon(change.running ? Icons.hourglass_top : Icons.error_outline),
      title: Text(name ?? target.name),
      subtitle: change.running
          ? Text('${target.doing} Any failure will appear in this row.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(change.refusal!), OrganizationVaultShut(organization)],
            ),
      trailing: change.running
          ? null
          : CommandMenu(
              tooltip: 'What can be done with ${target.name}',
              commands: [
                organizationCommand(
                  id: 'retryChange/${target.scope}/${target.name}',
                  label: 'Try again',
                  unavailable:
                      organization.whyNoRetry(change) ??
                      (unconfirmed && !change.unanswered ? 'Review the project before asking again.' : null),
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
    this.waitsForItsWrite = false,
  });

  /// Whether the dialog stays open until its change is answered, and closes saying it was taken.
  final bool waitsForItsWrite;

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
      waitsForItsWrite: widget.waitsForItsWrite,
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
/// asked to fetch at once. Asked again while a machine of this person's waits for the token for it, it follows that
/// placing at once where nothing of the project is left to put on, and says so beside the choice otherwise.
Future<void> putProjectOnAMachine(
  BuildContext context, {
  required Organization organization,
  required String project,
  HostConnections? connections,
  GiveHostToken? onGiveToken,
}) async {
  final view = organization.view;
  if (view == null) return;
  final mine = hostsAdministeredBy(view);
  final waiting = [
    for (final wait in projectWaits(view, connections, project))
      if (mine.any((host) => host.name == wait.host)) wait,
  ];
  if (waiting.isNotEmpty && view.carriedWhole(project)) {
    if (connections == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => PlacingProjectDialog(
        project: project,
        host: waiting.first.host,
        view: view,
        connections: connections,
        onGiveToken: onGiveToken,
      ),
    );
    return;
  }
  final forge = organizationForgeName(view);
  final carrying = CarryingChoice(view, project);
  // Open until the store answers: a refusal is said beside the choice, and a placing it took goes on below.
  final taken = await showDialog<bool>(
    context: context,
    builder: (_) => OrganizationPersonDialog(
      organization,
      waitsForItsWrite: true,
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
      below: (_, changed) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // What the machine says now: a token given from here, or anywhere, takes its wait away.
          if (connections != null)
            ListenableBuilder(
              listenable: connections,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final wait in projectWaits(view, connections, project))
                    if (mine.any((host) => host.name == wait.host)) ...[
                      Text('Its placing on ${wait.host} ${waitingWords(wait.said, forge)}.'),
                      if (wait.said.waitsForToken && onGiveToken != null)
                        TextButton(
                          key: ValueKey('organization-carry-give-token ${wait.host}'),
                          onPressed: () => unawaited(onGiveToken(wait.host)),
                          child: Text('Give ${wait.host} my $forge token…'),
                        ),
                    ],
                ],
              ),
            ),
          CarryChoice(organization: organization, carrying: carrying, changed: changed),
        ],
      ),
      ready: (_) => carrying.whole || carrying.chosen.isNotEmpty,
      input: (_, machine) => {
        'host': carrying.machine = machine,
        'project': project,
        if (!carrying.whole) 'repositories': carrying.chosen.join(','),
      },
    ),
  );
  await organization.whenIdle;
  // A placing taken is followed though the organization's read does not show it yet; a dialog cancelled changed
  // nothing, and a refused one said why where it was asked.
  final machine = carrying.machine;
  if (taken != true || machine == null) return;
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

/// Offers the whole project or searchable repository choices, with carried repositories disabled.
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
  List<ProjectRepository>? _repositories;
  final _search = TextEditingController();
  String? _problem;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    try {
      final project = await widget.organization.source.readProject(widget.carrying.project);
      if (!mounted) return;
      setState(() {
        _repositories = project.repositories;
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

  String? _fullName(ProjectRepository repository) {
    final central = repository.central?.trim();
    final address = (central == null || central.isEmpty ? repository.address?.trim() : central) ?? '';
    if (address.isEmpty) return null;
    final name = OrganizationView.endOfAddress(address);
    return name.isEmpty ? null : name;
  }

  Widget _repositoryRow(ProjectRepository repository) {
    final carrying = widget.carrying;
    final key = repository.name;
    final fullName = _fullName(repository);
    final machine = carrying.elsewhere[key];
    return CheckboxListTile(
      key: Key('organization-carry-repository-$key'),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Wrap(
        spacing: Space.small,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(fullName ?? key),
          if (fullName != null && fullName != key) Text(key, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      subtitle: machine == null ? null : Text('Already on $machine.'),
      value: carrying.chosen.contains(key),
      onChanged: machine == null
          ? (on) => _choose(() => on == true ? carrying.chosen.add(key) : carrying.chosen.remove(key))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final carrying = widget.carrying;
    final repositories = _repositories;
    final search = _search.text.trim().toLowerCase();
    final shown = [
      for (final repository in repositories ?? const <ProjectRepository>[])
        if (repository.name.toLowerCase().contains(search) ||
            (_fullName(repository)?.toLowerCase().contains(search) ?? false))
          repository,
    ];
    final available = [
      for (final repository in shown)
        if (!carrying.elsewhere.containsKey(repository.name)) repository.name,
    ];
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
            const Text('The whole project cannot go on this machine: some of its repositories are on another.'),
          if (!carrying.whole) ...[
            const SizedBox(height: Space.small),
            if (repositories == null && _problem == null)
              const Text('Reading its repositories…')
            else if (_problem case final problem?)
              Text(problem)
            else ...[
              TextField(
                key: const Key('organization-carry-search'),
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Search repositories',
                  hintText: 'Full name or project key',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.small),
              Wrap(
                spacing: Space.small,
                children: [
                  TextButton(
                    key: const Key('organization-carry-all'),
                    onPressed: available.isEmpty ? null : () => _choose(() => carrying.chosen.addAll(available)),
                    child: const Text('All'),
                  ),
                  TextButton(
                    key: const Key('organization-carry-none'),
                    onPressed: available.isEmpty ? null : () => _choose(() => carrying.chosen.removeAll(available)),
                    child: const Text('None'),
                  ),
                ],
              ),
              if (carrying.chosen.isEmpty && repositories!.isNotEmpty) const Text('Choose at least one repository.'),
              if (shown.isEmpty)
                Text(repositories!.isEmpty ? 'This project has no repositories.' : 'No repositories match your search.')
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: Sizes.repositoryPicker),
                  child: ListView.builder(
                    primary: false,
                    shrinkWrap: true,
                    itemCount: shown.length,
                    itemBuilder: (_, index) => _repositoryRow(shown[index]),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
