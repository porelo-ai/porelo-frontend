import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/agent_inventory.dart';
import '../app/commands.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'page_explanation.dart' show counted;
import 'tokens.dart';

/// What agents are installed on this machine, and what each may reach.
///
/// It never names an agent this build knows about: the list is whatever the machine answered.
///
/// Three lists, and the last two are the ones nobody would go looking for: what is installed and
/// unusable, and what is installed and permanently hidden by another copy.
class AgentsView extends StatelessWidget {
  /// Constructor taking the inventory, the page's head and the providers' rows under it.
  const AgentsView({
    required this.inventory,
    required this.head,
    this.providers,
    this.providerRows,
    this.subtitle,
    super.key,
  });

  /// What the machine answered.
  final AgentInventory inventory;

  /// Where the page sits and what its head says beside the agents' own words.
  final LeafHead head;

  /// The existing provider command on this same machine.
  final Command? providers;

  /// The providers of this machine, the second group of rows under the same head.
  final Widget? providerRows;

  /// Its words for the page's subtitle: how many agents, or that they are not read.
  static String countWords(AgentInventory inventory) => !inventory.asked || inventory.problem != null
      ? 'agents not read'
      : inventory.busy && inventory.agents.isEmpty
      ? 'agents not read yet'
      : counted(inventory.agents.length, 'agent', 'agents');

  /// What the page's subtitle says: the agents and the providers counted, or said not read.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final read = inventory.asked && !(inventory.busy && inventory.agents.isEmpty);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.normal),
      child: FilteredListSection(
        key: ValueKey<String>(head.id),
        storageId: head.id,
        title: 'Agents & providers',
        leaf: true,
        collapsible: false,
        path: head.path,
        pathKey: head.pathKey,
        search: head.filter,
        searchHint: 'Filter the agents and providers',
        read: read,
        busy: inventory.busy,
        problem: inventory.problem,
        staleRows: head.stale,
        subtitle: subtitle,
        actions: <Widget>[
          if (providers case final command?)
            Tooltip(
              message: command.unavailable ?? command.label,
              child: OutlinedButton(
                key: Key(command.id),
                onPressed: command.available ? command.run : null,
                child: Text(command.label),
              ),
            ),
        ],
        beforeRows: <Widget>[
          ...head.notices,
          _group(context, 'Agents', read ? '${inventory.agents.length}' : 'not read'),
        ],
        emptyWords:
            'None is installed. That is a state, not a failure — an agent is installed '
            'separately from the thing that runs it.',
        rows: <FilteredRow>[
          for (final agent in inventory.agents) (words: '${agent.name} ${agent.label}', child: _AgentRow(agent: agent)),
          for (final hidden in inventory.shadowed)
            (
              words: '${hidden.path} ${hidden.usedInstead}',
              child: LeafListRow(
                leading: Icon(
                  Icons.layers_clear_outlined,
                  size: Sizes.mark,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                title: hidden.path,
                titleKey: const Key('agent-shadowed'),
                state: 'never used',
                // The winner is named, never implied: "not in use" on its own leaves somebody
                // asking where to look.
                subtitle: Text('${hidden.usedInstead} runs instead'),
              ),
            ),
          for (final failure in inventory.failures.entries)
            (
              words: '${failure.key} ${failure.value}',
              child: LeafListRow(
                leading: Icon(Icons.error_outline, size: Sizes.mark, color: Theme.of(context).colorScheme.error),
                title: failure.key,
                titleKey: const Key('agent-failure'),
                state: 'unusable',
                toneWords: 'failed',
                subtitleMaxLines: null,
                subtitle: Text(failure.value),
              ),
            ),
        ],
        afterRows: <Widget>[
          if (inventory.shadowed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                'Never used: another copy of the same file wins, as the most specific directory is '
                'searched first. These are never started, so their version is not the one running.',
                style: small,
              ),
            ),
          if (inventory.failures.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                'Unusable: these are here and could not be asked what they are. Listed rather than '
                'left out: absent is the state nobody goes looking for.',
                style: small,
              ),
            ),
          ?providerRows,
        ],
      ),
    );
  }

  static Widget _group(BuildContext context, String title, String count) => Padding(
    padding: const EdgeInsets.only(bottom: Space.small),
    child: Wrap(
      spacing: Space.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(count, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

/// One installed agent, with what it may reach.
class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    shape: const Border(),
    collapsedShape: const Border(),
    tilePadding: EdgeInsets.zero,
    leading: const Icon(Icons.smart_toy_outlined, size: Sizes.mark),
    title: Wrap(
      spacing: Space.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[Text(agent.label.isEmpty ? agent.name : agent.label), const StateChip('installed')],
    ),
    subtitle: Text(agent.version.isEmpty ? '${agent.name} · version not reported' : '${agent.name} · ${agent.version}'),
    children: <Widget>[
      _Field(name: 'Found at', value: agent.from),
      _Field(name: 'Runs', value: agent.binary),
      // **The answer to "did a person or an agent write this commit?"**, which had nowhere to
      // be looked up before the field existed. It is also what a pre-push guard on somebody's
      // own checkout matches on, so the two have to agree — and reading it here means nobody
      // has to open a manifest to find out what they agree on.
      _Field(
        name: 'Commits as',
        value: agent.commitsAs.recorded ? agent.commitsAs.words : 'not recorded — installed before this was reported',
      ),
      const _Heading(words: 'Machines it needs'),
      if (agent.allowedDomains.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
          child: Text('None of its own. It reaches whatever the project allows.'),
        ),
      for (final host in agent.allowedDomains)
        ListTile(
          dense: true,
          title: Text(
            host,
            key: const Key('agent-host'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.normal),
        child: Text(
          "Added to a task's egress on top of the project's own.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      if (agent.refusedDomains.isNotEmpty) ...<Widget>[
        const _Heading(words: 'Asked for and refused'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
          child: Text(
            'This agent declares these and is deliberately not given them. A dropped packet '
            'cannot tell that apart from nobody having added it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final host in agent.refusedDomains)
          ListTile(
            dense: true,
            leading: Icon(Icons.block, size: Sizes.mark, color: Theme.of(context).colorScheme.error),
            title: Text(
              host,
              key: const Key('agent-refused'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
      const _Heading(words: 'What it fetches'),
      if (agent.artifacts.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
          child: Text(
            'Nothing. It writes its tool into the image, so it pins a version and has no '
            'digest to check.',
            key: Key('agent-fetches-nothing'),
          ),
        ),
      for (final artifact in agent.artifacts) _Artifact(artifact: artifact),
    ],
  );
}

/// One file an agent fetches, and whether anybody can check it.
///
/// **Two states, never a blank.** The daemon refuses to build an artifact with neither a digest
/// nor a reason, so an unverified one always says why — and a stated reason is a decision
/// somebody made, not a fault. It is shown as the reason rather than as a warning.
class _Artifact extends StatelessWidget {
  const _Artifact({required this.artifact});

  final InstallArtifact artifact;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(
      artifact.unverified ? Icons.gpp_maybe_outlined : Icons.verified_outlined,
      size: Sizes.mark,
      color: artifact.unverified ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary,
    ),
    title: Text(
      artifact.url,
      key: const Key('agent-artifact'),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    ),
    subtitle: Text(
      artifact.unverified ? 'Not checked, on purpose: ${artifact.reason}' : artifact.sha256,
      key: const Key('agent-artifact-digest'),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
    ),
  );
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
