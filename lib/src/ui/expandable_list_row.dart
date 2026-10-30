import 'package:flutter/material.dart';

import '../app/commands.dart';
import 'tokens.dart';
import 'window_size.dart';

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
    super.key,
  });

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
    final text = Theme.of(context).textTheme;
    final compact = WindowSize.fromContext(context) == WindowSize.compact;
    final disclosure = listDisclosureCommand(expanded: _expanded, toggle: () => setState(() => _expanded = !_expanded));
    final primary = widget.primary?.visible == true ? widget.primary : null;
    return Semantics(
      selected: widget.selected,
      child: Card(
        child: KeyedSubtree(
          key: widget.bodyKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: Sizes.listRowHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: widget.onOpen,
                        child: SizedBox(
                          height: Sizes.listRowHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.small),
                            child: Row(
                              children: [
                                widget.leading,
                                const SizedBox(width: Space.small),
                                Expanded(
                                  flex: 2,
                                  child: Tooltip(
                                    message: widget.title,
                                    child: Text(
                                      widget.title,
                                      key: widget.titleKey,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.titleSmall,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Space.small),
                                Flexible(
                                  child: Tooltip(
                                    message: widget.state,
                                    child: Text(
                                      widget.state,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.labelSmall,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (primary != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: compact ? Sizes.listActionCompact : Sizes.listAction),
                        child: Tooltip(
                          message: primary.unavailable ?? primary.label,
                          child: TextButton(
                            key: widget.primaryKey,
                            onPressed: primary.available ? primary.run : null,
                            child: Text(primary.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: disclosure.label,
                      icon: Icon(_expanded ? Icons.expand_more : Icons.chevron_right),
                      onPressed: disclosure.run,
                    ),
                  ],
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.all(Space.normal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (primary?.unavailable case final reason?) Text('${primary!.label}: $reason'),
                      widget.details,
                    ],
                  ),
                ),
            ],
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
    this.titleKey,
    this.selected = false,
    super.key,
  });

  /// The title shown in the header.
  final String title;

  /// The source states and public information on this row.
  final String subtitle;

  /// The outlined mark for this item.
  final Widget leading;

  /// Opens this exact item.
  final VoidCallback? onOpen;

  /// The operations always reachable beside the row.
  final Widget menu;

  /// The navigation target used by pointer automation.
  final Key? bodyKey;

  /// The title target used by pointer automation.
  final Key? titleKey;

  /// Whether this exact item is selected.
  final bool selected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        key: bodyKey,
        selected: selected,
        leading: leading,
        title: Text(title, key: titleKey, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: menu,
        onTap: onOpen,
      ),
      const Divider(height: Sizes.divider),
    ],
  );
}
