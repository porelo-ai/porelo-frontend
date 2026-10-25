import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/agent_inventory.dart';
import 'panes.dart';
import 'tokens.dart';

/// What agents are installed on this machine, and what each may reach.
///
/// It never names an agent this build knows about: the list is whatever the machine answered.
///
/// Three lists, and the last two are the ones nobody would go looking for: what is installed and
/// unusable, and what is installed and permanently hidden by another copy.
class AgentsView extends StatelessWidget {
  /// Constructor taking the inventory and how to close it.
  const AgentsView({required this.inventory, required this.onClose, super.key});

  /// What the machine answered.
  final AgentInventory inventory;

  /// Closes the view.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        PaneHeader(
          title: 'Agents installed here',
          trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: onClose),
        ),
        if (inventory.problem != null)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: Sizes.divider),
            ),
            padding: const EdgeInsets.all(Space.normal),
            child: Text(inventory.problem!, key: const Key('agents-problem')),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Space.small),
            children: <Widget>[
              if (inventory.busy)
                const Padding(padding: EdgeInsets.all(Space.normal), child: Text('Asking the machine what it has…'))
              else if (inventory.agents.isEmpty && inventory.failures.isEmpty && inventory.shadowed.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(Space.normal),
                  child: Text(
                    'None is installed. That is a state, not a failure — an agent is installed '
                    'separately from the thing that runs it.',
                    key: Key('no-agents'),
                  ),
                ),
              for (final agent in inventory.agents) _AgentRow(agent: agent),
              if (inventory.shadowed.isNotEmpty) ...<Widget>[
                const _Heading(words: 'Installed and never used'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
                  child: Text(
                    'Another copy of the same file wins: the most specific directory is searched '
                    'first. These are never started, so their version is not the one running.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                for (final hidden in inventory.shadowed)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.layers_clear_outlined,
                      size: Sizes.mark,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    title: Text(
                      hidden.path,
                      key: const Key('agent-shadowed'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    // The winner is named, never implied: "not in use" on its own leaves somebody
                    // asking where to look.
                    subtitle: Text(
                      '${hidden.usedInstead} runs instead',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
              ],
              if (inventory.failures.isNotEmpty) ...<Widget>[
                const _Heading(words: 'Installed and unusable'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
                  child: Text(
                    'These are here and could not be asked what they are. Listed rather than '
                    'left out: absent is the state nobody goes looking for.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                for (final failure in inventory.failures.entries)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.error_outline, size: Sizes.mark, color: Theme.of(context).colorScheme.error),
                    title: Text(
                      failure.key,
                      key: const Key('agent-failure'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    subtitle: Text(failure.value),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One installed agent, with what it may reach.
class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: const Icon(Icons.smart_toy_outlined, size: Sizes.mark),
    title: Text(agent.label.isEmpty ? agent.name : agent.label),
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
      const _Heading(words: 'Hosts it needs'),
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
