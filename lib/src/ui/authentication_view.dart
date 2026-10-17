import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';

import '../app/authentication.dart';
import 'panes.dart';
import 'tokens.dart';

/// Which providers this machine has, and where a credential for each belongs.
///
/// **Nothing here takes a secret, and the screen says where instead of leaving a blank field.**
/// The person reading it holds an ssh connection to that machine already — that is why this window
/// can see the socket at all — so what is shown is the command, ready to copy.
class AuthenticationView extends StatelessWidget {
  /// Constructor taking what the machine said and what can be done.
  const AuthenticationView({
    required this.authentication,
    required this.onImport,
    required this.onClose,
    super.key,
  });

  /// What the machine has.
  final Authentication authentication;

  /// Imports what an agent already holds there. No secret crosses doing it.
  final void Function(String? agent) onImport;

  /// Closes the view.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        PaneHeader(
          title: 'Providers on this machine',
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close (Esc)',
            onPressed: onClose,
          ),
        ),
        if (authentication.problem != null)
          Container(
            width: double.infinity,
            color: scheme.errorContainer,
            padding: const EdgeInsets.all(Space.normal),
            child: Text(authentication.problem!, key: const Key('providers-problem')),
          ),
        if (authentication.imported != null)
          Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(Space.normal),
            // Never the value — the length is how somebody sees it worked without the
            // confirmation becoming the place the secret appears.
            child: Text(authentication.importWords, key: const Key('import-says')),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Space.small),
            children: <Widget>[
              if (authentication.busy && authentication.answer == null)
                const Padding(
                  padding: EdgeInsets.all(Space.normal),
                  child: Text('Asking the machine…'),
                ),
              if (!authentication.readable && authentication.answer != null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                      Space.normal, 0, Space.normal, Space.small),
                  child: Text(
                    'The vault is shut, so nothing here can say which of these are '
                    'authenticated. That is not the same as none of them being.',
                    key: Key('shut-so-cannot-say'),
                  ),
                ),
              for (final provider in authentication.providers)
                _ProviderRow(
                  provider: provider,
                  readable: authentication.readable,
                  onImport: () => onImport(provider.name),
                ),
              if (authentication.answer != null) ...<Widget>[
                const SizedBox(height: Space.wide),
                Padding(
                  padding: const EdgeInsets.all(Space.normal),
                  child: Text(
                    'Nothing here asks for a secret. A credential is typed at the machine, in '
                    'the terminal half of the connection this window already uses to reach it.',
                    key: const Key('typed-at-the-machine'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One provider, with where its credential belongs.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.readable,
    required this.onImport,
  });

  final Provider provider;
  final bool readable;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      leading: Icon(
        // **Only beside a readable store.** A shut one says nothing about whether a credential is
        // there, and a cross would be a claim nobody made.
        !readable
            ? Icons.help_outline
            : provider.authenticated
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
        size: Sizes.mark,
        color: !readable
            ? scheme.onSurfaceVariant
            : provider.authenticated
                ? scheme.primary
                : scheme.outline,
      ),
      title: Text(provider.label.isEmpty ? provider.name : provider.label,
          key: const Key('provider')),
      subtitle: Text(!readable
          ? '${provider.name} · cannot say while the vault is shut'
          : provider.authenticated
              ? '${provider.name} · authenticated'
              : '${provider.name} · not authenticated'),
      children: <Widget>[
        _Field(name: 'Reaches', value: provider.upstream),
        if (provider.dialects.isNotEmpty)
          _Field(name: 'Ways in', value: provider.dialects.join(', ')),
        // **What differs between them, without pretending to know each agent's flow.** The two
        // kinds go in different headers, which is why the command carries `--type` — sending one
        // as the other fails as an authentication error that looks exactly like a wrong key.
        //
        // Where the value comes from is the agent's own documentation, and restating it here
        // would be per-agent knowledge going stale silently: the same trap that withdrew
        // instructions.
        if (provider.dialects.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.normal, Space.tight, Space.normal, Space.small),
            child: Text(
              'A key and a subscription token are stored differently — the command below carries '
              'which. Getting either one is the agent’s own login, on the machine, and its own '
              'documentation says how.',
              key: const Key('which-way-in'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        // **Never recomputed here.** It is usually the provider's own name, but a vault written
        // before credentials were keyed by provider answers under the *agent's* name and that key
        // stays in use — so a client intersecting two lists would report a credential missing from
        // precisely the vault that has one.
        if (provider.credentialName.isNotEmpty)
          _Field(name: 'Stored under', value: provider.credentialName),
        if (readable && provider.credentialType.isNotEmpty)
          _Field(name: 'Kind', value: provider.credentialType),
        if (provider.storeCommand.isNotEmpty) ...<Widget>[
          const _Heading(words: 'To store one, at the machine'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.normal, 0, Space.normal, Space.small),
            child: Row(
              children: <Widget>[
                Expanded(
                  // Rendered verbatim. The daemon built it from the key it really uses, and a
                  // line rebuilt here would sooner or later name a different one.
                  child: SelectableText(provider.storeCommand,
                      key: const Key('store-command'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
                IconButton(
                  key: const Key('copy-store-command'),
                  icon: const Icon(Icons.copy, size: Sizes.rowIcon),
                  tooltip: 'Copy it',
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: provider.storeCommand)),
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Space.normal, 0, Space.normal, Space.normal),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('import-credential'),
              onPressed: onImport,
              icon: const Icon(Icons.download_outlined, size: Sizes.rowIcon),
              // No secret crosses this: the daemon reads the agent's own config on its own disk,
              // and only a name comes back.
              label: const Text('Import what the agent already has there'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.words});

  final String words;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            Space.normal, Space.small, Space.normal, Space.tight),
        child: Text(words, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.normal, vertical: Space.tight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: Sizes.label,
              child: Text(name, style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: Text(value.isEmpty ? '—' : value,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
      );
}
