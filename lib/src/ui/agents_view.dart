import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';

import '../app/agent_inventory.dart';
import '../app/commands.dart';
import 'expandable_list_row.dart';
import 'fact_rows.dart';
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

/// One installed agent, with what it may reach: its name, command and version on the row, and,
/// unfolded, its facts as label and value in two aligned columns.
class _AgentRow extends StatefulWidget {
  const _AgentRow({required this.agent});

  final Agent agent;

  @override
  State<_AgentRow> createState() => _AgentRowState();
}

class _AgentRowState extends State<_AgentRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    // The list's own fold, so the row reads as every other list's; its body stands at the left.
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: Space.wide),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      expandedAlignment: AlignmentDirectional.topStart,
      onExpansionChanged: (open) => setState(() => _open = open),
      title: Text(
        agent.label.isEmpty ? agent.name : agent.label,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: _open ? FontWeight.w600 : FontWeight.w500),
      ),
      subtitle: Text(
        agent.version.isEmpty ? '${agent.name} · version not reported' : '${agent.name} · ${agent.version}',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const StateChip('installed'),
          const SizedBox(width: Space.small),
          Icon(_open ? Icons.expand_less : Icons.expand_more, size: Sizes.rowIcon),
        ],
      ),
      children: <Widget>[
        FactRows(
          facts: <Fact>[
            Fact('Found at', _code(agent.from)),
            Fact('Runs', _code(agent.binary)),
            // **The answer to "did a person or an agent write this commit?"**, which had nowhere to
            // be looked up before the field existed. It is also what a pre-push guard on somebody's
            // own checkout matches on, so the two have to agree — and reading it here means nobody
            // has to open a manifest to find out what they agree on.
            Fact(
              'Commits as',
              agent.commitsAs.recorded
                  ? _code(agent.commitsAs.words)
                  : const Text('not recorded — installed before this was reported'),
            ),
            Fact(
              'Machines it needs',
              _Hosts(
                chips: <Widget>[for (final host in agent.allowedDomains) _HostChip(host: host, refused: false)],
                none: 'None of its own. It reaches whatever the project allows.',
                note: "Added to a task's egress on top of the project's own.",
                noteStyle: small,
              ),
              dividedAbove: true,
            ),
            if (agent.refusedDomains.isNotEmpty)
              Fact(
                'Asked for and refused',
                _Hosts(
                  chips: <Widget>[for (final host in agent.refusedDomains) _HostChip(host: host, refused: true)],
                  none: '',
                  note:
                      'This agent declares these and is deliberately not given them. A dropped packet '
                      'cannot tell that apart from nobody having added it.',
                  noteStyle: small,
                ),
              ),
            Fact(
              'What it fetches',
              agent.artifacts.isEmpty
                  ? const Text(
                      'Nothing. It writes its tool into the image, so it pins a version and has no '
                      'digest to check.',
                      key: Key('agent-fetches-nothing'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[for (final artifact in agent.artifacts) _Artifact(artifact: artifact)],
                    ),
            ),
          ],
        ),
      ],
    );
  }

  /// A path or a name as the machine spells it, said to be missing rather than drawn blank.
  static Widget _code(String value) =>
      value.isEmpty ? const Text('not reported by the machine') : SelectableText(value, style: codeText);
}

/// Hosts as chips, with the note that says what they are for under them.
class _Hosts extends StatelessWidget {
  const _Hosts({required this.chips, required this.none, required this.note, required this.noteStyle});

  final List<Widget> chips;
  final String none;
  final String note;
  final TextStyle? noteStyle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (chips.isEmpty) Text(none) else Wrap(spacing: Space.small, runSpacing: Space.small, children: chips),
      const SizedBox(height: Space.small),
      Text(note, style: noteStyle),
    ],
  );
}

/// One host an agent needs, or one it asked for and is refused, marked so without colour too.
class _HostChip extends StatelessWidget {
  const _HostChip({required this.host, required this.refused});

  final String host;
  final bool refused;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = refused ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.small, vertical: Space.tight),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: Opacities.stateChip),
        borderRadius: BorderRadius.circular(Radii.small),
        border: refused ? Border.all(color: tone.withValues(alpha: Opacities.stateChip * 3)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(refused ? Icons.block : Icons.check, size: Sizes.rowIcon, color: tone),
          const SizedBox(width: Space.tight),
          Flexible(
            child: Text(
              host,
              key: Key(refused ? 'agent-refused' : 'agent-host'),
              style: codeText.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// One file an agent fetches, and whether anybody can check it.
///
/// **Two states, never a blank.** The daemon refuses to build an artifact with neither a digest
/// nor a reason, so an unverified one always says why — and a stated reason is a decision
/// somebody made, not a fault. It is shown as the reason rather than as a warning.
///
/// The digest is shortened to read and copied whole: it is compared, never retyped.
class _Artifact extends StatelessWidget {
  const _Artifact({required this.artifact});

  final InstallArtifact artifact;

  static String _short(String digest) =>
      digest.length > 20 ? '${digest.substring(0, 8)}…${digest.substring(digest.length - 8)}' : digest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.tight),
      child: Wrap(
        spacing: Space.normal,
        runSpacing: Space.tight,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SelectableText(artifact.url, key: const Key('agent-artifact'), style: codeText),
          if (artifact.unverified)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.gpp_maybe_outlined, size: Sizes.rowIcon, color: scheme.tertiary),
                const SizedBox(width: Space.tight),
                Flexible(
                  child: Text('Not checked, on purpose: ${artifact.reason}', key: const Key('agent-artifact-digest')),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.only(left: Space.small),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.small),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      'sha256 ${_short(artifact.sha256)}',
                      key: const Key('agent-artifact-digest'),
                      style: codeText.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  IconButton(
                    key: const Key('agent-artifact-copy'),
                    tooltip: 'Copy the full sha256',
                    icon: const Icon(Icons.copy_outlined, size: Sizes.rowIcon),
                    onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: artifact.sha256))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
