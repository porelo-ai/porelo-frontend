import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/commands.dart';
import 'tokens.dart';

/// The commands one thing offers, as one menu.
///
/// One menu rather than a button each: a row with five actions is wider than the pane, and icons
/// say nothing about what they do. What cannot be run stays in the menu, grayed out, carrying the
/// reason — a row whose actions disappear reads as a row with nothing to offer.
///
/// A command that names a [Command.submenu] stands in that submenu, so a thing with many commands shows the few a
/// person reaches for most and the rest by what they do; a command that names none stands in the menu itself.
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

/// A row in which a right click opens the row's own [CommandMenu], at the pointer.
///
/// The same menu as the row's button, rather than a copy of its entries: its submenus, its following of the view and
/// its guard against another row drawn in its place are then the button's own.
class CommandMenuArea extends StatefulWidget {
  /// Constructor taking the row.
  const CommandMenuArea({required this.child, this.enabled = true, super.key});

  /// The row, holding its menu.
  final Widget child;

  /// Whether a right click opens anything.
  final bool enabled;

  @override
  State<CommandMenuArea> createState() => _CommandMenuAreaState();
}

class _CommandMenuAreaState extends State<CommandMenuArea> {
  _CommandMenuState? _menu;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onSecondaryTapDown: widget.enabled ? (details) => _menu?._openAt(details.globalPosition) : null,
    child: widget.child,
  );
}

/// How a submenu none of whose entries can run is read out.
const _allUnavailable = 'none of its entries can run now';

class _CommandMenuState extends State<CommandMenu> {
  final _controller = MenuController();
  final _anchor = GlobalKey();
  final _button = FocusNode(debugLabel: 'command menu');
  final _first = FocusNode(debugLabel: 'command menu first entry');
  final _marked = FocusNode(debugLabel: 'command menu marked entry');
  final _submenus = <String, MenuController>{};
  _CommandMenuAreaState? _area;
  String? _openedFor;

  /// The entry the open menu was opened on for the finder, which stays marked while it is open, after the finder
  /// has been told.
  String? _marking;
  var _byPointer = false;

  /// What the menu is for: its key and the thing its tooltip names. A list that draws another row in this one's place
  /// keeps this State, and an open menu then offers nothing of that row.
  (Key?, String) get _subject => (widget.key, widget.tooltip);

  /// What the open menu was opened for.
  (Key?, String)? _openedAs;

  /// The entries the open menu was opened with: an entry stays where it was while the menu is open, and one whose
  /// command is gone since is drawn grey.
  List<Command> _opened = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final area = context.findAncestorStateOfType<_CommandMenuAreaState>();
    if (area != _area) {
      if (_area?._menu == this) _area?._menu = null;
      _area = area?.._menu = this;
    }
  }

  @override
  void dispose() {
    if (_area?._menu == this) _area?._menu = null;
    _button.dispose();
    _first.dispose();
    _marked.dispose();
    super.dispose();
  }

  List<Command> get _visible => widget.commands.where((command) => command.visible).toList();

  String? get _mine => _visible.any((command) => command.id == widget.highlight) ? widget.highlight : null;

  /// Opens the menu for the thing it is for now, marking [marking].
  ///
  /// What it opens for is taken after the opening: opening a menu still open closes it first, and that closing
  /// forgets what the open one was for.
  void _openFor({Offset? position, String? marking}) {
    _controller.open(position: position);
    setState(() {
      _openedAs = _subject;
      _opened = _visible;
      _marking = marking;
    });
  }

  void _openAt(Offset global) {
    if (!mounted || !widget.enabled || _visible.isEmpty) return;
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _byPointer = true;
    _openFor(position: box.globalToLocal(global));
  }

  void _toggle() {
    if (_controller.isOpen) return _controller.close();
    _openFor();
  }

  /// Gives the first entry the keyboard only where the keyboard opened the menu: one the pointer opened shows no
  /// entry as focused, so Enter must not press one.
  void _onOpen() {
    final byPointer = _byPointer;
    _byPointer = false;
    if (byPointer) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusFirst();
    });
  }

  /// Gives the keyboard to the menu's first row that takes it.
  void _focusFirst() {
    if (!_controller.isOpen || _first.context == null) return;
    _first.requestFocus();
    // A submenu opens as soon as its row has the keyboard: the keyboard lands on the row, and the person opens it.
    FocusManager.instance.applyFocusChangesIfNeeded();
    for (final submenu in _submenus.values) {
      if (submenu.isOpen) submenu.close();
    }
  }

  void _onClose() {
    // A closing that ends after the menu opened again belongs to the menu that was, not to this one.
    if (!mounted || _controller.isOpen) return;
    setState(() {
      _openedAs = null;
      _opened = const [];
      _marking = null;
    });
  }

  /// Runs [id] as the view offers it now, and only for the thing the menu was opened for.
  void _press((Key?, String)? openedAs, String id) {
    if (!mounted || openedAs != _subject) return;
    for (final command in widget.commands) {
      if (command.id == id && command.visible && command.available) command.run();
    }
  }

  /// Opens the menu on [id], and the submenu that holds it, then marks it: the finder is told only once the person
  /// can see where it went.
  void _openOn(String id) {
    final submenu = _visible.where((command) => command.id == id).firstOrNull?.submenu;
    // A menu closed or turned off meanwhile is not opened again, and the finder is not told of what nobody saw.
    bool stillOpening() => mounted && widget.enabled && _controller.isOpen && _marking == id;
    void mark() {
      if (!stillOpening()) return;
      _marked.requestFocus();
      // Settled now rather than at the end of the frame, so whoever is told finds the entry focused.
      FocusManager.instance.applyFocusChangesIfNeeded();
      widget.onShown?.call();
    }

    void next(VoidCallback then) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => then())
        ..scheduleFrame();
    }

    _byPointer = true;
    // The row is brought into view first: a menu opened on a row scrolled out of sight is opened nowhere a person
    // looks.
    unawaited(Scrollable.ensureVisible(context));
    _openFor(marking: id);
    next(() {
      if (!stillOpening()) return;
      if (submenu == null) return mark();
      _submenus[submenu]?.open();
      next(mark);
    });
  }

  /// The entries as they are drawn now: while open, those it was opened with, each as the view offers it now.
  List<Command> _shown() {
    final openedAs = _openedAs;
    if (openedAs == null) return _visible;
    final now = openedAs == _subject ? _visible : const <Command>[];
    return [
      for (final opened in _opened)
        now.where((each) => each.id == opened.id).firstOrNull ??
            Command(
              id: opened.id,
              label: opened.label,
              group: opened.group,
              home: opened.home,
              danger: opened.danger,
              submenu: opened.submenu,
              checked: opened.checked,
              unavailable: 'no longer offered here',
              run: () {},
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // An open menu stays while it is open, its entries no longer offered, rather than vanishing half-open.
    if (_visible.isEmpty && _openedAs == null) return const SizedBox.shrink();
    final mine = _mine;
    if (widget.enabled && mine != null && mine != _openedFor) {
      _openedFor = mine;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled && _mine == mine) _openOn(mine);
      });
    }
    if (mine == null) _openedFor = null;
    final openedAs = _openedAs;
    var first = true;
    FocusNode? firstOf({required bool focusable}) {
      if (!first || !focusable) return null;
      first = false;
      return _first;
    }

    final marking = _marking;
    Widget entry(Command command, {FocusNode? focusNode}) => _entry(
      context,
      command,
      marked: command.id == marking,
      focusNode: command.id == marking ? _marked : focusNode,
      onPressed: () => _press(openedAs, command.id),
    );

    return MenuAnchor(
      controller: _controller,
      consumeOutsideTap: true,
      crossAxisUnconstrained: false,
      childFocusNode: _button,
      onOpen: _onOpen,
      onClose: _onClose,
      menuChildren: [
        for (final (name, commands) in commandMenuLayout(_shown()))
          if (name == null)
            entry(commands.single, focusNode: firstOf(focusable: commands.single.available))
          else
            _submenu(
              context,
              name,
              commands,
              controller: _submenus.putIfAbsent(name, MenuController.new),
              focusNode: firstOf(focusable: true),
              entries: [for (final command in commands) entry(command)],
            ),
      ],
      builder: (context, controller, _) => Listener(
        key: _anchor,
        onPointerDown: (_) => _byPointer = true,
        // The press's tap, which opens the menu, runs right after its release; a press that opens nothing leaves no
        // mark for the keyboard's next opening.
        onPointerUp: (_) => scheduleMicrotask(() => _byPointer = false),
        onPointerCancel: (_) => _byPointer = false,
        // Whoever opened it, the arrows lead from the button into the open menu, never to the page behind it.
        child: Actions(
          actions: {DirectionalFocusIntent: _IntoTheMenu(this)},
          child: IconButton(
            focusNode: _button,
            tooltip: widget.tooltip,
            icon: const Icon(Icons.more_vert, size: Sizes.rowIcon),
            onPressed: widget.enabled ? _toggle : null,
          ),
        ),
      ),
    );
  }
}

/// An arrow key on the button of an open menu, which gives the keyboard to the menu's first row.
class _IntoTheMenu extends Action<DirectionalFocusIntent> {
  _IntoTheMenu(this._menu);

  final _CommandMenuState _menu;

  @override
  bool isEnabled(DirectionalFocusIntent intent) => _menu.mounted && _menu._controller.isOpen;

  @override
  void invoke(DirectionalFocusIntent intent) => _menu._focusFirst();
}

/// A menu's entries in the order they stand: an entry without a submenu where it comes, a submenu where its name
/// first comes with its entries in their order, and an entry that takes something away last, so it is never pressed
/// in passing. A submenu with nothing offered is left out.
List<(String?, List<Command>)> commandMenuLayout(List<Command> commands) {
  final layout = <(String?, List<Command>)>[];
  final submenus = <String, List<Command>>{};
  final last = <Command>[];
  for (final command in commands.where((command) => command.visible)) {
    final name = command.submenu;
    if (name == null) {
      if (command.danger) {
        last.add(command);
      } else {
        layout.add((null, [command]));
      }
    } else if (submenus[name] case final held?) {
      held.add(command);
    } else {
      final held = [command];
      submenus[name] = held;
      layout.add((name, held));
    }
  }
  return [
    ...layout,
    for (final command in last) (null, [command]),
  ];
}

Widget _entry(
  BuildContext context,
  Command command, {
  required bool marked,
  required VoidCallback onPressed,
  FocusNode? focusNode,
}) {
  final theme = Theme.of(context);
  return MenuItemButton(
    // The finder's destination carries a key of its own, so the way there can be followed.
    key: marked ? const Key('highlighted') : ValueKey<String>(command.id),
    focusNode: focusNode,
    overflowAxis: Axis.vertical,
    onPressed: command.available ? onPressed : null,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Sizes.menuEntry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.tight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              command.label,
              style: command.danger && command.available ? TextStyle(color: theme.colorScheme.error) : null,
            ),
            if (command.unavailable case final reason?)
              // Without a color of its own, so it is drawn as grey as the entry it explains.
              Text('Unavailable: $reason', style: TextStyle(fontSize: theme.textTheme.bodySmall?.fontSize)),
          ],
        ),
      ),
    ),
  );
}

Widget _submenu(
  BuildContext context,
  String name,
  List<Command> commands, {
  required MenuController controller,
  required List<Widget> entries,
  FocusNode? focusNode,
}) {
  // Still opened when nothing in it can run, so each reason can be read where the action is.
  final grey = !commands.any((command) => command.available);
  return SubmenuButton(
    key: Key('submenu $name'),
    controller: controller,
    focusNode: focusNode,
    style: grey ? SubmenuButton.styleFrom(foregroundColor: Theme.of(context).disabledColor) : null,
    menuChildren: entries,
    child: Semantics(hint: grey ? _allUnavailable : null, child: Text(name)),
  );
}
