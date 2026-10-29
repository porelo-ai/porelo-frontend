import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/commands.dart';
import 'tokens.dart';

/// Opens the command finder and answers with what was chosen, or null.
///
/// One finder over the whole product, listing actions that belong to screens which are not
/// open: an action nobody can find is an action nobody has. Unavailable ones are listed with
/// the reason rather than hidden, because "not now, because X" is an answer and silence is not.
Future<Command?> showCommandFinder(BuildContext context, List<Command> commands) => showDialog<Command>(
  context: context,
  builder: (context) => _CommandFinder(commands: commands.where((command) => command.visible).toList()),
);

class _CommandFinder extends StatefulWidget {
  const _CommandFinder({required this.commands});

  final List<Command> commands;

  @override
  State<_CommandFinder> createState() => _CommandFinderState();
}

class _CommandFinderState extends State<_CommandFinder> {
  final _query = TextEditingController();
  final _keyboard = FocusNode();
  int _highlighted = 0;

  List<Command> get _matches {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return widget.commands;
    return widget.commands
        .where((command) => command.label.toLowerCase().contains(query) || command.group.toLowerCase().contains(query))
        .toList();
  }

  void _choose(Command command) {
    if (!command.visible || !command.available) return;
    Navigator.of(context).pop(command);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final matches = _matches;
    if (matches.isEmpty) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _highlighted = (_highlighted + 1) % matches.length);
      case LogicalKeyboardKey.arrowUp:
        setState(() => _highlighted = (_highlighted - 1 + matches.length) % matches.length);
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _choose(matches[_highlighted.clamp(0, matches.length - 1)]);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    if (_highlighted >= matches.length) _highlighted = 0;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: Space.loose, vertical: Sizes.finderInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sizes.finder, maxHeight: Sizes.finderHeight),
        child: Focus(
          focusNode: _keyboard,
          onKeyEvent: _onKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(Space.normal),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'What do you want to do?',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _highlighted = 0),
                  onSubmitted: (_) {
                    if (matches.isNotEmpty) {
                      _choose(matches[_highlighted.clamp(0, matches.length - 1)]);
                    }
                  },
                ),
              ),
              Expanded(
                child: matches.isEmpty
                    ? const Center(child: Text('No command by that name.'))
                    : ListView.builder(
                        key: const Key('command-list'),
                        itemCount: matches.length,
                        itemBuilder: (context, index) => _CommandRow(
                          command: matches[index],
                          highlighted: index == _highlighted,
                          onTap: () => _choose(matches[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    _keyboard.dispose();
    super.dispose();
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.command, required this.highlighted, required this.onTap});

  final Command command;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortcut = command.shortcut;
    return ListTile(
      dense: true,
      enabled: command.available,
      selected: highlighted,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      title: Text(command.label),
      subtitle: Text(command.available ? command.group : '${command.group} · unavailable: ${command.unavailable}'),
      trailing: shortcut == null ? null : Text(describeShortcut(shortcut)),
      onTap: command.available ? onTap : null,
    );
  }
}
