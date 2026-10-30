import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/commands.dart';
import '../app/links.dart';
import '../app/registry_pages.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'tokens.dart';

/// Offers scoped operations only when the corresponding backend adapter is supplied.
List<Command> registryItemCommands(
  BuildContext context,
  RegistryPages registry,
  RegistryPageItem item,
  Iterable<RegistryOperation> operations, {
  String? person,
}) => [
  for (final operation in operations)
    if (registry.features.supports(operation))
      registryPageCommand(
        registry: registry,
        target: item.target,
        operation: operation,
        person: person,
        run: () => unawaited(runRegistryAction(context, registry, item, operation, person: person)),
      ),
];

/// Confirms destructive scope and rechecks authorization before publishing.
Future<void> runRegistryAction(
  BuildContext context,
  RegistryPages registry,
  RegistryPageItem item,
  RegistryOperation operation, {
  String? person,
}) async {
  if (registry.unavailable(item.target, operation, person: person) != null) return;
  if ({RegistryOperation.admit, RegistryOperation.addPerson}.contains(operation)) {
    person = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(registryOperationLabel(operation)),
        children: [
          SizedBox(
            width: Sizes.dialogSmall,
            height: Sizes.personPicker,
            child: SingleChildScrollView(
              child: FilteredListSection(
                title: 'Persons',
                storageId: 'person-picker',
                rows: [
                  for (final card in registry.people)
                    if (!item.members.any((member) => member.person.login == card.login))
                      (
                        words: '${card.name} ${card.login}',
                        child: SimpleDialogOption(
                          key: ValueKey('choose-person ${card.login}'),
                          onPressed: () => Navigator.pop(context, card.login),
                          child: Text('${card.name} (${card.login})'),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (person == null || !context.mounted) return;
  }
  const destructive = {
    RegistryOperation.projectLock,
    RegistryOperation.hostLock,
    RegistryOperation.removePerson,
    RegistryOperation.deleteAccount,
    RegistryOperation.takeOffHost,
  };
  if (destructive.contains(operation)) {
    final scope = item.target.project == null
        ? 'server ${item.target.host}'
        : 'project ${item.target.project} on ${item.target.host}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(registryOperationLabel(operation)),
        content: Text(
          '${person == null ? 'This change' : 'Change access for $person'} in $scope? '
          '${operation == RegistryOperation.deleteAccount
              ? 'This permanently deletes their Linux account and home. Nothing undoes this.'
              : operation == RegistryOperation.projectLock || operation == RegistryOperation.removePerson
              ? 'Only this project’s repositories and rooms are affected.'
              : 'This affects their access on this server.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('registry-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  if (registry.unavailable(item.target, operation, person: person) != null) return;
  await registry.change((target: item.target, operation: operation, person: person));
}

/// A verified person list with host and project operations kept in separate scopes.
class RegistryPersons extends StatelessWidget {
  /// Creates a section for one exact host or project admission.
  const RegistryPersons({required this.registry, required this.item, super.key});

  /// The verified registry decisions and separate host confirmations.
  final RegistryPages registry;

  /// The verified admission whose persons are listed.
  final RegistryPageItem? item;

  @override
  Widget build(BuildContext context) {
    final current = item;
    final project = current?.target.project != null;
    final operations = project
        ? [
            RegistryOperation.projectLock,
            RegistryOperation.projectUnlock,
            RegistryOperation.removePerson,
            RegistryOperation.replaceLostKey,
          ]
        : [
            RegistryOperation.hostLock,
            RegistryOperation.hostUnlock,
            RegistryOperation.deleteAccount,
            RegistryOperation.replaceLostKey,
          ];
    final add = current == null || !project
        ? <Command>[]
        : registryItemCommands(context, registry, current, [
            project ? RegistryOperation.addPerson : RegistryOperation.admit,
          ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilteredListSection(
          key: ValueKey('persons ${current?.target}'),
          title: 'Persons',
          storageId: 'persons ${current?.target}',
          collapsible: true,
          actions: [
            for (final command in add)
              Tooltip(
                message: command.unavailable ?? command.label,
                child: TextButton(onPressed: command.available ? command.run : null, child: Text(command.label)),
              ),
          ],
          rows: [
            for (final member in current?.members ?? <RegistryMember>[])
              (
                words: '${member.person.name} ${member.person.login} ${member.role} ${member.state}',
                child: ItemListRow(
                  key: ValueKey('person ${current!.target}/${member.person.login}'),
                  title: member.person.name,
                  subtitle: [
                    member.person.login,
                    member.role,
                    'registry: ${member.state}',
                    'host: ${registry.applied(current.target)?.personStates[member.person.login] ?? 'unknown'}',
                  ].join(' · '),
                  leading: const Icon(Icons.person_outline),
                  onOpen: () => unawaited(_showPerson(context, member.person)),
                  menu: CommandMenu(
                    key: ValueKey('person-menu ${member.person.login}'),
                    tooltip: 'Access for ${member.person.name}',
                    commands: registryItemCommands(context, registry, current, operations, person: member.person.login),
                  ),
                ),
              ),
          ],
        ),
        if (current == null) const Text('Verified access state has not been supplied.'),
        if (current != null)
          for (final admin in current.administrators) AdministratorContact(person: admin),
        if (registry.problem case final problem?) Text(problem),
      ],
    );
  }

  Future<void> _showPerson(BuildContext context, RegistryPerson person) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(person.name),
      content: AdministratorContact(person: person),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}

/// Names who may act and offers contact only when a card supplied a valid email address.
class AdministratorContact extends StatelessWidget {
  /// Creates the contact line for an administrator's verified card.
  const AdministratorContact({required this.person, super.key});

  /// The verified card for this row.
  final RegistryPerson person;

  @override
  Widget build(BuildContext context) {
    final email = person.contactEmail;
    return Wrap(
      spacing: Space.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${person.name} (${person.login})${email == null ? ': no email supplied' : ': $email'}'),
        if (email != null) ...[
          TextButton(
            onPressed: () => unawaited(openLink(Uri(scheme: 'mailto', path: email))),
            child: const Text('Write'),
          ),
          TextButton(
            onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: email))),
            child: const Text('Copy'),
          ),
        ],
      ],
    );
  }
}
