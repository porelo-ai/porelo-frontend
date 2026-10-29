import 'package:flutter/material.dart';

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
      itemBuilder: (context) => commandMenuEntries(widget.commands, highlight: mine),
    );
  }
}

void _run(List<Command> commands, String id) {
  for (final command in commands) {
    if (command.id == id && command.visible && command.available) command.run();
  }
}

/// The entries of a command menu, so a button and a right-click offer the same list.
List<PopupMenuEntry<String>> commandMenuEntries(List<Command> commands, {String? highlight}) =>
    <PopupMenuEntry<String>>[
      for (final command in commands.where((command) => command.visible))
        PopupMenuItem<String>(
          // The finder's destination carries a key of its own, so the way there can be followed.
          key: command.id == highlight ? const Key('highlighted') : ValueKey<String>(command.id),
          value: command.id,
          enabled: command.available,
          child: ListTile(
            dense: true,
            enabled: command.available,
            contentPadding: EdgeInsets.zero,
            title: Text(command.label),
            subtitle: command.available ? null : Text('Unavailable: ${command.unavailable}'),
          ),
        ),
    ];

/// Opens a command menu where the pointer is, and runs what is chosen.
Future<void> showCommandMenu(BuildContext context, Offset at, List<Command> commands) async {
  final visible = commands.where((command) => command.visible).toList();
  if (visible.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final chosen = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
    items: commandMenuEntries(visible),
  );
  if (chosen != null) _run(commands, chosen);
}
