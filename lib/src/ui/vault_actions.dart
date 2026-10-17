import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/vault.dart';
import '../app/vault_devices.dart';
import 'choice_field.dart';
import 'tokens.dart';

/// The vault's controls in the machine's title, beside the emergency stop: a lock that shows
/// whether the store is open and opens or shuts it. **Enrolling this device is in the machine's
/// menu**, not here: beside the lock it read as a task left undone on every machine.
class VaultButtons extends StatelessWidget {
  /// Constructor taking the vault and what pressing each does.
  const VaultButtons({
    required this.vault,
    required this.onLock,
    this.onOpenWithThePassphrase,
    this.onMakeIt,
    super.key,
  });

  /// What the store and its devices say.
  final Vault vault;

  /// Opens or shuts the store; null while the machine is not answering.
  final VoidCallback? onLock;

  /// Opens the store by its passphrase in a terminal on the machine; null where nothing here can
  /// reach that machine's `porelo`, or while it is not answering.
  final VoidCallback? onOpenWithThePassphrase;

  /// Makes the store in a terminal on the machine, for a machine that has none; null where nothing
  /// here can reach that machine's `porelo`, or while it is not answering.
  final VoidCallback? onMakeIt;

  @override
  Widget build(BuildContext context) {
    final open = vault.state?.readable ?? false;
    // A shut store this device cannot open is still openable — by its passphrase — so the lock is
    // never a dead button while that way exists: it is the only way to a device being enrolled.
    final byPassphrase = !vault.lockWorks && !open ? onOpenWithThePassphrase : null;
    // No store at all is the first thing a fresh machine has, and making one is where it all starts.
    final make = vault.missing ? onMakeIt : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Tooltip(
          message: make != null
              ? 'There is no vault here yet. Make one, with a passphrase, in a terminal '
                    'on the machine'
              : byPassphrase != null
              ? 'Shut. Open it with its passphrase, in a terminal on the machine'
              : vault.lockSays,
          child: IconButton(
            key: const Key('vault-act'),
            onPressed: make ?? (vault.lockWorks ? onLock : byPassphrase),
            // No store answers readable, and an open lock over nothing would claim one is open.
            icon: Icon(
              vault.missing
                  ? Icons.enhanced_encryption_outlined
                  : open
                  ? Icons.lock_open_outlined
                  : Icons.lock_outline,
              size: Sizes.rowIcon,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

/// Asks, does it, then says what happened **in the same dialog**, like the emergency stop: an
/// answer shown somewhere else is an answer nobody saw.
abstract class _ActState<T extends StatefulWidget> extends State<T> {
  String? _answer;
  bool _doing = false;

  String get title;
  String get confirm;
  bool get ready => true;
  Widget ask(BuildContext context);
  Future<void> doIt();
  String answer();

  Future<void> _go() async {
    setState(() => _doing = true);
    await doIt();
    if (!mounted) return;
    final said = answer();
    setState(() {
      _doing = false;
      _answer = said.isEmpty ? 'Done.' : said;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: Sizes.dialogNarrow,
      child: _answer != null ? Text(_answer!, key: const Key('vault-answer')) : ask(context),
    ),
    actions: _answer != null
        ? <Widget>[
            FilledButton(
              key: const Key('vault-done'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ]
        : <Widget>[
            TextButton(onPressed: _doing ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              key: const Key('vault-confirm'),
              onPressed: ready && !_doing ? _go : null,
              child: Text(confirm),
            ),
          ],
  );
}

/// Names this device and enrolls it, saying **before** what its key is kept in.
class EnrollDialog extends StatefulWidget {
  /// Constructor taking how this device keeps its key, what enrolling does and what it said.
  const EnrollDialog({
    required this.storage,
    required this.onEnroll,
    required this.answer,
    this.suggested = '',
    super.key,
  });

  /// How this device keeps its key.
  final KeyslotStorage storage;

  /// Enrolls it under a name.
  final Future<void> Function(String name) onEnroll;

  /// What enrolling said.
  final String Function() answer;

  /// The name offered, usually the host's.
  final String suggested;

  @override
  State<EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends _ActState<EnrollDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.suggested);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  String get title => 'Enroll this device';

  @override
  String get confirm => 'Enroll';

  @override
  bool get ready => _name.text.trim().isNotEmpty;

  @override
  Future<void> doIt() => widget.onEnroll(_name.text.trim());

  @override
  String answer() => widget.answer();

  @override
  Widget ask(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      TextField(
        key: const Key('device-name'),
        controller: _name,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'What to call it'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Space.normal),
      Text('Its key: ${storageWords(widget.storage)}', key: const Key('enroll-storage')),
    ],
  );
}

/// How long an unlock lasts, including not bounding it.
enum _For {
  quarterHour(15, 'for 15 minutes'),
  hour(60, 'for an hour'),
  workday(480, 'for 8 hours'),
  untilShut(null, 'until it is shut');

  const _For(this.minutes, this.words);

  final int? minutes;
  final String words;
}

/// Opens the store with this device's key. **Nothing is chosen for the person** — a bound that
/// crept in as a default would decide how often they are asked, and so would its absence.
class OpenDialog extends StatefulWidget {
  /// Constructor taking what opening does and what it said.
  const OpenDialog({required this.onOpen, required this.answer, super.key});

  /// Opens it for so many minutes, or until it is shut when null.
  final Future<void> Function(int? minutes) onOpen;

  /// What opening said.
  final String Function() answer;

  @override
  State<OpenDialog> createState() => _OpenDialogState();
}

class _OpenDialogState extends _ActState<OpenDialog> {
  _For? _chosen;

  @override
  String get title => 'Open the vault';

  @override
  String get confirm => 'Open it';

  @override
  bool get ready => _chosen != null;

  @override
  Future<void> doIt() => widget.onOpen(_chosen!.minutes);

  @override
  String answer() => widget.answer();

  @override
  Widget ask(BuildContext context) => ChoiceField<_For>(
    id: 'open-for',
    label: 'For how long',
    value: _chosen,
    onChanged: (chosen) => setState(() => _chosen = chosen),
    choices: <Choice<_For>>[for (final each in _For.values) Choice(each, each.words, id: 'open-${each.name}')],
  );
}

/// Shuts the store, and then says what locking could not reach.
class ShutDialog extends StatefulWidget {
  /// Constructor taking what shutting does and what it said.
  const ShutDialog({required this.onShut, required this.answer, super.key});

  /// Shuts it.
  final Future<void> Function() onShut;

  /// What shutting said.
  final String Function() answer;

  @override
  State<ShutDialog> createState() => _ShutDialogState();
}

class _ShutDialogState extends _ActState<ShutDialog> {
  @override
  String get title => 'Shut the vault';

  @override
  String get confirm => 'Shut it';

  @override
  Future<void> doIt() => widget.onShut();

  @override
  String answer() => widget.answer();

  @override
  Widget ask(BuildContext context) => const Text('Work that needs a credential cannot start until it is opened again.');
}
