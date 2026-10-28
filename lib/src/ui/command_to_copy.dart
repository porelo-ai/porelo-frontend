import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// A command the person runs in a terminal of their own, in a box of its own with a button that copies it.
///
/// Copyable rather than only readable: it is going to be typed into a terminal, and retyping it from a screen is
/// how a command ends up almost right.
class CommandToCopy extends StatelessWidget {
  /// Constructor taking the command and the key its text goes by.
  const CommandToCopy({required this.command, this.textKey, super.key});

  /// The command, exactly as it is to be run.
  final String command;

  /// The key of the command's text, where a test or a walk names it.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.tight, Space.small),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              command,
              key: textKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: Sizes.rowIcon),
            tooltip: 'Copy the command',
            onPressed: () => Clipboard.setData(ClipboardData(text: command)),
          ),
        ],
      ),
    );
  }
}
