import 'package:flutter/material.dart';

import 'tokens.dart';

/// One searchable row, with its independent item identity retained by its widget key.
typedef FilteredRow = ({String words, Widget child});

/// A list header whose filter stays available while the section is closed.
class FilteredListSection extends StatefulWidget {
  /// Creates a filtered list, optionally collapsible on an item page.
  const FilteredListSection({
    required this.title,
    required this.storageId,
    required this.rows,
    this.collapsible = false,
    this.initiallyOpen = true,
    this.actions = const [],
    this.reveal,
    super.key,
  });

  /// The title shown in the header.
  final String title;

  /// The full list identity used to retain its filter and expansion.
  final String storageId;

  /// The rows and their searchable public words.
  final List<FilteredRow> rows;

  /// Whether this section may be folded shut.
  final bool collapsible;

  /// Whether a new section starts expanded.
  final bool initiallyOpen;

  /// The operations shown beside this list header.
  final List<Widget> actions;

  /// The finder destination that requires this section to open and clear its filter.
  final String? reveal;

  @override
  State<FilteredListSection> createState() => _FilteredListSectionState();
}

class _FilteredListSectionState extends State<FilteredListSection> {
  late final TextEditingController _filter;
  late bool _open;

  @override
  void initState() {
    super.initState();
    final kept = PageStorage.maybeOf(context)?.readState(context, identifier: widget.storageId);
    _filter = TextEditingController(text: kept is (String, bool) ? kept.$1 : '');
    _open = kept is (String, bool) ? kept.$2 : widget.initiallyOpen;
    if (widget.reveal != null) _reveal();
  }

  @override
  void didUpdateWidget(FilteredListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reveal != null && widget.reveal != oldWidget.reveal) _reveal();
  }

  void _reveal() {
    _open = true;
    _filter.clear();
    _keep();
  }

  void _keep() =>
      PageStorage.maybeOf(context)?.writeState(context, (_filter.text, _open), identifier: widget.storageId);

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _filter.text.trim().toLowerCase();
    final shown = widget.rows.where((row) => row.words.toLowerCase().contains(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.normal,
          runSpacing: Space.small,
          children: [
            if (widget.collapsible)
              TextButton.icon(
                key: ValueKey('${widget.storageId}-fold'),
                icon: Icon(_open ? Icons.expand_more : Icons.chevron_right),
                label: Text('${widget.title} (${widget.rows.length})'),
                onPressed: () => setState(() {
                  _open = !_open;
                  _keep();
                }),
              )
            else
              Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(
              width: Sizes.listFilter,
              child: TextField(
                key: ValueKey('${widget.storageId}-filter'),
                controller: _filter,
                decoration: InputDecoration(
                  labelText: 'Filter ${widget.title.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => setState(_keep),
              ),
            ),
            ...widget.actions,
          ],
        ),
        const SizedBox(height: Space.small),
        if (!widget.collapsible || _open) ...[
          for (final row in shown) row.child,
          if (shown.isEmpty)
            Text(widget.rows.isEmpty ? 'No ${widget.title.toLowerCase()} supplied.' : 'Nothing matches.'),
        ],
        const SizedBox(height: Space.normal),
      ],
    );
  }
}
