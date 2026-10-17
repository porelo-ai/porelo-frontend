import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_backend.dart';
import '../app/mailboxes.dart';
import '../app/task_peers.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Shows whom [task] may talk to, and lets a person moderate each peer and write to it.
Future<void> showPeers(
  BuildContext context, {
  required FleetBackend backend,
  required Task task,
  Mailboxes? mailboxes,
  Set<String> sameProject = const <String>{},
}) => showDialog<void>(
  context: context,
  builder: (_) => PeersDialog(peers: TaskPeers(backend, task)..load(), mailboxes: mailboxes, sameProject: sameProject),
);

/// Whom one task may talk to, how each is moderated, and a way to write to one.
class PeersDialog extends StatefulWidget {
  /// Constructor taking the task's peers.
  const PeersDialog({required this.peers, this.mailboxes, this.sameProject = const <String>{}, super.key});

  /// Every task of the same project on this machine, the task itself included, for following what
  /// happens to the project's messages rather than the one task's.
  final Set<String> sameProject;

  /// The task's peers, asked of the machine.
  final TaskPeers peers;

  /// The machine's mailboxes, whose stream says what happened to the task's messages.
  final Mailboxes? mailboxes;

  @override
  State<PeersDialog> createState() => _PeersDialogState();
}

class _PeersDialogState extends State<PeersDialog> {
  /// Whether what happened is followed for every task of the project rather than this one.
  bool _wholeProject = false;

  @override
  void dispose() {
    widget.peers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(<Listenable?>[widget.peers, widget.mailboxes]),
    builder: (context, _) {
      final model = widget.peers;
      final peers = model.peers;
      final text = Theme.of(context).textTheme;
      return AlertDialog(
        key: const Key('peers-dialog'),
        title: Text('Holding the messages of ${model.task.project}'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Whom work may write to, and how much is asked first, is the project's, set once in
                // its project.yml: here is only the brake.
                Text(
                  'Whom work of ${model.task.project} may write to, and how much is asked first, is set in '
                  "the project's project.yml, in its repository. Here a peer can be held: nothing "
                  'goes to it until a person releases it, or until holding is off again.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: Space.tight),
                // A peer's hold is the project's, not one task's.
                Text(
                  'Holding applies to every task of ${model.task.project}, including one started later.',
                  key: const Key('moderation-scope'),
                  style: text.bodySmall,
                ),
                const SizedBox(height: Space.small),
                if (model.problem != null)
                  Text(
                    model.problem!,
                    key: const Key('peers-problem'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                if (peers == null && model.problem == null) const Text('Asking the machine…'),
                if (peers != null && peers.isEmpty && model.problem == null)
                  const Text('Its project names no peers, so it may talk to nobody.', key: Key('no-peers')),
                for (final peer in peers ?? const <TalkPeer>[]) _peer(context, peer),
                if (model.said != null)
                  Text(
                    model.said!,
                    key: const Key('said'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (widget.mailboxes case final mailboxes?)
                  ..._happened(
                    context,
                    _wholeProject
                        ? mailboxes.eventsOfAny(<String>{model.task.name, ...widget.sameProject})
                        : mailboxes.eventsOf(model.task.name),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('peers-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );

  Widget _peer(BuildContext context, TalkPeer peer) {
    final model = widget.peers;
    final text = Theme.of(context).textTheme;
    return Card(
      key: ValueKey<String>('peer ${peer.name}'),
      child: Padding(
        padding: const EdgeInsets.all(Space.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(peer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            // Who it is, where the address alone says nothing to a person: "Written to alice" read
            // as writing to oneself (walk 8).
            if (_who(peer) case final who?) Text(who, key: ValueKey<String>('peer-who ${peer.name}')),
            SelectableText(peer.address, style: text.bodySmall),
            if (widget.mailboxes?.waitingWith(model.task.name, peer.name) case final waiting? when waiting > 0)
              Text(
                waiting == 1
                    ? 'One message with it waits for a person now, in what needs you.'
                    : '$waiting messages with it wait for a person now, in what needs you.',
                key: ValueKey<String>('peer-waiting ${peer.name}'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: Space.small),
            SwitchListTile(
              key: ValueKey<String>('peer-held ${peer.name}'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Hold everything for it'),
              subtitle: const Text(
                'Nothing goes to it unless a person releases it, or until this is off '
                'again.',
              ),
              value: peer.held,
              onChanged: model.busy ? null : (held) => unawaited(model.setHeld(peer, held)),
            ),
          ],
        ),
      ),
    );
  }

  /// What happened to the task's messages, as the machine streams it: **never what they said**.
  List<Widget> _happened(BuildContext context, List<TalkEvent> events) {
    final text = Theme.of(context).textTheme;
    return <Widget>[
      const SizedBox(height: Space.normal),
      Text('What happened to its messages', style: text.titleSmall),
      Text('Since this interface connected; the machine does not stream what came before.', style: text.bodySmall),
      SwitchListTile(
        key: const Key('talk-whole-project'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text('For every task of ${widget.peers.task.project}, not only this one'),
        value: _wholeProject,
        onChanged: (whole) => setState(() => _wholeProject = whole),
      ),
      const SizedBox(height: Space.tight),
      if (events.isEmpty) const Text('Nothing yet.', key: Key('no-talk-events')),
      // A message that could not go is said as that, in the error's colour: a release that failed
      // at sending showed only as the same message held again (walk 8).
      for (final (index, event) in events.indexed)
        Text(
          _eventWords(event),
          key: ValueKey<String>('talk-event $index'),
          style: event.event == 'deferred'
              ? text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)
              : text.bodySmall,
        ),
    ];
  }

  static String _eventWords(TalkEvent event) {
    final what = switch (event.event) {
      'taken' => 'taken from the outbox',
      'queued' => 'queued to go out',
      'sent' => 'sent',
      'deferred' => 'could not be sent yet, and is tried again on the next pass',
      'held' => 'held for a person',
      'delivered' => 'delivered to this task',
      'duplicate' => 'dropped as a duplicate',
      'refused' => 'refused by a person',
      'overridden' => 'delivered by a person despite the filter',
      _ => event.event,
    };
    final peer = event.peer.isEmpty ? '' : ' (${event.peer})';
    final why = event.detail.isEmpty ? '' : ': ${event.detail}';
    return '${event.at}  ${event.message}$peer $what$why';
  }

  /// Who a peer is, in a sentence, from its address and trust: the project's other work, or whoever
  /// reads the project's conversation in a Matrix client; null where neither says.
  static String? _who(TalkPeer peer) {
    final scheme = peer.address.split(':').first;
    final inTheConversation = peer.address.endsWith(':') || peer.address == '$scheme:';
    if (peer.trust == 'vouched' && inTheConversation) {
      return 'Another piece of work in this project: what is written to it reaches its inbox.';
    }
    if (inTheConversation) {
      return 'Whoever reads this project’s conversation in a $scheme client, by the name ${peer.name}: '
          'a person who joined it, or another machine. What is written to it goes into the room.';
    }
    return null;
  }
}
