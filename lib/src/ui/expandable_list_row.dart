import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/task_certifying.dart';
import 'tokens.dart';
import 'window_size.dart';

/// The card's full width, before row padding and command space are taken out.
class ListCardWidth extends InheritedWidget {
  /// Carries the available card width to its rows.
  const ListCardWidth({required this.width, required super.child, super.key});

  /// The full card width used for state-chip placement.
  final double width;

  /// The containing card's width, if it supplies one.
  static double? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ListCardWidth>()?.width;

  @override
  bool updateShouldNotify(ListCardWidth oldWidget) => width != oldWidget.width;
}

/// A list entry whose navigation, main action and disclosure have separate targets.
class ExpandableListRow extends StatefulWidget {
  /// Keeps details local while the body opens the item's own page.
  const ExpandableListRow({
    required this.leading,
    required this.title,
    required this.state,
    required this.onOpen,
    required this.details,
    this.primary,
    this.primaryKey,
    this.titleKey,
    this.bodyKey,
    this.selected = false,
    this.steps = const <Widget>[],
    this.subtitle,
    this.primaryFilled = false,
    super.key,
  });

  /// Next steps offered on the row itself, for a row with more than one: beside its title, or under
  /// it on a narrow window.
  final List<Widget> steps;

  /// The facts of what [title] says, under it, in place of [state].
  final String? subtitle;

  /// Whether the main command is what the row is there for, and so filled.
  final bool primaryFilled;

  /// The item's outlined mark, filled only when selected.
  final Widget leading;

  /// The item's name.
  final String title;

  /// A short state, with the full explanation in [details].
  final String state;

  /// Opens the item's page without performing its main action.
  final VoidCallback? onOpen;

  /// The full state and further commands, shown only after disclosure.
  final Widget details;

  /// The main command for the current state.
  final Command? primary;

  /// The existing main action's automation key.
  final Key? primaryKey;

  /// The existing title's automation key.
  final Key? titleKey;

  /// The existing navigation target's automation key.
  final Key? bodyKey;

  /// Whether this item is selected.
  final bool selected;

  @override
  State<ExpandableListRow> createState() => _ExpandableListRowState();
}

class _ExpandableListRowState extends State<ExpandableListRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final compact = WindowSize.fromContext(context) == WindowSize.compact;
    final disclosure = listDisclosureCommand(expanded: _expanded, toggle: () => setState(() => _expanded = !_expanded));
    final primary = widget.primary?.visible == true ? widget.primary : null;
    final why = primary?.unavailable == null ? null : '${primary!.label}: ${printableForAPerson(primary.unavailable!)}';
    Widget action(Command command) => Tooltip(
      message: command.unavailable ?? command.label,
      child: widget.primaryFilled
          ? FilledButton(
              key: widget.primaryKey,
              onPressed: command.available ? command.run : null,
              child: Text(command.label),
            )
          : TextButton(
              key: widget.primaryKey,
              onPressed: command.available ? command.run : null,
              child: Text(command.label),
            ),
    );
    return Semantics(
      selected: widget.selected,
      child: Card(
        child: LayoutBuilder(
          builder: (context, constraints) => ListCardWidth(
            width: constraints.maxWidth,
            child: KeyedSubtree(
              key: widget.bodyKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: widget.onOpen,
                          child: _RowWords(
                            leading: widget.leading,
                            title: widget.title,
                            titleKey: widget.titleKey,
                            subtitle: (_expanded ? null : why) ?? widget.subtitle ?? '',
                            state: widget.state,
                          ),
                        ),
                      ),
                      if (!compact) ...widget.steps,
                      if (!compact && primary != null) Flexible(child: action(primary)),
                      IconButton(
                        tooltip: disclosure.label,
                        icon: Icon(_expanded ? Icons.expand_more : Icons.chevron_right),
                        onPressed: disclosure.run,
                      ),
                    ],
                  ),
                  if (compact && (widget.steps.isNotEmpty || primary != null))
                    Padding(
                      padding: const EdgeInsets.all(Space.small),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...widget.steps, if (primary != null) action(primary)],
                      ),
                    ),
                  if (_expanded)
                    ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(Space.normal),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [if (why != null) Text(why), widget.details],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A navigation row with its menu always in reach and no expanding card.
class ItemListRow extends StatelessWidget {
  /// Creates a row whose body opens the item and whose trailing menu holds operations.
  const ItemListRow({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onOpen,
    required this.menu,
    this.bodyKey,
    this.subtitleKey,
    this.subtitleMaxLines = 2,
    this.state,
    this.titleKey,
    this.selected = false,
    super.key,
  });

  /// The observed state, kept separate from the detail line.
  final String? state;

  /// The title shown in the header.
  final String title;

  /// The source states and public information on this row.
  final String subtitle;

  /// The outlined mark for this item.
  final Widget leading;

  /// Opens this exact item.
  final VoidCallback? onOpen;

  /// The operations always reachable beside the row.
  final Widget? menu;

  /// The detail line's limit; null keeps a refusal or explanation fully visible.
  final int? subtitleMaxLines;

  /// The detail line's automation target.
  final Key? subtitleKey;

  /// The navigation target used by pointer automation.
  final Key? bodyKey;

  /// The title target used by pointer automation.
  final Key? titleKey;

  /// Whether this exact item is selected.
  final bool selected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final beside = WindowSize.chipBeside(ListCardWidth.of(context) ?? constraints.maxWidth);
      final name = Tooltip(
        message: title,
        child: Text(title, key: titleKey, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
      final chip = StateChip(state ?? 'not read');
      return ListTile(
        key: bodyKey,
        selected: selected,
        leading: leading,
        onTap: onOpen,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (beside && menu == null)
              Row(
                children: [
                  Flexible(child: name),
                  const SizedBox(width: Space.small),
                  Flexible(child: chip),
                ],
              )
            else
              name,
            if (!beside) chip,
          ],
        ),
        subtitle: Text(subtitle, key: subtitleKey, maxLines: subtitleMaxLines, overflow: TextOverflow.ellipsis),
        trailing: menu == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (beside)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: Sizes.listAction),
                      child: chip,
                    ),
                  ?menu,
                ],
              ),
      );
    },
  );
}

/// A state in words, with the same tone wherever it appears.
class StateChip extends StatelessWidget {
  /// Shows only a public state, never a credential or a value.
  const StateChip(this.words, {this.toneWords, super.key});

  /// The observed state.
  final String words;

  /// The known state category when the source supplies a longer explanation.
  final String? toneWords;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = StateColours.forWords(toneWords ?? words, colors);
    // A state too long for its place ends in an ellipsis, never cut mid-letter; the tooltip keeps it whole.
    return Tooltip(
      message: words,
      child: Chip(
        label: Text(
          words,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone),
        ),
        backgroundColor: tone.withValues(alpha: Opacities.stateChip),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _RowWords extends StatelessWidget {
  const _RowWords({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.state,
    this.titleKey,
  });
  final Widget leading;
  final String title;
  final String subtitle;
  final String state;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The trailing menu has already taken its space; keeping the chip below is safe at the boundary.
      final beside = WindowSize.chipBeside(ListCardWidth.of(context) ?? constraints.maxWidth);
      final words = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: title,
            child: Text(
              title,
              key: titleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          if (!beside && state.isNotEmpty) StateChip(state),
        ],
      );
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.listRowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.small, vertical: Space.small),
          child: Row(
            children: [
              leading,
              const SizedBox(width: Space.small),
              Expanded(child: words),
              if (beside && state.isNotEmpty) ...[
                const SizedBox(width: Space.small),
                Flexible(child: StateChip(state)),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// A leaf row with rich details and commands that stack when the card narrows.
class LeafListRow extends StatelessWidget {
  /// Keeps navigation separate from the row's commands.
  const LeafListRow({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.state,
    this.trailing,
    this.onTap,
    this.titleKey,
    this.toneWords,
    this.subtitleMaxLines = 2,
    this.chipFirst = false,
    super.key,
  });

  /// Whether the state stands in the name's line before it, and the operations right-aligned inside the row, wrapping
  /// together under the words where the card is narrow: for a row whose operations are several buttons, which a chip
  /// stacked over them pushed past the row's edges.
  final bool chipFirst;

  /// The title's automation target.
  final Key? titleKey;

  /// The known state category where [state] says more than it.
  final String? toneWords;

  /// The detail's limit per line of words; null keeps a refusal or what to do in full.
  final int? subtitleMaxLines;

  /// The full public name, available in a tooltip.
  final String title;

  /// The public details, including any refusal or unavailable reason.
  final Widget subtitle;

  /// The item's outlined icon.
  final Widget leading;

  /// The observed state in words.
  final String state;

  /// The row's existing operations.
  final Widget? trailing;

  /// Opens the item's page.
  final VoidCallback? onTap;

  /// The operations as one group standing at the row's right, wrapping together.
  Widget? _actionsAtTheRight() => switch (trailing) {
    final Wrap actions => Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: actions.spacing,
      runSpacing: Space.tight,
      children: actions.children,
    ),
    final actions => actions,
  };

  Widget _chipFirst(BuildContext context, {required bool beside}) {
    final actions = _actionsAtTheRight();
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: title,
          child: Text(
            title,
            key: titleKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (subtitleMaxLines case final lines?)
          DefaultTextStyle.merge(maxLines: lines, overflow: TextOverflow.ellipsis, child: subtitle)
        else
          subtitle,
      ],
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Space.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, line) => Row(
                children: [
                  leading,
                  const SizedBox(width: Space.small),
                  Flexible(child: StateChip(state, toneWords: toneWords)),
                  const SizedBox(width: Space.small),
                  Expanded(child: words),
                  if (beside && actions != null) ...[
                    const SizedBox(width: Space.small),
                    // As wide as the buttons need, up to a share of the line: past it they wrap, as one group.
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: line.maxWidth * Sizes.rowActionsShare),
                      child: actions,
                    ),
                  ],
                ],
              ),
            ),
            if (!beside && actions != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.small),
                child: Align(alignment: Alignment.centerRight, child: actions),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final beside = WindowSize.chipBeside(ListCardWidth.of(context) ?? constraints.maxWidth);
      if (chipFirst) return _chipFirst(context, beside: beside);
      final actions = trailing;
      return InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(Space.small),
                    child: Row(
                      children: [
                        leading,
                        const SizedBox(width: Space.small),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Tooltip(
                                message: title,
                                child: Text(
                                  title,
                                  key: titleKey,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              if (subtitleMaxLines case final lines?)
                                DefaultTextStyle.merge(
                                  maxLines: lines,
                                  overflow: TextOverflow.ellipsis,
                                  child: subtitle,
                                )
                              else
                                subtitle,
                              if (!beside) StateChip(state, toneWords: toneWords),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (beside)
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StateChip(state, toneWords: toneWords),
                        ?actions,
                      ],
                    ),
                  ),
              ],
            ),
            if (!beside && actions != null)
              Padding(
                padding: const EdgeInsets.all(Space.small),
                child: actions is Wrap
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actions.children)
                    : actions,
              ),
          ],
        ),
      );
    },
  );
}
