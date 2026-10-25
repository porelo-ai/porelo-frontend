import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/egress.dart';
import 'panes.dart';
import 'tokens.dart';

/// What a project's work may reach, and where each host came from. **Shown, never changed here**: the
/// project's repository holds its project.yml, the one place it is changed (walk 10:
/// the project.yml in the repository is the single source of truth).
class EgressView extends StatelessWidget {
  /// Constructor taking the egress.
  const EgressView({required this.egress, required this.onClose, super.key});

  /// What the project may reach.
  final Egress egress;

  /// Closes the view.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final using = <String>{
      for (final host in egress.reachable)
        if (host.origin.startsWith('set ')) host.origin.substring(4),
    };

    return Column(
      children: <Widget>[
        PaneHeader(
          title: egress.repository == null
              ? 'What ${egress.project?.name ?? ''} may reach'
              : 'What ${egress.project?.name ?? ''} · ${egress.repository} may reach',
          trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: onClose),
        ),
        if (egress.problem != null)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: Sizes.divider),
            ),
            padding: const EdgeInsets.all(Space.normal),
            child: Text(egress.problem!, key: const Key('egress-problem')),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Space.small),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.normal, 0),
                child: Text(
                  'Changed only in project.yml in the project\'s repository, under egress; '
                  'a machine following it takes the change at its next look. Work already running keeps '
                  'what it started with.',
                  key: const Key('egress-where-changed'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              _Heading(words: 'Reachable now'),
              if (egress.repository case final repository?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
                  child: Text(
                    'What every repository of ${egress.project?.name ?? ''} may reach, and what '
                    '$repository adds to it. A repository only ever adds: nothing it names can take '
                    'away what the project grants. What it adds is in $repository\'s own block of '
                    'project.yml.',
                    key: const Key('what-a-repository-adds'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              // In the order the sources granted them: the first grant wins, so the order is what
              // says where a host came from. Sorting would destroy the answer.
              for (final host in egress.reachable) _Reachable(host: host, added: egress.addedByTheRepository(host)),
              if (egress.refused.isNotEmpty) ...<Widget>[
                _Heading(words: 'Asked for and refused'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
                  child: Text(
                    'The agent wants these and is deliberately not given them. A dropped packet '
                    'cannot tell that apart from nobody having added it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                for (final host in egress.refused) _Refused(host: host),
              ],
              _Heading(words: 'Sets installed on this machine'),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
                child: Text(
                  'Chosen one at a time, and deliberately: there is no "all sets, including '
                  'ones installed later". A set shipped in a later release would widen this '
                  'project without anybody editing it.',
                  key: const Key('why-no-open-ended-sets'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (egress.sets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(Space.normal),
                  child: Text('None is installed. That is a state, not a failure.'),
                ),
              for (final set in egress.sets) _SetRow(set: set, inUse: using.contains(set.name)),
              if (egress.locations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(Space.normal),
                  child: Text(
                    'Searched, most specific first: ${egress.locations.join(', ')}. '
                    'A set an operator drops into their own directory wins over a packaged one '
                    'of the same name, which is why the same name can behave differently on two '
                    'machines.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
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
    padding: const EdgeInsets.fromLTRB(Space.normal, Space.wide, Space.normal, Space.small),
    child: Text(words, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _Reachable extends StatelessWidget {
  const _Reachable({required this.host, this.added = false});

  final EgressHost host;

  /// Whether the repository being looked at adds it, rather than every repository getting it.
  final bool added;

  @override
  Widget build(BuildContext context) => ListTile(
    key: added ? ValueKey<String>('added ${host.host}') : null,
    dense: true,
    leading: added
        ? Icon(Icons.add_circle_outline, size: Sizes.rowIcon, color: Theme.of(context).colorScheme.tertiary)
        : null,
    title: Text(host.host, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    trailing: Text(added ? 'added by this repository' : host.origin, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _Refused extends StatelessWidget {
  const _Refused({required this.host});

  final String host;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(Icons.block, size: Sizes.mark, color: Theme.of(context).colorScheme.error),
    title: Text(
      host,
      key: const Key('refused-host'),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    ),
  );
}

/// One installed set, with the hosts it grants.
///
/// The domains are shown because a set exists so nobody authors host lists by hand, and that only
/// works if a person can see what the name means.
class _SetRow extends StatelessWidget {
  const _SetRow({required this.set, required this.inUse});

  final EgressSet set;
  final bool inUse;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: Icon(inUse ? Icons.check_circle_outline : Icons.circle_outlined, size: Sizes.mark),
    title: Text(set.label),
    subtitle: Text('${set.name} · ${set.domains.length} hosts${inUse ? ' · in use' : ''}'),
    children: <Widget>[
      for (final domain in set.domains)
        ListTile(
          dense: true,
          title: Text(domain, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
    ],
  );
}
