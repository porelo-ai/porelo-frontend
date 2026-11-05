import 'package:flutter/material.dart';

import '../app/commands.dart';
import 'command_menu.dart';
import 'tokens.dart';
import 'window_size.dart';

/// One searchable row, with its independent item identity retained by its widget key.
typedef FilteredRow = ({String words, Widget child});

/// One way a section's rows can stand in order: its name in the menu, and each row's key by its place in `rows`.
class SectionSort {
  /// Constructor taking the name and the key.
  const SectionSort(this.label, this.keyOf);

  /// What the sort menu calls it.
  final String label;

  /// What the row at this place in `rows` sorts by.
  final String Function(int row) keyOf;
}

/// What a section keeps per list while its page comes and goes.
typedef _Kept = ({String filter, bool open, bool chosen, bool empty, bool searching, String? sort, bool descending});

/// A list in a card: its header holds the title and count, a magnifier that opens a small filter, the sort and the list's
/// own buttons; rows stand under it, separated.
class FilteredListSection extends StatefulWidget {
  /// Creates a section, optionally collapsible.
  const FilteredListSection({
    required this.title,
    required this.storageId,
    this.emptyWords,
    required this.rows,
    this.collapsible = false,
    this.initiallyOpen = true,
    this.openWhenCompact = true,
    this.actions = const [],
    this.commands = const [],
    this.drawnCommands = const [],
    this.sorts,
    this.reveal,
    this.search,
    this.searchHint,
    super.key,
  });

  /// A search that is always there, held by whoever else may set it, in place of the magnifier.
  final TextEditingController? search;

  /// What [search] says it searches.
  final String? searchHint;

  /// The title shown in the header.
  final String title;

  /// What it says with nothing in it, where it knows more than that nothing is there.
  final String? emptyWords;

  /// The full list identity used to retain its filter, sort and expansion.
  final String storageId;

  /// The rows and their searchable public words.
  final List<FilteredRow> rows;

  /// Whether this section may be folded shut.
  final bool collapsible;

  /// Whether a new section starts expanded.
  final bool initiallyOpen;

  /// Whether a new section starts expanded in a compact window, as a phone's page opens only its first.
  final bool openWhenCompact;

  /// The operations shown beside this list header.
  final List<Widget> actions;

  /// What adds to this list: buttons in the header, and behind a menu where a phone has no room for them.
  final List<Command> commands;

  /// The commands [actions] draws itself: why one cannot run is said under the head like any of [commands].
  final List<Command> drawnCommands;

  /// The orders offered, the first being the one it starts in. Left out, a row's words give the one order, *Name*.
  final List<SectionSort>? sorts;

  /// The finder destination that requires this section to open and clear its filter.
  final String? reveal;

  @override
  State<FilteredListSection> createState() => _FilteredListSectionState();
}

class _FilteredListSectionState extends State<FilteredListSection> {
  late final TextEditingController _filter;
  final _filterFocus = FocusNode();
  late bool _open;

  /// Whether the person folded or opened it themselves; then the window leaves it be.
  bool _foldChosen = false;
  late bool _searching;
  String? _sort;
  bool _descending = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final kept = PageStorage.maybeOf(context)?.readState(context, identifier: widget.storageId);
    final held = widget.search;
    if (held != null) held.addListener(_searched);
    if (kept is _Kept) {
      _filter = held ?? TextEditingController(text: kept.filter);
      _open = kept.open;
      _foldChosen = kept.chosen;
      if (!_foldChosen && kept.empty != widget.rows.isEmpty) _open = _opensByItself;
      _searching = kept.searching;
      _sort = kept.sort;
      _descending = kept.descending;
    } else {
      _filter = held ?? TextEditingController();
      _open = _opensByItself;
      _searching = false;
    }
    if (widget.reveal != null) _reveal();
  }

  @override
  void didUpdateWidget(FilteredListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reveal != null && widget.reveal != oldWidget.reveal) _reveal();
    if (!_foldChosen && oldWidget.rows.isEmpty != widget.rows.isEmpty) {
      _open = _opensByItself;
      _keep();
    }
  }

  /// What it does unasked: open, where it holds something and neither the page nor a narrow window says not.
  bool get _opensByItself {
    final compact = WindowSize.fromContext(context) == WindowSize.compact;
    return widget.initiallyOpen && (widget.openWhenCompact || !compact) && widget.rows.isNotEmpty;
  }

  void _searched() {
    if (mounted) setState(() {});
  }

  void _reveal() {
    _open = true;
    _foldChosen = true;
    _filter.clear();
    _searching = false;
    _keep();
  }

  void _keep() => PageStorage.maybeOf(context)?.writeState(context, (
    filter: _filter.text,
    open: _open,
    chosen: _foldChosen,
    empty: widget.rows.isEmpty,
    searching: _searching,
    sort: _sort,
    descending: _descending,
  ), identifier: widget.storageId);

  List<SectionSort> get _sorts => widget.sorts ?? [SectionSort('Name', (row) => widget.rows[row].words)];

  /// The chosen order, or the first where the chosen one is no longer offered.
  SectionSort get _sorting => _sorts.firstWhere((each) => each.label == _sort, orElse: () => _sorts.first);

  void _choose(String label) => setState(() {
    if (label == _sorting.label) {
      _descending = !_descending;
    } else {
      _sort = label;
      _descending = false;
    }
    _keep();
  });

  /// The rows in the chosen order, those of one key staying in the order they came.
  List<FilteredRow> _ordered() {
    final keyOf = _sorting.keyOf;
    final places = [for (var place = 0; place < widget.rows.length; place++) place];
    final keys = [for (final place in places) keyOf(place).toLowerCase()];
    places.sort((a, b) {
      final order = keys[a].compareTo(keys[b]);
      return order != 0 ? (_descending ? -order : order) : a.compareTo(b);
    });
    return [for (final place in places) widget.rows[place]];
  }

  void _closeSearch() => setState(() {
    _searching = false;
    _filter.clear();
    _keep();
  });

  @override
  void dispose() {
    final held = widget.search;
    if (held == null) {
      _filter.dispose();
    } else {
      held.removeListener(_searched);
    }
    _filterFocus.dispose();
    super.dispose();
  }

  Widget _field(double? width) {
    final field = TextField(
      key: ValueKey('${widget.storageId}-filter'),
      controller: _filter,
      focusNode: _filterFocus,
      // A search that is always there does not take the keyboard from the page by being drawn.
      autofocus: widget.search == null,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.searchHint ?? 'Filter ${widget.title.toLowerCase()}',
        prefixIcon: const Icon(Icons.search, size: Sizes.rowIcon),
        suffixIcon: widget.search != null
            ? null
            : IconButton(
                key: ValueKey('${widget.storageId}-filter-close'),
                tooltip: 'Close the filter',
                icon: const Icon(Icons.close, size: Sizes.rowIcon),
                onPressed: _closeSearch,
              ),
      ),
      onChanged: (_) => setState(_keep),
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }

  Widget _magnifier(double target) => IconButton(
    key: ValueKey('${widget.storageId}-search'),
    tooltip: 'Filter ${widget.title.toLowerCase()}',
    constraints: BoxConstraints(minWidth: target, minHeight: target),
    icon: const Icon(Icons.search, size: Sizes.rowIcon),
    onPressed: () => setState(() {
      _searching = true;
      _keep();
    }),
  );

  Widget _sortMenu(double target) {
    final colors = Theme.of(context).colorScheme;
    final current = _sorting.label;
    return PopupMenuButton<String>(
      key: ValueKey('${widget.storageId}-sort'),
      tooltip: 'Sort ${widget.title.toLowerCase()}',
      onSelected: _choose,
      itemBuilder: (context) => [
        for (final sort in _sorts)
          PopupMenuItem<String>(
            key: ValueKey('${widget.storageId}-sort ${sort.label}'),
            value: sort.label,
            child: Text(sort.label),
          ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.small),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _descending ? Icons.arrow_downward : Icons.arrow_upward,
                size: Sizes.rowIcon,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: Space.tight),
              Text(current, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _foldButton(double target) => IconButton(
    key: ValueKey('${widget.storageId}-fold'),
    tooltip: _open ? 'Fold ${widget.title.toLowerCase()}' : 'Open ${widget.title.toLowerCase()}',
    constraints: BoxConstraints(minWidth: target, minHeight: target),
    icon: Icon(_open ? Icons.expand_more : Icons.chevron_right),
    onPressed: () => setState(() {
      _open = !_open;
      _foldChosen = true;
      _keep();
    }),
  );

  Widget _commandButton(Command command, double target) {
    final button = OutlinedButton(
      key: ValueKey(command.id),
      style: OutlinedButton.styleFrom(minimumSize: Size(target, target)),
      onPressed: command.available ? command.run : null,
      child: Text(command.label),
    );
    final why = command.unavailable;
    return why == null ? button : Tooltip(message: why, child: button);
  }

  Widget _heading() {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(widget.title, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: Space.small),
        DecoratedBox(
          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(Radii.small)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.small),
            child: Text('${widget.rows.length}', style: theme.textTheme.bodySmall),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final size = WindowSize.fromContext(context);
    final compact = size == WindowSize.compact;
    final target = size.showsTwoPanes ? Sizes.iconTarget : Sizes.touchTarget;
    final tools = [
      if (widget.search != null)
        _field(compact ? null : Sizes.workSearch)
      else if (_searching || _filter.text.isNotEmpty)
        _field(compact ? null : Sizes.listFilter)
      else
        _magnifier(target),
      _sortMenu(target),
    ];
    final fold = widget.collapsible ? _foldButton(target) : null;
    final commands = widget.commands.where((command) => command.visible).toList();
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _heading()),
              if (commands.isNotEmpty)
                CommandMenu(
                  key: ValueKey('${widget.storageId}-commands'),
                  commands: commands,
                  tooltip: 'What can be added to ${widget.title.toLowerCase()}',
                ),
              ?fold,
            ],
          ),
          Row(
            children: [for (final tool in tools) tool is SizedBox || tool is TextField ? Expanded(child: tool) : tool],
          ),
          if (widget.actions.isNotEmpty) Wrap(spacing: Space.small, runSpacing: Space.small, children: widget.actions),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.normal,
      runSpacing: Space.small,
      children: [
        _heading(),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.small,
          runSpacing: Space.small,
          children: [
            ...tools,
            ...widget.actions,
            for (final command in commands) _commandButton(command, target),
            ?fold,
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _filter.text.trim().toLowerCase();
    final shown = _ordered().where((row) => row.words.toLowerCase().contains(query)).toList();
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.wide),
      // A Material and not a box: the rows are list tiles, which paint on the nearest Material.
      child: Material(
        color: colors.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant, width: Space.hairline),
          borderRadius: BorderRadius.circular(Radii.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.tight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    // Where a person looks, and not behind a hover.
                    for (final command in [...widget.commands, ...widget.drawnCommands])
                      if (command.visible && !command.available && command.unavailable != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.small),
                          child: Text(
                            '${command.label.replaceAll('…', '')}: ${command.unavailable}',
                            key: ValueKey('${widget.storageId}-why ${command.id}'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                  ],
                ),
              ),
            ),
            if (!widget.collapsible || _open)
              Theme(
                // A row that draws itself as a card is a row here: the section is the card.
                data: theme.copyWith(
                  cardTheme: theme.cardTheme.copyWith(
                    color: Colors.transparent,
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.normal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (place, row) in shown.indexed) ...[
                        if (place > 0) const Divider(height: Space.hairline),
                        row.child,
                      ],
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.normal),
                          child: Text(
                            widget.rows.isEmpty
                                ? (widget.emptyWords ?? 'No ${widget.title.toLowerCase().replaceFirst('my ', '')} yet.')
                                : 'Nothing matches.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
