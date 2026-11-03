import 'dart:async';

import 'package:flutter/material.dart';

import '../app/organization_source.dart';
import 'tokens.dart';

/// The frame of a dialog that asks the store for one change: its refusal stays in the dialog, in the store's words, and it
/// closes only once the store took the change.
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
    if (widget.invalid?.call() case final words?) {
      setState(() => _refusal = words);
      return;
    }
    final asked = widget.ask();
    if (asked == null) return;
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
  Widget build(BuildContext context) => organization.busy
      ? const LinearProgressIndicator(key: Key('organization-change-running'), semanticsLabel: 'A change is under way')
      : const SizedBox.shrink();
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
  });

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
        ],
      ),
      invalid: () => widget.check?.call(_name.text.trim()),
      ask: () {
        final person = _person;
        final name = _name.text.trim();
        if (person == null || (widget.nameLabel != null && name.isEmpty)) return null;
        return (change: widget.changeFor?.call(person) ?? widget.change, input: widget.input(name, person));
      },
    );
  }
}
