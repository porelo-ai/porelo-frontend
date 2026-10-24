import 'dart:async';

import 'package:flutter/material.dart';

import 'package:porelo_host/porelo_host.dart' show forgeAddress;

import '../app/host_session.dart';
import '../app/machines.dart';
import '../app/forge_connection.dart';
import '../app/links.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// The rights a token needs, said once for every place that asks for one.
String tokenRightsWords(String forge) =>
    'Enter your own $forge token in the terminal, without echo. It needs Contents (read and write) '
    'to update machine-signers. This computer keeps it in the system secret store for the forge API. '
    'Each machine keeps your token in its vault for git over https.';

/// Where a person makes a token at [address].
Uri tokenPage(String address) => Uri.parse('https://$address/settings/personal-access-tokens/new');

/// Opens the forges set up on this computer. [usedBy] answers, for an entry, the repositories of
/// the projects the watched machines follow there, before their API access here is forgotten.
Future<void> showForges(
  BuildContext context,
  ForgeConnection forges, {
  List<String> Function(ForgeEntry entry)? usedBy,
}) async {
  // Read again each time: a token kept before the list existed, or another window's change, shows.
  unawaited(forges.readList());
  await showDialog<void>(
    context: context,
    builder: (_) => ForgesDialog(forges: forges, usedBy: usedBy),
  );
}

/// Every forge set up here: added, renamed, given a new token, or removed.
class ForgesDialog extends StatefulWidget {
  /// Constructor taking the forges.
  const ForgesDialog({required this.forges, this.usedBy, super.key});

  /// The forges set up here, and the one being looked at.
  final ForgeConnection forges;

  /// The projects a forge's repositories are in, to say before it is removed.
  final List<String> Function(ForgeEntry entry)? usedBy;

  @override
  State<ForgesDialog> createState() => _ForgesDialogState();
}

class _ForgesDialogState extends State<ForgesDialog> {
  /// The entry being edited, or null; [_adding] while a new one is set up.
  ForgeEntry? _editing;
  bool _adding = false;
  String? _said;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.forges,
    builder: (context, _) {
      final forges = widget.forges;
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        key: const Key('forges-dialog'),
        title: const Text('Your forges'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'The places your repositories are, each with the token that reaches them. Several of one '
                  'kind are fine: name them apart, “GitHub private” and “GitHub work”.',
                  style: text.bodySmall,
                ),
                if (forges.problem != null)
                  Text(
                    forges.problem!,
                    key: const Key('forges-problem'),
                    style: TextStyle(color: scheme.error),
                  ),
                if (_said != null) Text(_said!, key: const Key('forges-said')),
                if (forges.loaded && forges.entries.isEmpty && !_adding)
                  const Text('None yet.', key: Key('forges-none')),
                for (final entry in forges.entries)
                  if (_editing?.id == entry.id)
                    ForgeForm(
                      key: ValueKey<String>('forge-edit ${entry.id}'),
                      forges: forges,
                      editing: entry,
                      onDone: (said) => setState(() {
                        _editing = null;
                        _said = said;
                      }),
                    )
                  else
                    ListTile(
                      key: ValueKey<String>('forge ${entry.name}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.name),
                      subtitle: Text(
                        <String>[
                          entry.kindWords,
                          entry.address,
                          if (forges.current?.id == entry.id && forges.account != null) 'as ${forges.account!.login}',
                        ].join(' · '),
                      ),
                      trailing: Wrap(
                        spacing: Space.tight,
                        children: <Widget>[
                          TextButton(
                            key: ValueKey<String>('forge-change ${entry.name}'),
                            onPressed: forges.busy ? null : () => setState(() => _editing = entry),
                            child: const Text('Change'),
                          ),
                          TextButton(
                            key: ValueKey<String>('forge-remove ${entry.name}'),
                            onPressed: forges.busy ? null : () => unawaited(_remove(context, entry)),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                if (_adding)
                  ForgeForm(
                    key: const Key('forge-add-form'),
                    forges: forges,
                    onDone: (said) => setState(() {
                      _adding = false;
                      _said = said;
                    }),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (!_adding)
            TextButton(
              key: const Key('forge-add'),
              onPressed: forges.busy ? null : () => setState(() => _adding = true),
              child: const Text('Add a forge'),
            ),
          TextButton(
            key: const Key('forges-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );

  Future<void> _remove(BuildContext context, ForgeEntry entry) async {
    final said = await removeForge(context, widget.forges, entry, widget.usedBy?.call(entry) ?? const <String>[]);
    if (said != null && mounted) setState(() => _said = said);
  }
}

/// Removes the local API token after showing which projects [used] it. Machine vaults keep their tokens.
Future<String?> removeForge(BuildContext context, ForgeConnection forges, ForgeEntry entry, List<String> used) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('forge-remove-dialog'),
      title: Text('Remove ${entry.name}?'),
      content: SizedBox(
        width: Sizes.dialogMedium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Its token is taken out of this computer’s keychain. Nothing at ${entry.address} '
              'changes: the token stays valid there until you revoke it.',
            ),
            if (used.isNotEmpty) ...<Widget>[
              const SizedBox(height: Space.small),
              Text(
                'Projects your machines follow use it: ${used.join(', ')}. Their vault tokens stay on those machines.',
                key: const Key('forge-remove-used'),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Keep it')),
        FilledButton(
          key: const Key('forge-remove-confirm'),
          onPressed: () => Navigator.of(context).pop('remove'),
          child: const Text('Remove it'),
        ),
      ],
    ),
  );
  if (choice == null) return null;
  await forges.remove(entry);
  return forges.problem ?? '${entry.name} is no longer set up here.';
}

/// Setting a forge up or changing it, with the token entered only at the helper's terminal prompt.
class ForgeForm extends StatefulWidget {
  /// Constructor taking the forges and, to change one, the entry.
  const ForgeForm({required this.forges, required this.onDone, this.editing, this.cancels = true, super.key});

  /// The forges set up here, and the one being looked at.
  final ForgeConnection forges;

  /// The forge being changed, or null for a new one.
  final ForgeEntry? editing;

  /// Called with what happened, in words, once it was kept.
  final void Function(String said) onDone;

  /// Whether it offers *Cancel*: not where it is the only thing shown, with nothing to go back to.
  final bool cancels;

  @override
  State<ForgeForm> createState() => _ForgeFormState();
}

class _ForgeFormState extends State<ForgeForm> {
  late final TextEditingController _name = TextEditingController(text: widget.editing?.name ?? 'GitHub');
  late final TextEditingController _address = TextEditingController(text: widget.editing?.address ?? 'github.com');

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final forges = widget.forges;
    final editing = widget.editing;
    final String address;
    try {
      address = forgeAddress(editing?.address ?? _address.text);
    } on FormatException catch (error) {
      setState(() => _problem = error.message);
      return;
    }
    int? exit;
    await runInATerminal(
      context,
      title: 'Connect $address',
      explanation: 'Enter your own token at the terminal prompt. It is not echoed and goes into this computer’s system secret store.',
      machine: Machine.local(),
      command: <String>[poreloHost(), 'key', 'set', address],
      shownCommand: 'porelo-host key set $address',
      open: forges.openTerminal,
      onExit: (code) => exit = code,
      stillWorking: 'Waiting for the token in this terminal on this computer.',
    );
    if (!mounted || exit != 0) return;
    try {
      if (!await forges.hasToken(address)) {
        if (mounted) setState(() => _problem = 'No token is kept for $address. Enter it in the terminal.');
        return;
      }
      if (editing == null) {
        final made = await forges.add(name: _name.text, address: address);
        if (made != null && mounted) {
          widget.onDone(
            '${made.name} is set up: logged in as ${forges.account?.login ?? '?'}, it reaches ${forges.repositories?.length ?? 0} repositories.',
          );
        }
      } else {
        await forges.edit(editing, name: _name.text);
        if (forges.problem == null && mounted) widget.onDone('${_name.text.trim()} has its token from the terminal.');
      }
    } on Exception {
      if (mounted) setState(() => _problem = 'The system secret store could not be read.');
    }
  }

  String? _problem;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.forges,
    builder: (context, _) {
      final editing = widget.editing;
      final text = Theme.of(context).textTheme;
      final address = _address.text.trim().isEmpty ? 'github.com' : _address.text.trim();
      return Container(
        margin: const EdgeInsets.symmetric(vertical: Space.small),
        padding: const EdgeInsets.all(Space.small),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(editing == null ? 'A GitHub to work with' : 'Change ${editing.name}', style: text.titleSmall),
            TextField(
              key: const Key('forge-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'What you call it'),
            ),
            if (editing == null)
              TextField(
                key: const Key('forge-address'),
                controller: _address,
                decoration: const InputDecoration(labelText: 'Where it is: github.com, or your own GitHub’s host'),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: Space.tight),
            Text(tokenRightsWords('GitHub'), style: text.bodySmall),
            if (_problem != null) Text(_problem!, key: const Key('forge-form-problem')),
            TextButton(
              key: const Key('forge-token-page'),
              onPressed: () {
                try {
                  unawaited(openLink(tokenPage(forgeAddress(address))));
                } on FormatException catch (error) {
                  setState(() => _problem = error.message);
                }
              },
              child: Text('Make a token at $address'),
            ),
            Wrap(
              spacing: Space.tight,
              children: <Widget>[
                FilledButton(
                  key: const Key('forge-connect'),
                  onPressed: widget.forges.busy ? null : () => unawaited(_save()),
                  child: Text(editing == null ? 'Connect it' : 'Keep the change'),
                ),
                if (widget.cancels)
                  TextButton(
                    key: const Key('forge-cancel'),
                    onPressed: () => widget.onDone(''),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
