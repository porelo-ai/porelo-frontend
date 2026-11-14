import 'package:flutter/material.dart';

import 'terminal_look.dart';
import 'tokens.dart';

/// An output that grows, such as a machine's Prepare protocol, kept at its last line as a terminal keeps it.
///
/// While the person has not scrolled up, the last line stands at the bottom. Scrolling up stops that, and *Following*
/// says it is off, so new lines do not pull them away from what they read; scrolling back to the end, or turning
/// *Following* on, follows again.
class FollowingOutput extends StatefulWidget {
  /// Constructor taking the output as it stands now.
  const FollowingOutput({required this.text, this.waitingForFirstLine = false, super.key});

  /// Everything written so far.
  final String text;

  /// Whether the run goes on and has said no line yet.
  final bool waitingForFirstLine;

  @override
  State<FollowingOutput> createState() => _FollowingOutputState();
}

class _FollowingOutputState extends State<FollowingOutput> {
  final _scroll = ScrollController();
  bool _following = true;

  /// What stands in the pane: while the person has part of it selected, the output as it stood then, so neither the
  /// selection nor the view moves under them; the lines written since come once the selection is let go.
  late String _shown = widget.text;
  bool _selecting = false;

  /// How near the end still counts as at it: a line's part, so a wheel's last notch that stops short still follows.
  static const _atTheEnd = Space.small;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_moved);
    _toTheEnd();
  }

  @override
  void didUpdateWidget(FollowingOutput old) {
    super.didUpdateWidget(old);
    if (_selecting || old.text == widget.text) return;
    _shown = widget.text;
    if (_following) _toTheEnd();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_moved)
      ..dispose();
    super.dispose();
  }

  /// Only a move changes whether it follows: lines added below move nothing, so they never turn it off.
  void _moved() {
    final at = _scroll.position;
    final following = at.pixels >= at.maxScrollExtent - _atTheEnd;
    if (following != _following) setState(() => _following = following);
  }

  void _toTheEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_following || _selecting) return;
      final at = _scroll.position;
      if (at.pixels != at.maxScrollExtent) _scroll.jumpTo(at.maxScrollExtent);
    });
  }

  void _selected(TextSelection selection, SelectionChangedCause? cause) {
    final selecting = !selection.isCollapsed;
    if (selecting == _selecting) return;
    _selecting = selecting;
    if (!selecting && _shown != widget.text) {
      setState(() => _shown = widget.text);
      _toTheEnd();
    }
  }

  void _follow(bool on) {
    setState(() => _following = on);
    if (on) _toTheEnd();
  }

  @override
  Widget build(BuildContext context) {
    const console = TerminalLook.screen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: _following
                ? 'The last line stays at the bottom. Scroll up to read, and it stops following.'
                : 'New lines are added below without moving what you read. Turn it on to go to the last line.',
            child: FilterChip(
              key: const Key('following-output.following'),
              label: const Text('Following'),
              selected: _following,
              visualDensity: VisualDensity.compact,
              onSelected: _follow,
            ),
          ),
        ),
        const SizedBox(height: Space.tight),
        SizedBox(
          key: const Key('following-output'),
          height: Sizes.followingOutput,
          child: DecoratedBox(
            decoration: BoxDecoration(color: console.background, borderRadius: BorderRadius.circular(Radii.small)),
            child: Scrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(Space.small),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_shown.isNotEmpty)
                      SelectableText(_shown, style: TerminalLook.textOf(context), onSelectionChanged: _selected),
                    // A pane that stays black reads as stuck; this says the run goes on and has said nothing yet.
                    if (widget.waitingForFirstLine)
                      Text(
                        'Waiting for the first line',
                        key: const Key('following-output.waiting'),
                        style: TerminalLook.textOf(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
