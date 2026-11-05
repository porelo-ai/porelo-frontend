import 'dart:async';

import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/organization_source.dart';
import 'command_menu.dart';
import 'filtered_list_section.dart';
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
              widget.body(context, () => setState(() => _refusal = null)),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _asking ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
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
          DropdownButtonFormField<String>(
            key: const Key('organization-person'),
            isExpanded: true,
            initialValue: _person,
            decoration: InputDecoration(labelText: widget.personLabel, helperText: widget.helper),
            items: [
              for (final login in widget.people ?? [for (final person in view.holdingRoles) person.login])
                DropdownMenuItem(value: login, child: Text(login == view.me ? '$login (you)' : login)),
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
