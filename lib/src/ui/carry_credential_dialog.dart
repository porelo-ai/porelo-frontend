import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/credential_carry.dart';

/// Lets a person carry one of this computer's credentials for [provider] to the host [hostName].
///
/// [sources] reads what this computer offers; [carry] carries the one chosen. Neither shows a value: the rows say what
/// each source is, and the carrying passes only ciphertext, porelo to porelo.
Future<void> showCarryCredential(
  BuildContext context, {
  required Provider provider,
  required String hostName,
  required Future<List<CarrySource>> Function() sources,
  required Future<CarryOutcome> Function(CarrySource source, {required bool replace}) carry,
}) => showDialog<void>(
  context: context,
  builder: (_) => CarryCredentialDialog(provider: provider, hostName: hostName, sources: sources, carry: carry),
);

/// The dialog itself: this computer's vault entries and local agents' sign-ins side by side, one picked and carried.
class CarryCredentialDialog extends StatefulWidget {
  /// Constructor taking what it carries for, to where, and how.
  const CarryCredentialDialog({
    required this.provider,
    required this.hostName,
    required this.sources,
    required this.carry,
    super.key,
  });

  /// The provider whose credential goes.
  final Provider provider;

  /// The host it goes to, by name.
  final String hostName;

  /// Reads this computer's sources.
  final Future<List<CarrySource>> Function() sources;

  /// Carries one.
  final Future<CarryOutcome> Function(CarrySource source, {required bool replace}) carry;

  @override
  State<CarryCredentialDialog> createState() => _CarryCredentialDialogState();
}

class _CarryCredentialDialogState extends State<CarryCredentialDialog> {
  late final Future<List<CarrySource>> _sources = widget.sources();
  CarrySource? _chosen;
  bool _carrying = false;
  CarryOutcome? _said;
  String? _failed;

  Future<void> _carry({required bool replace}) async {
    final chosen = _chosen;
    if (chosen == null) return;
    setState(() {
      _carrying = true;
      _failed = null;
    });
    try {
      final said = await widget.carry(chosen, replace: replace);
      if (mounted) setState(() => _said = said);
    } on Object catch (ex) {
      // A call that failed says so; it never leaves the person guessing whether it went.
      if (mounted) setState(() => _failed = 'It could not be carried: $ex');
    } finally {
      if (mounted) setState(() => _carrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final said = _said;
    final stored = said?.stored ?? false;
    return AlertDialog(
      title: Text('Import ${widget.provider.label} from this computer'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<List<CarrySource>>(
          future: _sources,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                "This computer's credentials could not be read: ${snapshot.error}",
                key: const Key('carry-sources-failed'),
                style: TextStyle(color: theme.colorScheme.error),
              );
            }
            final sources = snapshot.data;
            if (sources == null) return const Text('Reading what this computer holds…');
            final vault = sources.whereType<VaultEntrySource>().toList();
            final agents = sources.whereType<AgentSignInSource>().toList();
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'The one you pick goes to the vault of ${widget.hostName}, sealed so that only that host can open '
                    'it. Its value is never shown.',
                    style: theme.textTheme.bodySmall,
                  ),
                  _kind(context, "This computer's porelo vault", vault, 'No entry for this provider.'),
                  _kind(context, "Local agents' own sign-ins", agents, 'No local agent reaches this provider.'),
                  if (said != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        said.words,
                        key: const Key('carry-says'),
                        style: said.stored || said.exists ? null : TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  if (_failed != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _failed!,
                        key: const Key('carry-says'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(stored ? 'Close' : 'Cancel')),
        if (!stored)
          FilledButton(
            key: const Key('carry-it'),
            onPressed: _chosen == null || _carrying ? null : () => _carry(replace: said?.exists ?? false),
            child: Text((said?.exists ?? false) ? 'Replace it on the host' : 'Carry to ${widget.hostName}'),
          ),
      ],
    );
  }

  Widget _kind(BuildContext context, String heading, List<CarrySource> sources, String none) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(heading, style: theme.textTheme.labelLarge),
        ),
        if (sources.isEmpty) Text(none, style: theme.textTheme.bodySmall),
        for (final source in sources)
          ListTile(
            key: Key('carry-source ${source.id}'),
            dense: true,
            enabled: source.whyNot == null && !_carrying,
            selected: _chosen?.id == source.id,
            leading: Icon(_chosen?.id == source.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            title: Text(source.label),
            subtitle: Text(source.whyNot ?? source.facts),
            onTap: () => setState(() {
              _chosen = source;
              // Another source is another carry: what the last one said is not this one's.
              _said = null;
              _failed = null;
            }),
          ),
      ],
    );
  }
}
