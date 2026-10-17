import 'package:flutter/material.dart';

import 'tokens.dart';

/// The scrolling body of a dialog that holds fields.
///
/// **Room above the first field**, because a floating label rises above its field's box and a
/// scroll view clips at its own top edge. **A scrollbar that is always drawn**, because a dialog
/// taller than the window otherwise gives no sign that anything is below the fold — found when
/// starting work.
class DialogScroll extends StatefulWidget {
  /// Constructor taking what scrolls.
  const DialogScroll({super.key, required this.child, this.controller});

  /// What scrolls.
  final Widget child;

  /// For a dialog that scrolls to what it just said; otherwise one of its own.
  final ScrollController? controller;

  @override
  State<DialogScroll> createState() => _DialogScrollState();
}

class _DialogScrollState extends State<DialogScroll> {
  final _own = ScrollController();

  ScrollController get _position => widget.controller ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    key: const Key('dialog-scrollbar'),
    controller: _position,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _position,
      // The right edge keeps the fields clear of the scrollbar drawn over them.
      padding: const EdgeInsets.only(top: Space.small, right: Space.normal),
      child: widget.child,
    ),
  );
}
