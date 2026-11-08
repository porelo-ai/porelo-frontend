import 'package:flutter/material.dart';

import '../app/commands.dart';
import 'command_menu.dart';
import 'machine_view.dart' show Highlight;
import 'tokens.dart';

/// One fact of a machine, as a tile: what it is, its value large, and a detail under it.
typedef ManagingFact = ({String id, String label, IconData icon, String value, String detail, bool known, bool code});

/// An action of the danger zone: what it does, said in one line beside its button.
typedef DangerAction = ({Command command, String title, String words, String button});

/// The page of facts and actions of one machine: its head once, its facts as tiles, its actions
/// with the reason a waiting one waits beside it, and what cannot be undone apart in a danger zone.
class ManagingPage extends StatelessWidget {
  /// Constructor taking the page's head and what it shows.
  const ManagingPage({
    required this.head,
    required this.facts,
    required this.actions,
    required this.danger,
    required this.lastRead,
    this.primary,
    this.menuCommands = const [],
    this.menuTooltip = 'What this machine can be told to do',
    this.highlight,
    this.busy = false,
    super.key,
  });

  /// The path line, the machine's name with its state, and what it is.
  final Widget head;

  /// The machine's facts, each a tile.
  final List<ManagingFact> facts;

  /// The actions that can be undone or repeated.
  final List<Command> actions;

  /// The one action filled, as the main action of this state.
  final String? primary;

  /// The actions that cannot be undone, apart.
  final List<DangerAction> danger;

  /// The rest of what can be done with the machine, behind its menu.
  final List<Command> menuCommands;

  /// What the menu says it holds.
  final String menuTooltip;

  /// When the facts were read, in words.
  final String lastRead;

  /// The command a finder marked.
  final String? highlight;

  /// Whether the machine is being asked right now.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = actions.where((command) => command.visible).toList();
    return ListView(
      key: const Key('facts-page'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        head,
        if (busy) const LinearProgressIndicator(minHeight: Sizes.progressBar),
        const SizedBox(height: Space.normal),
        LayoutBuilder(
          builder: (context, constraints) {
            final across = (constraints.maxWidth / Sizes.factTile).floor().clamp(1, facts.isEmpty ? 1 : facts.length);
            // Four in a row where they fit, else two, else one: never three and a lone one under them.
            final columns = across >= facts.length ? facts.length : (across >= 2 ? 2 : 1);
            final width = (constraints.maxWidth - Space.normal * (columns - 1)) / columns;
            return Wrap(
              spacing: Space.normal,
              runSpacing: Space.normal,
              children: [
                for (final fact in facts)
                  SizedBox(
                    width: width,
                    child: _FactTile(fact: fact),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Space.wide),
        Row(
          children: [
            Expanded(child: Text('Actions', style: theme.textTheme.titleMedium)),
            if (menuCommands.isNotEmpty)
              CommandMenu(
                key: const Key('machine-menu'),
                commands: menuCommands,
                tooltip: menuTooltip,
                highlight: highlight,
              ),
          ],
        ),
        const SizedBox(height: Space.small),
        Wrap(
          spacing: Space.normal,
          runSpacing: Space.small,
          children: [
            for (final command in shown)
              _Action(
                command: command,
                highlight: highlight,
                child: command.id == primary
                    ? FilledButton(
                        key: Key(command.id),
                        onPressed: command.available ? command.run : null,
                        child: Text(command.label),
                      )
                    : OutlinedButton(
                        key: Key(command.id),
                        onPressed: command.available ? command.run : null,
                        child: Text(command.label),
                      ),
              ),
          ],
        ),
        if (danger.any((each) => each.command.visible)) ...[
          const SizedBox(height: Space.wide),
          Material(
            key: const Key('danger-zone'),
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: scheme.error, width: Space.hairline),
              borderRadius: BorderRadius.circular(Radii.medium),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.normal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Danger zone', style: theme.textTheme.titleMedium?.copyWith(color: scheme.error)),
                  for (final (place, each) in danger.where((each) => each.command.visible).indexed) ...[
                    if (place > 0) const Divider(height: Space.wide),
                    const SizedBox(height: Space.small),
                    Wrap(
                      spacing: Space.normal,
                      runSpacing: Space.small,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(each.title, style: theme.textTheme.titleSmall),
                            Text(each.words, style: theme.textTheme.bodySmall),
                          ],
                        ),
                        _Action(
                          command: each.command,
                          highlight: highlight,
                          child: OutlinedButton(
                            key: Key(each.command.id),
                            onPressed: each.command.available ? each.command.run : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.error,
                              side: BorderSide(color: scheme.error),
                            ),
                            child: Text(each.button),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.normal),
        Text(lastRead, key: const Key('managing-last-read'), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// One action, and beside it why it cannot run now.
class _Action extends StatelessWidget {
  const _Action({required this.command, required this.child, this.highlight});

  final Command command;
  final Widget child;
  final String? highlight;

  @override
  Widget build(BuildContext context) => Wrap(
    key: ValueKey<String>('managing-action ${command.id}'),
    spacing: Space.small,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Highlight(
        active: highlight == command.id,
        child: Tooltip(message: command.unavailable ?? command.label, child: child),
      ),
      if (!command.available && command.unavailable != null)
        Text(
          'Not now: ${command.unavailable}',
          key: ValueKey<String>('why ${command.id}'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
    ],
  );
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});

  final ManagingFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    return Material(
      key: ValueKey<String>('managing-tile ${fact.id}'),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant, width: Space.hairline),
        borderRadius: BorderRadius.circular(Radii.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(fact.icon, size: Sizes.mark, color: scheme.onSurfaceVariant),
                const SizedBox(width: Space.small),
                Flexible(
                  child: Text(fact.label, key: const Key('tile-label'), style: theme.textTheme.labelMedium),
                ),
              ],
            ),
            const SizedBox(height: Space.small),
            Text(
              fact.value,
              key: const Key('tile-value'),
              style: theme.textTheme.titleLarge?.merge(fact.known ? null : muted),
            ),
            Text(
              fact.detail,
              key: const Key('tile-detail'),
              style: theme.textTheme.bodySmall?.merge(fact.code ? const TextStyle(fontFamily: 'monospace') : null),
            ),
          ],
        ),
      ),
    );
  }
}
