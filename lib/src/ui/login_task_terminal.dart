import 'package:flutter/material.dart';

import '../app/machines.dart';
import '../app/session.dart';
import 'session_view.dart';
import 'tokens.dart';

/// Opens the terminal of the login task [task] on [machine], over whatever is open, through [sessions] as any
/// task's (beside the one of *Running*, which it never takes): the person follows the link there and pastes the code there, never into this program.
///
/// Closing it leaves the terminal only: **the login task goes on**, and what waits on it goes on waiting.
Future<void> openTheLoginTask(
  BuildContext context, {
  required Sessions sessions,
  required Machine machine,
  required String task,
}) async {
  final session = sessions.openBeside(task, machine);
  final keyboard = FocusNode(debugLabel: 'the login task’s terminal');
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: const Key('login-task-terminal'),
        title: Text('Sign in, in $task on ${machine.name}'),
        content: SizedBox(
          width: Sizes.dialog,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.small,
            children: <Widget>[
              const Text(
                'Follow the link the terminal shows, sign in in your browser, and paste the code it gives you '
                'here, in the terminal. It goes straight to the machine and never through this program.',
              ),
              SizedBox(
                height: Sizes.loginTerminal,
                child: SessionView(session: session, focusNode: keyboard),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('login-task-terminal-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close the terminal'),
          ),
        ],
      ),
    );
  } finally {
    keyboard.dispose();
    // Only this way in: the login task itself goes on, as any task does when its terminal is left.
    await sessions.leaveBeside(session);
  }
}
