import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';

import '../app/authentication.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'page_explanation.dart' show counted;
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
    this.filter,
    this.reads = ImportReads.thisComputer,
    super.key,
  });

  /// Where the machine is, in the import's words: the agent's files are read where it runs.
  final ImportReads reads;

  /// What the machine has.
  final Authentication authentication;

  /// Imports what an agent already holds there. No secret crosses doing it.
  final void Function(String? agent) onImport;

  /// The page's filter, which narrows these rows as it narrows the page's others.
  final TextEditingController? filter;

  /// Its words for the page's subtitle: how many providers, or that they are not read.
  static String countWords(Authentication authentication) =>
      authentication.answer == null || authentication.problem != null
      ? 'providers not read'
      : counted(authentication.providers.length, 'provider', 'providers');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    final filter = this.filter;
    final read = authentication.answer != null && authentication.problem == null;
    return ListenableBuilder(
      listenable: filter ?? const AlwaysStoppedAnimation<double>(0),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LeafRowsCard(
            title: 'Providers',
            count: read ? '${authentication.providers.length}' : 'not read',
            empty: Text(
              !read
                  ? 'not read'
                  : authentication.providers.isEmpty
                  ? 'No provider is declared on this machine.'
                  : 'Nothing matches.',
              style: small,
            ),
            children: <Widget>[
              for (final provider in authentication.providers)
                if (filter == null || passesFilter(filter, '${provider.name} ${provider.label} ${provider.upstream}'))
                  _ProviderRow(
                    provider: provider,
                    readable: authentication.readable,
                    onImport: () => onImport(provider.name),
                    reads: reads,
                    importSaid: authentication.importedFor == provider.name ? authentication.importSaid : '',
                    importFailed: authentication.importProblem != null,
                    importing: authentication.importing,
                  ),
            ],
          ),
          if (authentication.problem != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                authentication.problem!,
                key: const Key('providers-problem'),
                style: TextStyle(color: scheme.error),
              ),
            ),
          if (authentication.busy && authentication.answer == null)
            const Padding(
              padding: EdgeInsets.only(top: Space.small),
              child: Text('Asking the machine…'),
            ),
          if (!authentication.readable && authentication.answer != null)
            const Padding(
              padding: EdgeInsets.only(top: Space.small),
              child: Text(
                'The vault is shut, so nothing here can say which of these are '
                'authenticated. That is not the same as none of them being.',
                key: Key('shut-so-cannot-say'),
              ),
            ),
          if (authentication.answer != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                'Nothing here asks for a secret. A credential is typed at the machine, in '
                'the terminal half of the connection this window already uses to reach it.',
                key: const Key('typed-at-the-machine'),
                style: small,
              ),
            ),
        ],
      ),
    );
  }
}

/// Where an import reads the agent's own files, in its button's words.
enum ImportReads {
  /// This computer, where the window runs.
  thisComputer('on this computer'),

  /// A WSL distribution on this computer.
  wsl('in WSL'),

  /// A remote machine.
  host('on the host');

  const ImportReads(this.words);

  /// The button's last words.
  final String words;
}

/// One provider, with where its credential belongs.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.readable,
    required this.onImport,
    required this.reads,
    required this.importSaid,
    required this.importFailed,
    required this.importing,
  });

  final Provider provider;
  final bool readable;
  final VoidCallback onImport;
  final ImportReads reads;

  /// What the last import pressed here said, empty when none was.
  final String importSaid;
  final bool importFailed;
  final bool importing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
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
      title: Wrap(
        spacing: Space.small,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(provider.label.isEmpty ? provider.name : provider.label, key: const Key('provider')),
          StateChip(
            !readable
                ? 'cannot say'
                : provider.authenticated
                ? 'authenticated'
                : 'not authenticated',
            toneWords: !readable
                ? 'shut'
                : provider.authenticated
                ? 'ok'
                : 'waiting',
          ),
        ],
      ),
      subtitle: Text(
        !readable
            ? '${provider.name} · cannot say while the vault is shut'
            : provider.authenticated
            ? '${provider.name} · authenticated'
            : '${provider.name} · not authenticated',
      ),
      children: <Widget>[
        _Field(name: 'Reaches', value: provider.upstream),
        if (provider.dialects.isNotEmpty) _Field(name: 'Ways in', value: provider.dialects.join(', ')),
        // **What differs between them, without pretending to know each agent's flow.** The two
        // kinds go in different headers, which is why the command carries `--type` — sending one
        // as the other fails as an authentication error that looks exactly like a wrong key.
        //
        // Where the value comes from is the agent's own documentation, and restating it here
        // would be per-agent knowledge going stale silently: the same trap that withdrew
        // instructions.
        if (provider.dialects.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.normal, Space.tight, Space.normal, Space.small),
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
        if (provider.credentialName.isNotEmpty) _Field(name: 'Stored under', value: provider.credentialName),
        if (readable && provider.credentialType.isNotEmpty) _Field(name: 'Kind', value: provider.credentialType),
        if (provider.storeCommand.isNotEmpty) ...<Widget>[
          const _Heading(words: 'To store one, at the machine'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
            child: Row(
              children: <Widget>[
                Expanded(
                  // Rendered verbatim. The daemon built it from the key it really uses, and a
                  // line rebuilt here would sooner or later name a different one.
                  child: SelectableText(
                    provider.storeCommand,
                    key: const Key('store-command'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                IconButton(
                  key: const Key('copy-store-command'),
                  icon: const Icon(Icons.copy, size: Sizes.rowIcon),
                  tooltip: 'Copy it',
                  onPressed: () => Clipboard.setData(ClipboardData(text: provider.storeCommand)),
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.normal),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('import-credential'),
              onPressed: importing ? null : onImport,
              icon: const Icon(Icons.download_outlined, size: Sizes.rowIcon),
              // No secret crosses this: the daemon reads the agent's own config on its own disk,
              // and only a name comes back.
              label: Text('Import what the agent already has ${reads.words}'),
            ),
          ),
        ),
        if (importSaid.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.normal),
            // Never the value — the length is how somebody sees it worked without the
            // confirmation becoming the place the secret appears.
            child: Text(
              importSaid,
              key: Key('import-says ${provider.name}'),
              style: importFailed ? TextStyle(color: scheme.error) : null,
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
    padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.normal, Space.tight),
    child: Text(words, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.tight),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: Sizes.label,
          child: Text(name, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      ],
    ),
  );
}
