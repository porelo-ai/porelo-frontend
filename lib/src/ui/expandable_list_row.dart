import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
                      // As wide as it needs, up to its share: a flexible action would keep the half it leaves unused.
                      if (!compact && primary != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth * Sizes.rowSideShare),
                          child: action(primary),
                        ),
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
      // Beside by the card's width, as every row of it, unless next steps left the words too little room for it.
      final beside = WindowSize.chipBesideWords(
        card: ListCardWidth.of(context) ?? constraints.maxWidth,
        words: constraints.maxWidth,
      );
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
                // As wide as it needs, up to its share, so the name takes every pixel the state leaves.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * Sizes.rowSideShare),
                  child: StateChip(state),
                ),
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
      final chip = StateChip(state, toneWords: toneWords);
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
          if (!beside) chip,
        ],
      );
      if (beside) {
        return InkWell(
          onTap: onTap,
          child: _StateBesideOrUnder(children: [leading, words, chip, ?_actionsAtTheRight()]),
        );
      }
      return InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.small),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: Space.small),
                  Expanded(child: words),
                ],
              ),
            ),
            if (actions != null)
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

/// A row's mark, words, state and operations: the state and the operations stand at its right, on one line and
/// centered in its height, with the width they need, while they take no more than [Sizes.rowActionsShare] of it; with
/// more, the state stands under the words and the operations under both, at the right, so neither is cut.
class _StateBesideOrUnder extends MultiChildRenderObjectWidget {
  /// Takes the mark, the words, the state and, when the row has any, its operations, in this order.
  const _StateBesideOrUnder({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStateBesideOrUnder();
}

class _Slot extends ContainerBoxParentData<RenderBox> {}

class _RenderStateBesideOrUnder extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _Slot>, RenderBoxContainerDefaultsMixin<RenderBox, _Slot> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Slot) child.parentData = _Slot();
  }

  RenderBox get _leading => firstChild!;
  RenderBox get _words => childAfter(_leading)!;
  RenderBox get _chip => childAfter(_words)!;
  RenderBox? get _actions => childAfter(_chip);

  /// The operations' width on one line; none, or a menu that offers nothing, takes no room and no gap.
  double get _actionsWidth => _actions?.getMaxIntrinsicWidth(double.infinity) ?? 0;

  /// The state and the operations on one line.
  double get _sideWidth {
    final actions = _actionsWidth;
    return _chip.getMaxIntrinsicWidth(double.infinity) + (actions > 0 ? Space.small + actions : 0);
  }

  /// Lays the children out, or only measures them, for [constraints]; places them when [place] is set.
  Size _arrange(BoxConstraints constraints, ChildLayouter layoutChild, {required bool place}) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : getMaxIntrinsicWidth(double.infinity);
    final loose = BoxConstraints(maxWidth: width);
    final leading = layoutChild(_leading, loose);
    final textStart = Space.small + leading.width + Space.small;
    final sideWidth = _sideWidth;
    final beside = sideWidth <= width * Sizes.rowActionsShare;
    final room = math.max(0.0, width - textStart - Space.small - (beside ? sideWidth + Space.small : 0));
    final words = layoutChild(_words, BoxConstraints.tightFor(width: room));
    final chip = layoutChild(_chip, BoxConstraints(maxWidth: beside ? width : room));
    final actions = _actions == null
        ? Size.zero
        : layoutChild(_actions!, BoxConstraints(maxWidth: math.max(0.0, width - 2 * Space.small)));
    final gap = actions.width > 0 ? Space.small : 0.0;
    if (beside) {
      final height = [
        leading.height + 2 * Space.small,
        words.height + 2 * Space.small,
        chip.height,
        actions.height,
      ].reduce(math.max);
      if (place) {
        _put(_leading, Space.small, (height - leading.height) / 2);
        _put(_words, textStart, (height - words.height) / 2);
        final actionsStart = width - Space.small - actions.width;
        _put(_chip, actionsStart - gap - chip.width, (height - chip.height) / 2);
        if (_actions case final box?) _put(box, actionsStart, (height - actions.height) / 2);
      }
      return constraints.constrain(Size(width, height));
    }
    final block = math.max(leading.height, words.height + chip.height);
    final actionsTop = Space.small + block + Space.small;
    final height = actionsTop + (actions.width > 0 ? actions.height + Space.small : 0);
    if (place) {
      _put(_leading, Space.small, Space.small + (block - leading.height) / 2);
      final wordsTop = Space.small + (block - words.height - chip.height) / 2;
      _put(_words, textStart, wordsTop);
      _put(_chip, textStart, wordsTop + words.height);
      if (_actions case final box?) _put(box, width - Space.small - actions.width, actionsTop);
    }
    return constraints.constrain(Size(width, height));
  }

  void _put(RenderBox child, double dx, double dy) => (child.parentData! as _Slot).offset = Offset(dx, dy);

  /// A child's size at [constraints] from its intrinsic dimensions, for this box's own intrinsic heights.
  static Size _intrinsic(RenderBox child, BoxConstraints constraints) {
    final width = constraints.constrainWidth(child.getMaxIntrinsicWidth(double.infinity));
    return Size(width, constraints.constrainHeight(child.getMaxIntrinsicHeight(width)));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final text = math.max(_words.getMinIntrinsicWidth(double.infinity), _chip.getMinIntrinsicWidth(double.infinity));
    final line = _leading.getMinIntrinsicWidth(double.infinity) + Space.small + text;
    return 2 * Space.small + math.max(line, _actions?.getMinIntrinsicWidth(double.infinity) ?? 0);
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      2 * Space.small +
      _leading.getMaxIntrinsicWidth(double.infinity) +
      Space.small +
      _words.getMaxIntrinsicWidth(double.infinity) +
      Space.small +
      _sideWidth;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _arrange(BoxConstraints(maxWidth: width), _intrinsic, place: false).height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild, place: false);

  @override
  void performLayout() => size = _arrange(constraints, ChildLayoutHelper.layoutChild, place: true);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
