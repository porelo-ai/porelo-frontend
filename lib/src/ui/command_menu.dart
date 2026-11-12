import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/commands.dart';
import 'tokens.dart';

/// The commands one thing offers, as one menu.
///
/// One menu rather than a button each: a row with five actions is wider than the pane, and icons
/// say nothing about what they do. What cannot be run stays in the menu, grayed out, carrying the
/// reason — a row whose actions disappear reads as a row with nothing to offer.
class CommandMenu extends StatefulWidget {
  /// Constructor taking what to offer and what to say it is for.
  const CommandMenu({
    required this.commands,
    required this.tooltip,
    this.highlight,
    this.onShown,
    this.enabled = true,
    super.key,
  });

  /// Whether this menu may be opened; historical rows keep it disabled.
  final bool enabled;

  /// What this thing can do, runnable or not.
  final List<Command> commands;

  /// What the button says it is for.
  final String tooltip;

  /// The command the finder went to. When it is one of these, the menu opens with it marked.
  final String? highlight;

  /// Called once the menu has opened on [highlight].
  final VoidCallback? onShown;

  @override
  State<CommandMenu> createState() => _CommandMenuState();
}

class _CommandMenuState extends State<CommandMenu> {
  final _button = GlobalKey<PopupMenuButtonState<String>>();
  String? _openedFor;

  /// The commands as the view offers them now, which an open menu's entries follow: a read that ends or
  /// a change that begins while it is open turns an entry runnable or grey without opening it again.
  late final ValueNotifier<List<Command>> _now = ValueNotifier<List<Command>>(widget.commands);

  @override
  void didUpdateWidget(CommandMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    final commands = widget.commands;
    // The open menu is another route: it is told after this frame's build, never during it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _now.value = commands;
    });
  }

  @override
  void dispose() {
    _now.dispose();
    super.dispose();
  }

  String? get _mine =>
      widget.commands.any((command) => command.visible && command.id == widget.highlight) ? widget.highlight : null;

  @override
  Widget build(BuildContext context) {
    if (!widget.commands.any((command) => command.visible)) return const SizedBox.shrink();
    final mine = _mine;
    if (widget.enabled && mine != null && mine != _openedFor) {
      _openedFor = mine;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _button.currentState?.showButtonMenu();
        widget.onShown?.call();
      });
    }
    if (mine == null) _openedFor = null;
    return PopupMenuButton<String>(
      key: _button,
      enabled: widget.enabled,
      tooltip: widget.tooltip,
      icon: const Icon(Icons.more_vert, size: Sizes.rowIcon),
      initialValue: mine,
      onSelected: (id) => _run(widget.commands, id),
      itemBuilder: (context) => commandMenuEntries(context, widget.commands, highlight: mine, following: _now),
    );
  }
}

void _run(List<Command> commands, String id) {
  for (final command in commands) {
    if (command.id == id && command.visible && command.available) command.run();
  }
}

/// The entries of a command menu, so a button and a right-click offer the same list.
///
/// With [following], each entry is drawn from the commands it holds now, while the menu is open; an entry
/// whose command is gone since is drawn grey and runs nothing.
List<PopupMenuEntry<String>> commandMenuEntries(
  BuildContext context,
  List<Command> commands, {
  String? highlight,
  ValueListenable<List<Command>>? following,
}) => <PopupMenuEntry<String>>[
  for (final command in commands.where((command) => command.visible))
    if (following == null)
      _entry(context, command, highlight: highlight)
    else
      _FollowingEntry(opened: command, highlight: highlight, following: following),
];

PopupMenuItem<String> _entry(BuildContext context, Command command, {String? highlight}) => PopupMenuItem<String>(
  // The finder's destination carries a key of its own, so the way there can be followed.
  key: command.id == highlight ? const Key('highlighted') : ValueKey<String>(command.id),
  value: command.id,
  enabled: command.available,
  child: ListTile(
    dense: true,
    enabled: command.available,
    contentPadding: EdgeInsets.zero,
    title: Text(
      command.label,
      style: command.danger && command.available ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
    ),
    subtitle: command.available ? null : Text('Unavailable: ${command.unavailable}'),
  ),
);

/// One entry of an open menu, redrawn from its command as the view offers it now.
class _FollowingEntry extends PopupMenuEntry<String> {
  const _FollowingEntry({required this.opened, required this.following, this.highlight});

  /// The command as it was when the menu opened.
  final Command opened;

  /// The command the finder went to, whose entry is marked.
  final String? highlight;

  /// The view's commands now.
  final ValueListenable<List<Command>> following;

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(String? value) => value == opened.id;

  @override
  State<_FollowingEntry> createState() => _FollowingEntryState();
}

class _FollowingEntryState extends State<_FollowingEntry> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Command>>(
    valueListenable: widget.following,
    builder: (context, commands, _) {
      final now = commands.where((each) => each.id == widget.opened.id && each.visible).firstOrNull;
      return _entry(
        context,
        now ??
            Command(
              id: widget.opened.id,
              label: widget.opened.label,
              group: widget.opened.group,
              home: widget.opened.home,
              unavailable: 'no longer offered here',
              run: () {},
            ),
        highlight: widget.highlight,
      );
    },
  );
}

/// Opens a command menu where the pointer is, and runs what is chosen.
Future<void> showCommandMenu(BuildContext context, Offset at, List<Command> commands) async {
  final visible = commands.where((command) => command.visible).toList();
  if (visible.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final chosen = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
    items: commandMenuEntries(context, visible),
  );
  if (chosen != null) _run(commands, chosen);
}
