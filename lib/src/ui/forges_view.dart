import 'dart:async';

import 'package:flutter/material.dart';

import '../app/forge.dart';
import '../app/forge_connection.dart';
import '../app/links.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// The rights a token needs, said once for every place that asks for one.
String tokenRightsWords(String forge) =>
    'It needs two rights on each repository you want to work on: Contents (read and write), to add a '
    'machine’s line to the project’s machine-signers, and Administration (read and write), because $forge keeps the keys it '
    'gives a machine there and has no narrower right for them. The token stays in this computer’s '
    'keychain and is sent to $forge only, never to a machine.';

/// Where a person makes a token at [address].
Uri tokenPage(String address) => Uri.parse('https://$address/settings/personal-access-tokens/new');

/// Opens the forges set up on this computer. [usedBy] answers, for an entry, the repositories of
/// the projects the watched machines follow there: what removing it would leave without a way to
/// take their keys off again.
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

/// Removes [entry] once the person agreed, saying first what [used] it and offering to take the
/// machines' keys off there while it still can. Answers what happened, or null where nothing did.
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
                'Projects your machines follow use it: ${used.join(', ')}. Without it, the keys their '
                'machines were given there cannot be removed from here any more.',
                key: const Key('forge-remove-used'),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Keep it')),
        if (used.isNotEmpty)
          TextButton(
            key: const Key('forge-remove-with-keys'),
            onPressed: () => Navigator.of(context).pop('keys'),
            child: const Text('Remove the machines’ keys there first'),
          ),
        FilledButton(
          key: const Key('forge-remove-confirm'),
          onPressed: () => Navigator.of(context).pop('remove'),
          child: const Text('Remove it'),
        ),
      ],
    ),
  );
  if (choice == null) return null;
  var removed = '';
  if (choice == 'keys') {
    removed = await _removeKeys(forges, entry, used);
    if (forges.problem != null) return removed;
  }
  await forges.remove(entry);
  return '${entry.name} is no longer set up here.${removed.isEmpty ? '' : ' $removed'}';
}

/// Takes every key a Porelo machine was given off [repositories] at [entry]'s forge.
Future<String> _removeKeys(ForgeConnection forges, ForgeEntry entry, List<String> repositories) async {
  final reached = await forges.reach(entry);
  if (reached == null) return 'No token is kept for ${entry.name}, so no key was removed.';
  var removed = 0;
  try {
    for (final repository in repositories) {
      for (final key in await reached.forge.deployKeys(repository)) {
        if (!key.isPorelos) continue;
        await reached.forge.removeDeployKey(repository, key.id);
        removed++;
      }
    }
  } on ForgeRefused catch (refused) {
    forges.problem = refused.words;
  }
  return removed == 0 ? 'No machine’s key was there.' : 'Removed $removed machine key${removed == 1 ? '' : 's'} there.';
}

/// Setting a forge up, or changing one: its name, where it is, and its token, which is kept only
/// once the forge accepted it. The kind of an entry never changes.
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
  final TextEditingController _token = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    // What was typed is not kept past the form; the keychain has it once it was accepted.
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final forges = widget.forges;
    final editing = widget.editing;
    if (editing == null) {
      final made = await forges.add(name: _name.text, address: _address.text, token: _token.text);
      if (made != null && mounted) {
        widget.onDone(
          '${made.name} is set up: logged in as ${forges.account?.login ?? '?'}, '
          'it reaches ${forges.repositories?.length ?? 0} repositories.',
        );
      }
      return;
    }
    await forges.edit(editing, name: _name.text, token: _token.text);
    if (forges.problem == null && mounted) {
      widget.onDone(
        _token.text.trim().isEmpty ? '${_name.text.trim()} is renamed.' : '${_name.text.trim()} has its new token.',
      );
    }
  }

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
            TextField(
              key: const Key('forge-token'),
              controller: _token,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: editing == null ? 'Personal access token' : 'A new token, only to replace it',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.tight),
            Text(tokenRightsWords('GitHub'), style: text.bodySmall),
            TextButton(
              key: const Key('forge-token-page'),
              onPressed: () => unawaited(openLink(tokenPage(address))),
              child: Text('Make a token at $address'),
            ),
            Wrap(
              spacing: Space.tight,
              children: <Widget>[
                FilledButton(
                  key: const Key('forge-connect'),
                  onPressed: widget.forges.busy || (editing == null && _token.text.trim().isEmpty)
                      ? null
                      : () => unawaited(_save()),
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
