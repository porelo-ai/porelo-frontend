import 'dart:async';

import 'package:flutter/material.dart';

import '../app/links.dart';
import '../app/session.dart';
import 'tokens.dart';

/// The web addresses a terminal's program marked as links, each to be opened here with a press —
/// **never on its own**: whoever writes to a terminal would otherwise choose where the browser goes.
class TerminalLinks extends StatelessWidget {
  /// Constructor taking the session whose links these are.
  const TerminalLinks({super.key, required this.session});

  /// The session whose links these are.
  final Session session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => session.links.isEmpty && session.forwarded == null && session.forwardProblem == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: Space.small),
            child: Wrap(
              spacing: Space.small,
              runSpacing: Space.tight,
              children: <Widget>[
                if (session.forwarded case final port?)
                  Text(
                    'The login’s reply is forwarded from port $port here to ${session.machine.name}, '
                    'while this terminal is open.',
                    key: const Key('login-reply-forwarded'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (session.forwardProblem case final problem?)
                  Text(
                    problem,
                    key: const Key('login-reply-refused'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                // The login's own page first, as the one to press; any other link below it, still
                // offered, because an agent without a redirect needs its own.
                for (final link in <TerminalLink>[
                  ...session.links.where((each) => each.isTheLogin),
                  ...session.links.where((each) => !each.isTheLogin),
                ])
                  // A login's terminal forwards its reply to this computer, so a loopback link there
                  // may well open; in a task's terminal it would open this computer's, not the task's.
                  if (!link.isTheLogin && !session.forwardsALoginReply && link.onlyInsideTheTask)
                    Text(
                      '${link.address.host}${link.address.path}: only reachable inside the task',
                      key: ValueKey<String>('terminal-link-inside ${link.address}'),
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Tooltip(
                      message: '${link.address}',
                      child: link.isTheLogin
                          ? FilledButton.icon(
                              key: ValueKey<String>('terminal-link ${link.address}'),
                              onPressed: () => unawaited(openLink(link.address)),
                              icon: const Icon(Icons.login, size: Sizes.rowIcon),
                              label: const Text('Sign in: the reply comes back here'),
                            )
                          : OutlinedButton.icon(
                              key: ValueKey<String>('terminal-link ${link.address}'),
                              onPressed: () => unawaited(openLink(link.address)),
                              icon: const Icon(Icons.open_in_new, size: Sizes.rowIcon),
                              label: Text(
                                session.links.any((each) => each.isTheLogin)
                                    ? 'Another link the program printed: ${link.address.host}${link.address.path}'
                                    : 'Open ${link.address.host}${link.address.path} in your browser',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
              ],
            ),
          ),
  );
}
