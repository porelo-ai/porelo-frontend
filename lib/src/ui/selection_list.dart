import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// A keyboard-first list, which is the only kind of list in this interface.
///
/// A pointer selects a row and so do the arrow keys; nothing here is reachable one way only.
/// The list keeps no selection of its own — the selection lives in the model, so closing a
/// detail and coming back finds it exactly where it was.
class SelectionList<T> extends StatefulWidget {
  /// Constructor taking the items and how to identify, draw and choose one.
  const SelectionList({
    required this.items,
    required this.idOf,
    required this.rowOf,
    required this.selected,
    required this.onSelect,
    required this.focusNode,
    required this.emptyMessage,
    this.onActivate,
    super.key,
  });

  /// What to list.
  final List<T> items;

  /// A stable identity per item, used to keep the selection across a redraw.
  final String Function(T item) idOf;

  /// How to draw one row.
  final Widget Function(BuildContext context, T item, bool selected) rowOf;

  /// The selected item's identity, or null.
  final String? selected;

  /// Called when the selection moves.
  final void Function(String id) onSelect;

  /// Called on Return, for a list where a row opens something.
  ///
  /// Return and a named affordance, deliberately not a double tap: an [InkWell] that has both
  /// holds every single tap back until the double-tap timeout has passed, so selecting anything
  /// would lag by a third of a second.
  final void Function(String id)? onActivate;

  /// The pane's focus, owned by the shell so a command can move the keyboard here.
  final FocusNode focusNode;

  /// What to say when there is nothing, which is never the same as a failure.
  final String emptyMessage;

  @override
  State<SelectionList<T>> createState() => _SelectionListState<T>();
}

class _SelectionListState<T> extends State<SelectionList<T>> {
  final _selectedRow = GlobalKey();
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant SelectionList<T> old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _revealSelection();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _selectedRow.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(context, alignment: 0.5, duration: Duration.zero);
    });
  }

  int get _selectedIndex => widget.items.indexWhere((item) => widget.idOf(item) == widget.selected);

  void _move(int by) {
    if (widget.items.isEmpty) return;
    final from = _selectedIndex;
    final to = from < 0 ? (by > 0 ? 0 : widget.items.length - 1) : (from + by).clamp(0, widget.items.length - 1);
    widget.onSelect(widget.idOf(widget.items[to]));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
      case LogicalKeyboardKey.home:
        _move(-widget.items.length);
      case LogicalKeyboardKey.end:
        _move(widget.items.length);
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        final selected = widget.selected;
        final activate = widget.onActivate;
        if (selected == null || activate == null) return KeyEventResult.ignored;
        activate(selected);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Focus(
        focusNode: widget.focusNode,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.loose),
            child: Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKey,
      child: ListView.builder(
        controller: _scroll,
        primary: false,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final id = widget.idOf(item);
          final isSelected = id == widget.selected;
          return InkWell(
            key: isSelected ? _selectedRow : null,
            onTap: () {
              widget.focusNode.requestFocus();
              widget.onSelect(id);
            },
            child: Container(
              // The selection is what a test can see, and what a person can see: one row is
              // marked, and it is the same mark whichever pane it is in.
              key: isSelected ? const Key('selected-row') : null,
              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
              child: widget.rowOf(context, item, isSelected),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}
