import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_model.dart';
import '../app/machines.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// One message waiting for a person, as a row in *Needs you*.
class HeldMessageRow extends StatelessWidget {
  /// Constructor taking the message and where it is.
  const HeldMessageRow({required this.machine, required this.fleet, required this.message, super.key});

  final Machine machine;
  final FleetModel fleet;
  final HeldMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final refused = message.standing == 'refused-by-filter';
    return Card(
      key: ValueKey<String>('held-message ${machine.name}/${message.task}/${message.handle}'),
      color: refused ? scheme.errorContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Space.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(headline(message, machine.name), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: Space.tight),
            if (mayPreview(message)) _Preview(fleet: fleet, message: message),
            Text(standingWords(message.standing), style: text.bodySmall),
            if (message.reason.isNotEmpty) Text(message.reason, style: text.bodySmall),
            // Held on its way in: what was written is out already, for everybody else; what is decided
            // here is only whether this task reads it (walk 10: it was taken for the sent one).
            if (message.direction == 'in')
              Text(
                'Whoever wrote it has sent it already; it only waits to reach ${message.task}. What you decide '
                'is whether ${message.task} gets it.',
                key: ValueKey<String>('held-message-inbound ${message.task}/${message.handle}'),
                style: text.bodySmall,
              ),
            const SizedBox(height: Space.small),
            OutlinedButton.icon(
              key: ValueKey<String>('read-message ${message.task}/${message.handle}'),
              onPressed: () => unawaited(showDialog<void>(
                context: context,
                builder: (_) => HeldMessageDialog(fleet: fleet, message: message),
              )),
              icon: const Icon(Icons.mail_outline, size: Sizes.rowIcon),
              label: Text(message.direction == 'in' ? 'Read it, and decide whether ${message.task} gets it' : 'Read it and decide'),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether the start of its text may be shown before a person opens it: only what stands held and
  /// nothing the filter refused or would have refused, whose text is what the filter kept back.
  /// For those the reason, the filter's own masked answer, is shown.
  static bool mayPreview(HeldMessage message) =>
      message.standing == 'held' && !message.reason.contains('filter would have refused');

  /// Which task, to whom, of which kind, and on which machine.
  static String headline(HeldMessage message, String machine) {
    final kind = message.kind.isEmpty ? 'A message' : 'A ${message.kind}';
    // Which way it was going, when the machine says: one arriving from a peer is held on its way
    // in, before any task has seen it.
    if (message.direction == 'in') {
      final from = message.peer.isEmpty ? 'a peer' : message.peer;
      return '$kind coming in from $from to ${message.task}, on $machine';
    }
    // Written by the person at this interface, through a task: said as theirs, since "from a person"
    // left them asking whose it was (walk 8).
    if (message.role == 'ROLE_USER') {
      final kindOf = message.kind.isEmpty ? 'A message' : 'A ${message.kind}';
      final to = message.peer.isEmpty ? '' : ' to ${message.peer}';
      return '$kindOf you wrote, going out through ${message.task}$to, on $machine';
    }
    final who = message.task;
    if (message.direction == 'out') {
      final to = message.peer.isEmpty ? '' : ' to ${message.peer}';
      return '$kind going out from $who$to, on $machine';
    }
    final to = message.peer.isEmpty ? '' : ' with ${message.peer}';
    return '$kind from $who$to, on $machine';
  }

  /// What its standing means for what can be done with it.
  static String standingWords(String standing) => switch (standing) {
        'held' => 'Held until somebody reads it and releases or refuses it.',
        'refused-by-filter' => 'Refused by the filter. It can be read, and delivered after all.',
        'refused-by-person' => 'Refused for good by a person. It is never sent.',
        'unchecked' => 'The filter could not check it at all. It is never sent.',
        _ => 'Standing: $standing.',
      };
}

/// Reads one held message in full and decides about exactly what was read.
///
/// **The text is shown as text and never interpreted**: every part in a selectable, monospaced box,
/// no markup rendered, no link made pressable, nothing fetched. It has not been cleared by the
/// filter — for a refused one the filter said no — so what is on screen is evidence, not content.
class HeldMessageDialog extends StatefulWidget {
  /// Constructor taking the machine's model and the message as it was listed.
  const HeldMessageDialog({required this.fleet, required this.message, super.key});

  final FleetModel fleet;
  final HeldMessage message;

  @override
  State<HeldMessageDialog> createState() => _HeldMessageDialogState();
}

class _HeldMessageDialogState extends State<HeldMessageDialog> {
  HeldMessageRead? _read;
  String? _problem;
  bool _deciding = false;
  MessageRelease? _done;
  // What a refusal tells the sender, in the person's own words; nothing when left empty.
  final _reason = TextEditingController();
  String _refusedWith = '';

  @override
  void initState() {
    super.initState();
    unawaited(_readIt());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _readIt() async {
    try {
      final read = await widget.fleet.mailboxes.read(widget.fleet.backend, widget.message);
      if (mounted) setState(() => _read = read);
    } on VarlinkException catch (refusal) {
      if (mounted) setState(() => _problem = 'The machine refused to show it: ${refusal.simpleName}.');
    } on VarlinkDisconnected catch (ex) {
      if (mounted) setState(() => _problem = 'Lost contact while reading it: ${ex.message}');
    }
  }

  Future<void> _decide({required bool refuse}) async {
    final read = _read;
    if (read == null) return;
    final reason = refuse ? _reason.text.trim() : '';
    setState(() => _deciding = true);
    try {
      final done = await widget.fleet.mailboxes
          .decide(widget.fleet.backend, read, widget.message.task, refuse: refuse, reason: reason);
      if (!mounted) return;
      // Closed once decided, with what came of it said where the person goes back to: the dialog
      // left open after a decision read as if nothing had happened (walk 8).
      final said = <String>[
        _outcome(done, widget.message.direction, withWords: reason.isNotEmpty),
        if (done.outcome == 'RELEASED' && done.detail.isNotEmpty) done.detail,
      ].join(' ');
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        setState(() {
          _done = done;
          _refusedWith = reason;
        });
        return;
      }
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(key: const Key('held-message-decided'), content: Text(said)));
      return;
    } on VarlinkException catch (refusal) {
      if (mounted) setState(() => _problem = 'The machine refused the decision: ${refusal.simpleName}.');
    } on VarlinkDisconnected catch (ex) {
      if (mounted) setState(() => _problem = 'Lost contact before it was decided: ${ex.message}');
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final read = _read;
    final done = _done;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('held-message-dialog'),
      title: Text(HeldMessageRow.headline(widget.message, widget.fleet.backend.label)),
      content: SizedBox(
        width: Sizes.dialog,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_problem != null) Text(_problem!, key: const Key('held-message-problem')),
              if (read == null && _problem == null) const Text('Reading it from the machine…'),
              if (read != null && !read.found)
                Text(_notThere(read.outcome), key: const Key('held-message-gone')),
              if (read != null && read.found) ...<Widget>[
                Text(HeldMessageRow.standingWords(read.standing), key: const Key('held-message-standing')),
                const SizedBox(height: Space.tight),
                Text(_facts(read), key: const Key('held-message-facts'), style: text.bodySmall),
                if (read.reason.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Space.small),
                  Text(read.standing == 'refused-by-filter' ? 'What the filter said' : 'Why it is held',
                      style: text.labelMedium),
                  SelectableText(read.reason, key: const Key('held-message-reason')),
                ],
                const SizedBox(height: Space.small),
                Text('What it says, exactly as written', style: text.labelMedium),
                const SizedBox(height: Space.tight),
                for (final (index, part) in read.text.indexed)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: Space.tight),
                    padding: const EdgeInsets.all(Space.small),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(Radii.small),
                    ),
                    child: SelectableText(
                      part,
                      key: ValueKey<String>('held-message-part $index'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                if (read.text.isEmpty) const Text('It has no text.'),
                if (read.standing == 'refused-by-filter' && done == null) ...<Widget>[
                  const SizedBox(height: Space.small),
                  Text(
                    'Delivered after all, it goes straight to its transport and never through the '
                    "filter's accepted messages, and the record says a person sent it although the "
                    'filter refused it. A peer that is external checks it again with its own filter, '
                    'and may refuse it there.',
                    key: const Key('held-message-despite'),
                    style: text.bodySmall,
                  ),
                ],
              ],
              if (read != null && read.found && done == null && _decidable(read.standing)) ...<Widget>[
                const SizedBox(height: Space.small),
                TextField(
                  key: const Key('held-message-refuse-reason'),
                  controller: _reason,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'If you refuse it: why, in your words (optional)',
                    helperText: 'The one that wrote it is told them with the refusal.',
                  ),
                ),
              ],
              if (done != null) ...<Widget>[
                const SizedBox(height: Space.small),
                Text(_outcome(done, widget.message.direction, withWords: _refusedWith.isNotEmpty),
                    key: const Key('held-message-outcome'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                // The machine's own words under ours, where it says more.
                if (done.outcome == 'RELEASED' && done.detail.isNotEmpty)
                  Text(done.detail, key: const Key('held-message-outcome-detail'), style: text.bodySmall),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (read != null && read.found && done == null && _decidable(read.standing)) ...<Widget>[
          TextButton(
            key: const Key('refuse-message'),
            onPressed: _deciding ? null : () => unawaited(_decide(refuse: true)),
            child: Text(read.standing == 'refused-by-filter' ? 'Keep it refused' : 'Refuse it'),
          ),
          FilledButton(
            key: const Key('release-message'),
            onPressed: _deciding ? null : () => unawaited(_decide(refuse: false)),
            child: Text(read.standing == 'refused-by-filter' ? 'Deliver it despite the filter' : 'Release it'),
          ),
        ],
        TextButton(
          key: const Key('held-message-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(done == null ? 'Leave it for now' : 'Done'),
        ),
      ],
    );
  }

  static bool _decidable(String standing) => standing == 'held' || standing == 'refused-by-filter';

  static String _facts(HeldMessageRead read) => <String>[
        if (read.role.isNotEmpty) read.role == 'ROLE_USER' ? 'Written by a person' : 'Written by the task',
        if (read.peer.isNotEmpty) 'peer ${read.peer}',
        if (read.kind.isNotEmpty) 'a ${read.kind}',
        if (read.at.isNotEmpty) 'recorded ${read.at}',
        if (read.id.isNotEmpty) 'id ${read.id}',
      ].join(' · ');

  static String _notThere(String outcome) => switch (outcome) {
        'NO_SUCH_MESSAGE' => 'It is no longer there: it was decided about, or its task took it, since it was listed.',
        'AMBIGUOUS' => 'The machine could not tell which message this is, so nothing is shown.',
        _ => 'The machine answered $outcome.',
      };

  static String _outcome(MessageRelease done, String direction, {bool withWords = false}) =>
      switch (done.outcome) {
        // Which way it was going decides where a release sends it: one held on its way in reaches
        // the task, checked as every arrival is, and never goes back out.
        // Released is "try again", not "trust it" (Porelo 347f122): the same check can hold it again.
        'RELEASED' when direction == 'in' =>
          'Released. The next pass checks it again, as every arrival is checked: it reaches this task '
              'unless the same check holds it again.',
        'RELEASED' => 'Released. It goes out on the next pass, unless its peer is set to refuse everything.',
        'REFUSED' => 'Refused for good. The task that wrote it is told${withWords ? ', with your words' : ''}.',
        'DELIVERED_DESPITE_FILTER' =>
          'Delivered despite the filter. The record says a person sent it after the filter refused it.',
        'NOT_DELIVERABLE' => 'It cannot be sent${done.detail.isEmpty ? '' : ': ${done.detail}'}.',
        'NO_SUCH_MESSAGE' => 'It was no longer there, so nothing was decided.',
        'AMBIGUOUS' => 'The machine could not tell which message this is, so nothing was decided.',
        _ => 'The machine answered ${done.outcome}.',
      };
}

/// The start of a held message's text, read for the row: what it says tells more than that it waits
/// (walk 8). Reading has no side effect: a release decides on the message as it lies.
class _Preview extends StatefulWidget {
  const _Preview({required this.fleet, required this.message});

  final FleetModel fleet;
  final HeldMessage message;

  /// How much of it is shown.
  static const length = 200;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  String? _start;

  @override
  void initState() {
    super.initState();
    unawaited(_readIt());
  }

  Future<void> _readIt() async {
    try {
      final read = await widget.fleet.mailboxes.read(widget.fleet.backend, widget.message);
      final all = read.text.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (!mounted || all.isEmpty) return;
      setState(() => _start = all.length > _Preview.length ? '${all.substring(0, _Preview.length)}…' : all);
    } on Object {
      // Nothing shown rather than a second error beside the row: opening it says what went wrong.
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    if (start == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.tight),
      // Shown as text and never interpreted, as in the dialog.
      child: Text('“$start”', key: ValueKey<String>('held-preview ${widget.message.handle}'), maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}
