import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guided_walk/guided_walk.dart';
import 'package:porelo_frontend/client.dart';

import '../app/conversation.dart';
import '../app/fleet_backend.dart';
import '../app/homeserver_forwards.dart';
import '../app/machines.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Shows [project]'s conversation, who has joined it, and lets a person join.
Future<void> showProjectMessages(BuildContext context,
    {required FleetBackend backend, required Machine machine, required Project project, HomeserverForwards? forwards}) async {
  final conversation = ProjectConversation(backend, machine, project, forwards: forwards);
  unawaited(conversation.load());
  await showDialog<void>(context: context, builder: (_) => MessagesDialog(conversation: conversation));
  conversation.dispose();
}

/// A project's conversation: where it is, whether this machine can carry it, and a way in for a person.
class MessagesDialog extends StatefulWidget {
  /// Constructor taking the conversation.
  const MessagesDialog({required this.conversation, super.key});

  final ProjectConversation conversation;

  @override
  State<MessagesDialog> createState() => _MessagesDialogState();
}

class _MessagesDialogState extends State<MessagesDialog> {
  final TextEditingController _person = TextEditingController();

  @override
  void dispose() {
    _person.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.conversation,
        builder: (context, _) {
          final model = widget.conversation;
          final messages = model.project.messages;
          final text = Theme.of(context).textTheme;
          final scheme = Theme.of(context).colorScheme;
          final members = model.members;
          final joined = model.joined;
          return AlertDialog(
            key: const Key('messages-dialog'),
            title: Text('Messages of ${model.project.name}'),
            content: SizedBox(
              width: Sizes.dialog,
              child: DialogScroll(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (messages != null) ..._where(context, messages),
                    // Joined before: still reachable, and said so, without joining again (walk 10).
                    if (model.joined == null && model.forwarded != null)
                      Text(
                        'A Matrix client here reaches its homeserver at http://127.0.0.1:${model.forwarded}, forwarded while '
                        'this window runs.',
                        key: const Key('homeserver-forwarded'),
                        style: text.bodySmall,
                      ),
                    const SizedBox(height: Space.small),
                    Text('Who has joined', style: text.titleSmall),
                    if (members == null && model.problem == null) const Text('Asking the machine…'),
                    if (members != null && members.isEmpty)
                      const Text('Nobody has joined yet.', key: Key('no-members')),
                    for (final each in members ?? const <MessageMember>[])
                      SelectableText('${each.person}, as ${each.user}',
                          key: ValueKey<String>('member ${each.person}'), style: text.bodySmall),
                    const SizedBox(height: Space.normal),
                    if (joined == null) ...<Widget>[
                      Text('Join it', style: text.titleSmall),
                      Text(
                        'An account is made for the person and invited into the room. Its password is shown '
                        'here once and kept nowhere, here or on the machine.',
                        style: text.bodySmall,
                      ),
                      TextField(
                        key: const Key('join-person'),
                        controller: _person,
                        // Walk 10: the name a person goes by in the chat, not "who".
                        decoration: const InputDecoration(
                          labelText: 'Your name in the chat',
                          helperText: 'A short nickname; your Matrix ID is made from it.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    if (model.problem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.small),
                        child: Text(model.problem!,
                            key: const Key('messages-problem'), style: TextStyle(color: scheme.error)),
                      ),
                    if (joined != null) ..._login(context, model, joined),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              if (joined == null && model.alreadyJoined != null)
                OutlinedButton(
                  key: const Key('join-reset'),
                  onPressed: model.busy ? null : () => unawaited(model.join(model.alreadyJoined!, reset: true)),
                  child: const Text('Give a new password'),
                ),
              if (joined == null)
                FilledButton(
                  key: const Key('join-it'),
                  onPressed: model.busy || _person.text.trim().isEmpty
                      ? null
                      : () => unawaited(model.join(_person.text.trim())),
                  child: const Text('Join'),
                ),
              TextButton(
                key: const Key('messages-close'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(joined == null ? 'Done' : 'Done: the password is not shown again'),
              ),
            ],
          );
        },
      );

  List<Widget> _where(BuildContext context, ProjectMessages messages) {
    final text = Theme.of(context).textTheme;
    final reaches = messages.reaches.isEmpty ? 'nothing said yet' : messages.reaches.join(', ');
    return <Widget>[
      Text('Over ${messages.transport}, reaching $reaches.', key: const Key('messages-where')),
      if (messages.conversation.isNotEmpty)
        SelectableText('Its room: ${messages.conversation}', style: text.bodySmall),
      Text(
        messages.ready
            ? 'This machine can carry its messages now.'
            : messages.detail.isEmpty
                ? 'This machine cannot carry its messages now.'
                : 'This machine cannot carry its messages now: ${messages.detail}',
        key: const Key('messages-ready'),
      ),
      if (messages.loopbackOnly)
        Text('An offline project: its messages stay on this machine, and its conversation with them.',
            style: text.bodySmall),
    ];
  }

  static Widget _secretIf(bool secret, Widget child) => secret ? WalkSecret(child: child) : child;

  List<Widget> _login(BuildContext context, ProjectConversation model, MessagesJoined joined) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final port = joined.port;
    return <Widget>[
      const SizedBox(height: Space.small),
      Text('Their login, shown once', style: text.titleSmall),
      Text('Copy it into their Matrix client now: it is not kept, and seeing it again means a new password.',
          style: text.bodySmall),
      const SizedBox(height: Space.tight),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.small),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Named as a Matrix client names its fields, each copied on its own, since a client asks
            // for them one by one (walk 8: "user" is "Matrix ID" there, and nothing could be copied).
            for (final (field, label) in _loginFields)
              if (joined.login[field] case final value?)
                Row(
                  children: <Widget>[
                    SizedBox(width: Sizes.fieldName, child: Text(label, style: text.bodySmall)),
                    Expanded(
                      // The password reads and writes in the project's room: blanked, and left out
                      // of what a walk writes down.
                      child: _secretIf(
                        field == 'password',
                        SelectableText(value,
                            key: ValueKey<String>('login $field'),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>('login-copy $field'),
                      icon: const Icon(Icons.copy, size: Sizes.rowIcon),
                      tooltip: 'Copy the $label',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: value))),
                    ),
                  ],
                ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('login-copy-all'),
                icon: const Icon(Icons.copy_all, size: Sizes.rowIcon),
                label: const Text('Copy all of it'),
                onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: <String>[
                  for (final (field, label) in _loginFields)
                    if (joined.login[field] case final value?) '$label: $value',
                ].join('\n')))),
              ),
            ),
          ],
        ),
      ),
      if (joined.loopback && port != null) ...<Widget>[
        const SizedBox(height: Space.small),
        Text(
          model.forwarded != null
              ? 'The homeserver is on ${model.machine.name}’s loopback; port $port is forwarded from this '
                  'computer while this window runs, so a Matrix client here reaches it at http://127.0.0.1:$port.'
              : model.forwardProblem ??
                  (model.machine.needsATunnel
                      ? 'Forwarding port $port from ${model.machine.name}…'
                      : 'The homeserver is on this computer, at http://127.0.0.1:$port.'),
          key: const Key('login-forward'),
          style: model.forwardProblem == null ? text.bodySmall : TextStyle(color: scheme.error),
        ),
      ],
    ];
  }
}

/// The login's fields, in the order a Matrix client asks for them, with the names it gives them.
const List<(String, String)> _loginFields = <(String, String)>[
  ('homeserver', 'Homeserver URL'),
  ('user', 'Matrix ID'),
  ('password', 'Password'),
  ('room', 'Room'),
];
