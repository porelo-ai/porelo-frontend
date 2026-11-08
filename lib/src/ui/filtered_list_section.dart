import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/commands.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart' show ListCardWidth;
import 'tokens.dart';
import 'window_size.dart';
import 'page_explanation.dart';
import 'how_long.dart';

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

/// A list's card: its rows on white in the light theme.
Color listCardColour(ColorScheme colors) =>
    colors.brightness == Brightness.light ? colors.surfaceContainerLowest : colors.surfaceContainerLow;

/// A list's head, pale over the white of its rows in the light theme.
Color listHeadColour(ColorScheme colors) =>
    colors.brightness == Brightness.light ? colors.surfaceContainer : colors.surfaceContainerHighest;

/// A list in a card: its header holds the title and count, a magnifier that opens a small filter, the sort and the list's
/// own buttons; rows stand under it, separated.
class FilteredListSection extends StatefulWidget {
  /// Creates a section, optionally collapsible.
  const FilteredListSection({
    required this.title,
    required this.storageId,
    this.emptyWords,
    required this.rows,
    this.collapsible = true,
    this.initiallyOpen = true,
    this.openWhenCompact = true,
    this.actions = const [],
    this.commands = const [],
    this.drawnCommands = const [],
    this.greyWords = const [],
    this.sorts,
    this.reveal,
    this.search,
    this.searchHint,
    this.leaf = false,
    this.read = true,
    this.titleInAppBar = false,
    this.path = const [],
    this.subtitle,
    this.explanation,
    this.busy = false,
    this.problem,
    this.onRetry,
    this.readAt,
    this.beforeRows = const [],
    this.pathKeys = const {},
    this.titleKey,
    super.key,
  });

  /// Whether the source has answered successfully at least once.
  final bool read;

  /// Whether the app bar already shows this exact title on a phone.
  final bool titleInAppBar;

  /// Uses a page head and a card without a band, for a leaf destination.
  final bool leaf;

  /// Stable targets for the links back to ancestors.
  final Map<String, Key> pathKeys;

  /// An existing automation target for the page title.
  final Key? titleKey;

  /// The ancestors of this page.
  final List<LeafPathStep> path;

  /// Counts the whole list in the page's own words.
  final String? subtitle;

  /// The explanation, shown between the head and the card.
  final Widget? explanation;

  /// Keeps the last rows visible while reading.
  final bool busy;

  /// Public facts that stand after the head and before the list.
  final List<Widget> beforeRows;

  /// The last successful observation, when the source provides it.
  final DateTime? readAt;

  /// A read refusal, never represented as an empty successful list.
  final String? problem;

  /// Reads the list again after a refusal.
  final VoidCallback? onRetry;

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

  /// Whether this section may be folded shut: every list may, unless it says otherwise, so a new page cannot miss it.
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

  /// Why a button of [actions] that holds no command is grey, said under the head with the others.
  final List<String> greyWords;

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
      if (!widget.leaf && !_foldChosen && kept.empty != widget.rows.isEmpty) _open = _opensByItself;
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
    if (widget.leaf) return widget.initiallyOpen;
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
      // A search held by the page and shown for what it holds does not take the keyboard from it.
      autofocus: !widget.leaf && (widget.search == null || _searching),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.searchHint ?? 'Filter ${widget.title.toLowerCase()}',
        prefixIcon: const Icon(Icons.search, size: Sizes.rowIcon),
        suffixIcon: IconButton(
          key: ValueKey('${widget.storageId}-filter-close'),
          tooltip: widget.leaf ? 'Clear the filter' : 'Close the filter',
          icon: const Icon(Icons.close, size: Sizes.rowIcon),
          onPressed: _closeSearch,
        ),
      ),
      onChanged: (_) => setState(_keep),
    );
    final clearable = !widget.leaf
        ? field
        : Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && _filter.text.isNotEmpty) {
                _closeSearch();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: field,
          );
    return width == null ? clearable : SizedBox(width: width, child: clearable);
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
      child: widget.leaf
          ? SizedBox(
              width: target,
              height: target,
              child: const Icon(Icons.sort, size: Sizes.rowIcon),
            )
          : ConstrainedBox(
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
    final button =
        widget.leaf &&
            command ==
                (widget.commands.where((each) => each.visible && each.available).firstOrNull ??
                    widget.commands.where((each) => each.visible).firstOrNull)
        ? FilledButton(
            key: ValueKey(command.id),
            style: FilledButton.styleFrom(minimumSize: Size(target, target)),
            onPressed: command.available ? command.run : null,
            child: Text(command.label),
          )
        : OutlinedButton(
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
        if (PageExplanationScope.of(context) case final scope? when scope.title == widget.title)
          PageExplanationButton(id: scope.id, settings: scope.settings),
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
      if (_searching || _filter.text.isNotEmpty)
        _field(compact ? null : (widget.search == null ? Sizes.listFilter : Sizes.workSearch))
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

  Widget _leaf(List<FilteredRow> shown) {
    final theme = Theme.of(context);
    final scope = PageExplanationScope.of(context);
    final phone = WindowSize.fromContext(context) == WindowSize.compact;
    final target = WindowSize.fromContext(context).showsTwoPanes ? Sizes.leafSort : Sizes.touchTarget;
    final read = howLongSince(widget.readAt);
    final unread = !widget.read || widget.busy && widget.rows.isEmpty;
    final total = widget.problem != null || unread ? 'not read' : widget.subtitle ?? '${widget.rows.length} entries';
    final actions = [
      ...widget.actions,
      for (final command in widget.commands.where((each) => each.visible)) _commandButton(command, target),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.wide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHead(
            title: widget.title,
            titleInAppBar: widget.titleInAppBar,
            path: widget.path,
            pathKeys: widget.pathKeys,
            titleKey: widget.titleKey,
            id: scope?.id,
            settings: scope?.settings,
            subtitle: read == null ? total : '$total · read $read ago',
            subtitleKey: ValueKey('${widget.storageId}-subtitle'),
            controls: Row(
              children: [
                Expanded(child: _field(null)),
                _sortMenu(target),
                if (widget.collapsible) _foldButton(target),
              ],
            ),
            action: actions.isEmpty
                ? null
                : phone
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actions)
                : Wrap(spacing: Space.small, runSpacing: Space.small, children: actions),
          ),
          for (final words in widget.greyWords) Text(words, style: theme.textTheme.bodySmall),
          for (final command in [...widget.commands, ...widget.drawnCommands])
            if (command.visible && !command.available && command.unavailable != null)
              Text(
                '${command.label.replaceAll('…', '')}: ${command.unavailable}',
                key: ValueKey('${widget.storageId}-why ${command.id}'),
                style: theme.textTheme.bodySmall,
              ),
          if (widget.explanation != null)
            widget.explanation!
          else if (scope != null && scope.parts.isNotEmpty)
            PageExplanation(id: scope.id, settings: scope.settings, parts: scope.parts),
          ...widget.beforeRows,
          if (widget.busy) const LinearProgressIndicator(),
          if (!widget.collapsible || _open || widget.problem != null)
            LayoutBuilder(
              builder: (context, constraints) => ListCardWidth(
                width: constraints.maxWidth,
                child: Material(
                  color: listCardColour(theme.colorScheme),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant, width: Space.hairline),
                    borderRadius: BorderRadius.circular(Radii.medium),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.normal),
                    child: Theme(
                      data: theme.copyWith(
                        cardTheme: theme.cardTheme.copyWith(
                          color: Colors.transparent,
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: const RoundedRectangleBorder(),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.problem case final problem?)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: Space.normal),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(problem, style: TextStyle(color: theme.colorScheme.error)),
                                  if (widget.onRetry != null)
                                    TextButton(onPressed: widget.onRetry, child: const Text('Try again')),
                                ],
                              ),
                            ),
                          if (!widget.collapsible || _open)
                            for (final (place, row) in shown.indexed) ...[
                              if (place > 0) const Divider(height: Space.hairline),
                              row.child,
                            ],
                          if ((!widget.collapsible || _open) && shown.isEmpty && widget.problem == null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: Space.normal),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    unread
                                        ? 'not read'
                                        : widget.rows.isEmpty
                                        ? widget.emptyWords ??
                                              'No ${widget.title.toLowerCase().replaceFirst('my ', '')} yet.'
                                        : 'Nothing matches.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (widget.rows.isNotEmpty)
                                    TextButton(onPressed: _closeSearch, child: const Text('Clear the filter')),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _filter.text.trim().toLowerCase();
    final shown = _ordered().where((row) => row.words.toLowerCase().contains(query)).toList();
    final colors = theme.colorScheme;
    if (widget.leaf) return _leaf(shown);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.wide),
      // A Material and not a box: the rows are list tiles, which paint on the nearest Material.
      child: Material(
        color: listCardColour(colors),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant, width: Space.hairline),
          borderRadius: BorderRadius.circular(Radii.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: listHeadColour(colors),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.tight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    // Where a person looks, and not behind a hover.
                    for (final words in widget.greyWords)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.small),
                        child: Text(words, style: theme.textTheme.bodySmall),
                      ),
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
