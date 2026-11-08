import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';

import '../app/diff.dart';
import '../app/forge_connection.dart' show hostOf;
import '../app/gate.dart';
import '../app/machines.dart' show Machine;
import '../app/makers.dart';
import 'panes.dart';
import 'refused_key.dart';
import 'selection_list.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';
import 'expandable_list_row.dart' show StateChip;
import 'fact_rows.dart';

/// What is waiting at a project's gate.
///
/// Work an agent finished and pushed, which has not left the machine and will not until somebody
/// decides. This is the one screen in the product where the decision is taken.
class GateView extends StatelessWidget {
  /// Constructor taking the gate, the keyboard and what a row opens.
  const GateView({required this.gate, required this.focusNode, required this.onOpen, required this.onClose, super.key});

  /// What is waiting, and what is being made of it.
  final Gate gate;

  /// This view's keyboard focus.
  final FocusNode focusNode;

  /// Opens one waiting push.
  final void Function(PendingPush push) onOpen;

  /// Closes the view.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      PaneHeader(
        title: 'Waiting at the gate · ${gate.project?.name ?? ''}',
        trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: onClose),
      ),
      if (gate.reading > 0) _Reading(count: gate.reading),
      if (gate.unread.isNotEmpty) _Unread(unread: gate.unread),
      if (gate.otherProblem != null) GateProblem(words: gate.otherProblem!),
      if (gate.mode.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
          child: Row(children: <Widget>[Text('Gate is ${gate.mode}', style: Theme.of(context).textTheme.labelMedium)]),
        ),
      Expanded(
        child: SelectionList<PendingPush>(
          items: gate.waiting,
          idOf: (push) => push.id,
          selected: gate.looking?.id,
          onSelect: (id) => onOpen(gate.waiting.firstWhere((push) => push.id == id)),
          onActivate: (id) => onOpen(gate.waiting.firstWhere((push) => push.id == id)),
          focusNode: focusNode,
          emptyMessage: gate.problem != null
              ? 'Nothing could be read.'
              : 'Nothing is waiting. Everything this project pushed has been decided.',
          rowOf: (context, push, selected) => _WaitingRow(
            push: push,
            // Named where there is more than one to tell apart: each repository has a gate of
            // its own, and a push is forwarded from the one it waits in.
            repository: gate.repositories.length > 1 ? push.repository : null,
          ),
        ),
      ),
      // **What the gate does not see, said where somebody would otherwise assume it is a
      // wall.** Agent work can still be pushed straight upstream by hand, past this screen
      // entirely. Porelo's guard against that is a pre-push hook, and it is installed **per
      // clone, on the machine somebody pushes from** — which is very often not the machine
      // this interface is talking to, and over a forwarded socket is not reachable from here
      // at all. So this says where it happens rather than offering a control that would only
      // ever protect one machine.
      Padding(
        padding: const EdgeInsets.all(Space.normal),
        child: Text(
          'This is what reached the gate. Work can also be pushed straight upstream by hand, '
          'past it — `porelo gate protect` installs a guard against that, per clone, on the '
          'machine you push from.',
          key: const Key('what-the-gate-does-not-see'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.push, this.repository});

  final PendingPush push;

  final String? repository;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      const Icon(Icons.outbox_outlined, size: Sizes.rowIcon),
      const SizedBox(width: Space.small),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(push.subject, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              <String>[
                if (repository != null) 'in $repository',
                // Porelo names it in full, for Approve; seven characters say which it is here.
                if (push.commit.isNotEmpty) push.commit.length > 7 ? push.commit.substring(0, 7) : push.commit,
                'waiting ${push.waiting}',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const Icon(Icons.chevron_right, size: Sizes.rowIcon),
    ],
  );
}

/// The ssh config a waiting push's fetch line carries for [machine], or null where it carries none: only a machine
/// this window reaches through its card's own config, whose `Host` is the very name the line logs in to, and never on
/// Windows, whose fetch line stays as the machine named it.
String? reviewFetchConfig(Machine machine, {required bool windows}) {
  final card = machine.hostCard;
  if (windows || !machine.needsATunnel || card == null || machine.host != card.name) return null;
  return machine.sshConfig.isEmpty ? null : machine.sshConfig;
}

/// The `git fetch` that brings a waiting push into the person's own clone, to read in their IDE:
/// copied, never run here, and said to be the agent's, not reviewed.
class _OwnClone extends StatefulWidget {
  const _OwnClone({required this.fetch});

  final String fetch;

  @override
  State<_OwnClone> createState() => _OwnCloneState();
}

class _OwnCloneState extends State<_OwnClone> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      key: const Key('review-own-clone'),
      padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.normal, Space.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Read it in your own clone', style: text.titleSmall),
          const SizedBox(height: Space.tight),
          Text(
            'Run this in your clone of the repository, then open it in your IDE in its safe mode. '
            'It is the agent\'s work, not reviewed yet: never build or test it on this computer, '
            'where it would run with your rights.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Space.tight),
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  widget.fetch,
                  key: const Key('review-fetch'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              TextButton.icon(
                key: const Key('review-fetch-copy'),
                icon: const Icon(Icons.copy, size: Sizes.rowIcon),
                label: Text(_copied ? 'Copied' : 'Copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: widget.fetch));
                  if (mounted) setState(() => _copied = true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One waiting push, file by file, and the decision about it.
class ReviewView extends StatelessWidget {
  /// Constructor taking the gate and the ways out of it.
  const ReviewView({
    required this.gate,
    required this.onBack,
    required this.onClose,
    required this.onApprove,
    required this.onReject,
    this.login,
    this.sshConfig,
    this.machine = '',
    this.onRefreshKeys,
    this.onTryKey,
    this.onKeepKey,
    this.onKeyTerminal,
    this.onWithoutLineEndings,
    super.key,
  });

  /// What reads the review again with or without what changed at line ends.
  final ValueChanged<bool>? onWithoutLineEndings;

  /// The machine's name, as the window shows it.
  final String machine;

  /// Reads the account's keys again, once a forward was refused for its key.
  final VoidCallback? onRefreshKeys;

  /// Tries a forward with one key alone, writing nothing.
  final void Function(SshKey key)? onTryKey;

  /// Keeps one key for the refused address and forwards again.
  final void Function(SshKey key)? onKeepKey;

  /// Opens a terminal on the machine with what the refusal names to run; null where it names nothing.
  final VoidCallback? onKeyTerminal;

  /// How this computer reaches the machine over ssh (`user@host`, or a `Host` of its own), put in
  /// the fetch in place of the name the machine gives itself; null where it is reached otherwise.
  final String? login;

  /// The SSH config used by this window on a POSIX desktop, when one applies.
  final String? sshConfig;

  /// What is being looked at.
  final Gate gate;

  /// Back to what is waiting.
  final VoidCallback onBack;

  /// Closes the view.
  final VoidCallback onClose;

  /// Forwards it, after asking which branch.
  final VoidCallback onApprove;

  /// Drops the request.
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final push = gate.looking;
    if (push == null) return const SizedBox.shrink();
    final files = gate.changed;

    return Column(
      children: <Widget>[
        PaneHeader(
          title: push.subject,
          leading: BackButton(onPressed: onBack),
          trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: onClose),
        ),
        if (gate.problem != null) GateProblem(words: gate.problem!),
        Expanded(
          child: gate.busy && files.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: Space.small),
                  children: gate.ranked.isEmpty
                      ? <Widget>[
                          ..._refusedKey(),
                          _WhoMadeIt(push: push, commits: gate.commits),
                          for (final file in files) _File(file: file),
                          if (files.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(Space.loose),
                              child: Text('This push changes no files.'),
                            ),
                          // After what it touched: reading it elsewhere is the second way, not the first.
                          if (push.fetch.isNotEmpty) _OwnClone(fetch: push.fetchFrom(login, sshConfig: sshConfig)),
                        ]
                      : <Widget>[
                          ..._refusedKey(),
                          _WhoMadeIt(push: push, commits: gate.commits),
                          ..._ranked(context, gate, files, onWithoutLineEndings),
                          if (push.fetch.isNotEmpty) _OwnClone(fetch: push.fetchFrom(login, sshConfig: sshConfig)),
                        ],
                ),
        ),
        _Decision(gate: gate, onApprove: onApprove, onReject: onReject),
      ],
    );
  }
}

extension on ReviewView {
  /// The way through a forward refused for its key, first, where there is one.
  List<Widget> _refusedKey() => <Widget>[
    if (gate.keyRefused != null)
      RefusedKey(
        gate: gate,
        machine: machine,
        onRefresh: onRefreshKeys ?? () {},
        onTry: onTryKey ?? (_) {},
        onKeep: onKeepKey ?? (_) {},
        onTerminal: gate.keyRefused!.refused.command.isEmpty ? null : onKeyTerminal,
      ),
  ];
}

/// Each commit, who wrote and committed it, and its trailer: what says whether an agent made it,
/// read before what it touched.
///
/// **Shown as the machine reports them**: the review's commits, newest first, where it lists them,
/// else the head commit as the waiting push names it. What it does not report is said to be not
/// reported, never left out, and the trailer check is then one that cannot be made here, never drawn
/// as passed.
class _WhoMadeIt extends StatelessWidget {
  const _WhoMadeIt({required this.push, required this.commits});

  final PendingPush push;

  /// The review's commits; null where the machine does not list them.
  final List<ReviewCommit>? commits;

  static const _notReported = 'not reported by the machine';

  /// What the card shows: the review's commits, or the head commit as the waiting push names it.
  List<ReviewCommit> get _made {
    final listed = commits;
    if (listed != null && listed.isNotEmpty) return listed;
    return <ReviewCommit>[
      ReviewCommit(
        commit: push.commit,
        subject: push.subject,
        author: push.author,
        committer: push.committer,
        trailers: push.trailers,
        message: push.message,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final made = _made;
    return Card(
      key: const Key('review-who'),
      margin: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.normal, Space.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
        child: FactRows(
          labelWidth: Sizes.label,
          facts: <Fact>[
            for (final (place, commit) in made.indexed) ..._facts(context, commit, place, several: made.length > 1),
          ],
        ),
      ),
    );
  }

  /// One commit's facts; those of the head commit keyed by their label alone, the others by their place too.
  List<Fact> _facts(BuildContext context, ReviewCommit commit, int place, {required bool several}) {
    final text = Theme.of(context).textTheme;
    final code = codeText.copyWith(color: text.bodyMedium?.color);
    final suffix = place == 0 ? '' : ' ${place + 1}';
    Widget said(String? value) => value == null ? const Text(_notReported) : SelectableText(value);
    final trailers = commit.trailers;
    final check = TrailerCheck.of(trailers, message: commit.message);
    return <Fact>[
      Fact(
        'Commit',
        commit.commit.isEmpty
            ? const Text(_notReported)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectableText(commit.commit, style: code),
                  // One commit is the push's own, named in the header; of several, each says which it is.
                  if (several && commit.subject.isNotEmpty) Text(commit.subject),
                ],
              ),
        key: Key('review-fact Commit$suffix'),
        dividedAbove: place > 0,
      ),
      Fact('Author', said(commit.author), key: Key('review-fact Author$suffix')),
      Fact('Committer', said(commit.committer), key: Key('review-fact Committer$suffix')),
      Fact(
        'Trailer',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (trailers == null)
              const Text(_notReported)
            else if (trailers.isEmpty)
              const Text('none')
            else
              for (final line in trailers) SelectableText(line),
            const SizedBox(height: Space.tight),
            KeyedSubtree(
              key: ValueKey<String>('review-trailer-check ${check.state.name}$suffix'),
              child: StateChip(
                check.words,
                toneWords: switch (check.state) {
                  TrailerState.passed => 'ok',
                  TrailerState.wrong => 'failed',
                  TrailerState.unknown => null,
                },
              ),
            ),
          ],
        ),
        key: Key('review-fact Trailer$suffix'),
      ),
    ];
  }
}

/// The review as the machine ranked it: what the task was asked, apart from what it touched, then
/// every file in the machine's order, the volume that is almost never a finding last.
List<Widget> _ranked(
  BuildContext context,
  Gate gate,
  List<ChangedFile> hunks,
  ValueChanged<bool>? onWithoutLineEndings,
) {
  final text = Theme.of(context).textTheme;
  final byPath = <String, ChangedFile>{for (final each in hunks) each.path: each};
  final read = <ReviewFile>[
    for (final file in gate.ranked)
      if (!file.volume) file,
  ];
  final volume = <ReviewFile>[
    for (final file in gate.ranked)
      if (file.volume) file,
  ];
  final asked = gate.asked;
  return <Widget>[
    // Kept apart from what it touched, and never compared with it: a person reads both.
    Padding(
      padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.normal, Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What the task was asked', style: text.labelMedium),
          const SizedBox(height: Space.tight),
          if (asked == null)
            const Text(
              'Its task is gone from this machine, so what it was asked is not known here.',
              key: Key('review-asked-unknown'),
            )
          else if (asked.isEmpty)
            const Text('It was started without an instruction.', key: Key('review-asked-nothing'))
          else
            SelectableText(asked, key: const Key('review-asked')),
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.normal),
      child: Text(
        'What it touched, in the order that matters: what is dangerous by kind first, however small, '
        'and the volume that is almost never a finding last. The order is the machine\'s. It changes '
        'what you read first, and detects nothing: no file here is judged safe or injected.',
        key: const Key('review-not-a-verdict'),
        style: text.bodySmall,
      ),
    ),
    ..._lineEndings(context, gate, onWithoutLineEndings),
    const SizedBox(height: Space.small),
    for (final file in read) _RankedFile(file: file, hunks: byPath[file.path], without: gate.withoutLineEndings),
    if (volume.isNotEmpty) ...<Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.normal, Space.normal, Space.normal, Space.tight),
        child: Text(
          'Almost never a finding: generated, or reformatting only',
          key: const Key('review-volume'),
          style: text.labelMedium,
        ),
      ),
      for (final file in volume) _RankedFile(file: file, hunks: byPath[file.path], without: gate.withoutLineEndings),
    ],
  ];
}

/// Whether leaving line ends out changes [file]'s count, where the machine counts both.
bool _countsDiffer(ReviewFile file) =>
    file.addedIgnoringLineEndings != null &&
    file.removedIgnoringLineEndings != null &&
    file.added >= 0 &&
    (file.addedIgnoringLineEndings != file.added || file.removedIgnoringLineEndings != file.removed);

/// What changed at line ends, said rather than hidden: which diff is shown, and the other where the
/// machine can give it.
List<Widget> _lineEndings(BuildContext context, Gate gate, ValueChanged<bool>? onWithoutLineEndings) {
  final mostly = gate.ranked.any((file) => file.mostlyLineEndings);
  if (!mostly && !gate.withoutLineEndings) return const <Widget>[];
  final offered = gate.servesWithoutLineEndings && onWithoutLineEndings != null;
  final said = switch ((gate.withoutLineEndings, offered)) {
    (true, _) =>
      'The diff below leaves out what changed at line ends, and spaces there. Where that changes a '
          "file's count, both counts stand beside it.",
    (false, true) =>
      'Some files changed mostly at their line ends, such as CRLF to LF. The diff below holds every '
          'such line; it can be shown without them.',
    (false, false) =>
      'Some files changed mostly at their line ends, such as CRLF to LF. The diff below holds every '
          'such line, and this machine cannot leave them out.',
  };
  return <Widget>[
    Padding(
      padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.normal, 0),
      child: Text(said, key: const Key('review-line-endings')),
    ),
    if (offered)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.small),
        child: CheckboxListTile(
          key: const Key('review-without-line-endings'),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: gate.withoutLineEndings,
          onChanged: gate.busy ? null : (value) => onWithoutLineEndings(value ?? false),
          title: const Text('Show the diff without line endings'),
        ),
      ),
  ];
}

/// One file as the machine ranked it: its rank and reason beside its name, its hunks on opening.
class _RankedFile extends StatefulWidget {
  const _RankedFile({required this.file, this.hunks, this.without = false});

  final ReviewFile file;
  final ChangedFile? hunks;

  /// Whether the diff shown leaves out line ends, so every count that changes with that is given twice.
  final bool without;

  @override
  State<_RankedFile> createState() => _RankedFileState();
}

class _RankedFileState extends State<_RankedFile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hunks = widget.hunks;
    return Container(
      key: ValueKey<String>('review-file ${file.path}'),
      color: file.dangerous ? scheme.errorContainer : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: hunks == null ? null : () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(_open ? Icons.expand_more : Icons.chevron_right, size: Sizes.rowIcon),
                      const SizedBox(width: Space.small),
                      Expanded(
                        child: Text(file.path, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      ),
                      Text(
                        _rankWords(file.rank),
                        key: ValueKey<String>('review-rank ${file.path}'),
                        style: text.labelSmall?.copyWith(
                          fontWeight: file.dangerous ? FontWeight.bold : null,
                          color: file.dangerous ? scheme.onErrorContainer : null,
                        ),
                      ),
                      const SizedBox(width: Space.small),
                      Text('+${file.added}', style: TextStyle(color: scheme.primary, fontSize: 12)),
                      const SizedBox(width: Space.tight),
                      Text(
                        file.removed < 0 ? 'binary' : '−${file.removed}',
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                    ],
                  ),
                  if (file.reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: Space.loose),
                      child: Text(
                        file.reason,
                        key: ValueKey<String>('review-reason ${file.path}'),
                        style: text.bodySmall,
                      ),
                    ),
                  if (file.mostlyLineEndings || (widget.without && _countsDiffer(file)))
                    Padding(
                      padding: const EdgeInsets.only(left: Space.loose),
                      child: Text(
                        '${file.mostlyLineEndings ? 'Mostly line endings' : 'Without line endings'}: '
                        '+${file.addedIgnoringLineEndings} −${file.removedIgnoringLineEndings} without them, '
                        '+${file.added} −${file.removed} with them.',
                        key: ValueKey<String>('review-line-endings ${file.path}'),
                        style: text.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_open && hunks != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(Space.loose, 0, Space.normal, Space.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[for (final line in hunks.lines) _Line(line: line)],
              ),
            ),
        ],
      ),
    );
  }

  static String _rankWords(String rank) => switch (rank) {
    'DANGEROUS' => 'dangerous by kind',
    'ORDINARY' => 'ordinary',
    'GENERATED' => 'generated',
    'REFORMATTING' => 'reformatting only',
    _ => rank.toLowerCase(),
  };
}

/// One changed file and its hunks.
///
/// Collapsed to its name until it is opened: a review of thirty files that opens them all is one
/// nobody reads to the end.
class _File extends StatefulWidget {
  const _File({required this.file});

  final ChangedFile file;

  @override
  State<_File> createState() => _FileState();
}

class _FileState extends State<_File> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
            child: Row(
              children: <Widget>[
                Icon(_open ? Icons.expand_more : Icons.chevron_right, size: Sizes.rowIcon),
                const SizedBox(width: Space.small),
                Expanded(
                  child: Text(
                    file.wasAt == null ? file.path : '${file.wasAt} → ${file.path}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                Text(file.what, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: Space.small),
                Text('+${file.insertions}', style: TextStyle(color: scheme.primary, fontSize: 12)),
                const SizedBox(width: Space.tight),
                Text('−${file.deletions}', style: TextStyle(color: scheme.error, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(Space.loose, 0, Space.normal, Space.small),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[for (final line in file.lines) _Line(line: line)],
            ),
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line});

  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color? background, Color? ink, String marker) = switch (line.kind) {
      DiffLineKind.added => (scheme.primaryContainer, scheme.onPrimaryContainer, '+'),
      DiffLineKind.removed => (scheme.errorContainer, scheme.onErrorContainer, '−'),
      DiffLineKind.hunk => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, ''),
      DiffLineKind.context => (null, null, ' '),
    };
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: Space.small, vertical: Space.hairline),
      child: SelectableText(
        '$marker${line.text}',
        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: ink),
      ),
    );
  }
}

/// The decision, and the way to take the diff elsewhere.
class _Decision extends StatelessWidget {
  const _Decision({required this.gate, required this.onApprove, required this.onReject});

  final Gate gate;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    padding: const EdgeInsets.all(Space.normal),
    child: Wrap(
      spacing: Space.small,
      runSpacing: Space.small,
      children: <Widget>[
        // First and plain: the common case is somebody wanting the diff in the tool they
        // review in, immediately. Nothing about it sends anything anywhere.
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_outlined, size: Sizes.rowIcon),
          label: const Text('Copy the diff'),
          onPressed: gate.diff.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: gate.diff)),
        ),
        OutlinedButton(onPressed: gate.looking == null ? null : onReject, child: const Text('Drop the request')),
        FilledButton(
          onPressed: gate.looking == null ? null : onApprove,
          // Work in the Default project goes to its repository's origin, never to a project's upstream.
          child: Text(gate.project?.name == defaultProject ? 'Forward it to its origin…' : 'Forward it upstream…'),
        ),
      ],
    ),
  );
}

/// Why the gate could not be read or acted on.
class GateProblem extends StatelessWidget {
  /// Constructor taking what to say.
  const GateProblem({required this.words, super.key});

  /// What went wrong, in words.
  final String words;

  @override
  Widget build(BuildContext context) => _ProblemBox(
    child: Padding(
      padding: const EdgeInsets.all(Space.normal),
      child: Text(words, key: const Key('gate-problem')),
    ),
  );
}

/// A box for what went wrong, a few lines high at most and scrolling beyond them, so what waits
/// below it stays on screen whatever it says.
class _ProblemBox extends StatefulWidget {
  const _ProblemBox({required this.child});

  final Widget child;

  @override
  State<_ProblemBox> createState() => _ProblemBoxState();
}

class _ProblemBoxState extends State<_ProblemBox> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxHeight: Sizes.problemBox),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: Sizes.divider),
    ),
    // Its own surface, so a row that opens inside it draws on the box rather than under it.
    child: Material(
      type: MaterialType.transparency,
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(controller: _scroll, child: widget.child),
      ),
    ),
  );
}

/// Says that the gate is being read, and how many repositories are asked.
class _Reading extends StatelessWidget {
  const _Reading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('gate-reading'),
    padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
    child: Row(
      children: <Widget>[
        const SizedBox.square(
          dimension: Sizes.operationSpinner,
          child: CircularProgressIndicator(strokeWidth: Sizes.spinnerStroke),
        ),
        const SizedBox(width: Space.small),
        Expanded(
          child: Text(
            count == 1 ? 'Reading the gate…' : 'Reading the gate of $count repositories…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

/// Why [repository]'s gate could not be read, from [words] with what names it alone left out: its name, and every
/// address and path, each said as "…".
String unreadReason(String repository, String words) => words
    .replaceAll(RegExp(r"'[^']*'"), '…')
    .replaceAll(RegExp(r'\S*[/@]\S*'), '…')
    .replaceAll(
      // Only where it stands as a name, before punctuation or at the end, never as a word of the message: a
      // repository called "key" leaves "Host key verification" alone.
      RegExp('(?<![\\w.-])${RegExp.escape(repository)}(?=[:;,)\\]]|\\.git\\b|\\s*\$)', multiLine: true),
      '…',
    )
    .trim();

/// The repositories whose gate could not be read, one line per reason, opened on demand.
class _Unread extends StatelessWidget {
  const _Unread({required this.unread});

  final List<({String name, String words})> unread;

  @override
  Widget build(BuildContext context) {
    // By reason, not by exact words: each refusal names its own repository, address and mirror, so sixteen of the same
    // reason would otherwise stand as sixteen lines.
    final byWords = <String, List<String>>{};
    for (final each in unread) {
      (byWords[unreadReason(each.name, each.words)] ??= <String>[]).add(each.name);
    }
    return _ProblemBox(
      child: Column(
        key: const Key('gate-unread'),
        children: <Widget>[
          for (final MapEntry(key: words, value: names) in byWords.entries) _UnreadReason(words: words, names: names),
        ],
      ),
    );
  }
}

class _UnreadReason extends StatelessWidget {
  const _UnreadReason({required this.words, required this.names});

  final String words;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = words.trim().split('\n').first;
    final which = names.length == 1 ? names.single : '${names.length} repositories';
    return ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: Space.normal),
      childrenPadding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text('$which could not be read: $first', maxLines: 1, overflow: TextOverflow.ellipsis),
      children: <Widget>[
        if (names.length > 1) SelectableText(names.join(', '), style: text.labelMedium),
        const SizedBox(height: Space.tight),
        SelectableText(words, style: text.bodySmall),
      ],
    );
  }
}

/// Asks which branch to forward onto.
///
/// Named, never inferred: `Approve` requires a branch, and a push forwarded onto a guess is one
/// nobody decided about.
Future<String?> askWhichBranch(
  BuildContext context, {
  required String subject,
  bool toOrigin = false,
  List<String> branches = const <String>[],
  String? defaultBranch,
  String upstream = '',
  String initialBranch = '',
  String branchSource = '',
}) => showDialog<String>(
  context: context,
  builder: (context) => _WhichBranch(
    subject: subject,
    toOrigin: toOrigin,
    branches: branches,
    defaultBranch: defaultBranch,
    upstream: upstream,
    initialBranch: initialBranch,
    branchSource: branchSource,
  ),
);

/// Why git would refuse [name] as a branch, in words, or null where it takes it: said before
/// anything is sent, since a forge refused a commit's subject typed as a branch.
String? whyNotABranch(String name) {
  if (name.isEmpty) return null;
  if (RegExp(r'\s').hasMatch(name)) return 'A branch name has no spaces.';
  if (RegExp(r'[~^:?*\[\\\x00-\x1f\x7f]').hasMatch(name)) return 'A branch name has none of ~ ^ : ? * [ \\.';
  if (name.contains('..') || name.contains('@{') || name.contains('//')) {
    return 'A branch name has no "..", "@{" or "//".';
  }
  if (name.startsWith('-') ||
      name.startsWith('/') ||
      name.endsWith('/') ||
      name.endsWith('.') ||
      name.endsWith('.lock')) {
    return 'A branch name does not start with "-" or "/", nor end with "/", "." or ".lock".';
  }
  if (name.split('/').any((part) => part.startsWith('.'))) return 'No part of a branch name starts with ".".';
  return null;
}

class _WhichBranch extends StatefulWidget {
  const _WhichBranch({
    required this.subject,
    this.toOrigin = false,
    this.branches = const <String>[],
    this.defaultBranch,
    this.upstream = '',
    this.initialBranch = '',
    this.branchSource = '',
  });

  final String subject;

  /// The repository's branches, as its forge lists them; empty where no forge here could be asked.
  final List<String> branches;

  /// Its default branch, offered first and chosen.
  final String? defaultBranch;

  /// Whether it goes to the repository's origin: work in the Default project.
  final bool toOrigin;

  /// The repository's upstream address, empty when none was reported.
  final String upstream;

  /// The task's branch or its last confirmed forward, empty when neither exists.
  final String initialBranch;

  /// Why the initial branch is offered.
  final String branchSource;

  @override
  State<_WhichBranch> createState() => _WhichBranchState();
}

class _WhichBranchState extends State<_WhichBranch> {
  final _branch = TextEditingController();

  /// The branch chosen from the list, or null for a new one typed below it.
  String? _chosen;

  /// The branches offered, the default first.
  late final List<String> _offered = <String>[
    if (widget.defaultBranch != null && widget.branches.contains(widget.defaultBranch)) widget.defaultBranch!,
    ...widget.branches.where((each) => each != widget.defaultBranch),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialBranch.isNotEmpty) {
      _chosen = _offered.contains(widget.initialBranch) ? widget.initialBranch : null;
      _branch.text = widget.initialBranch;
    } else {
      _chosen = _offered.isEmpty ? null : _offered.first;
    }
  }

  String get _named => _chosen ?? _branch.text.trim();

  String get _destination {
    if (widget.toOrigin) return "To the repository's origin";
    final upstream = widget.upstream.trim();
    final host = hostOf(upstream);
    final scp = RegExp(r'^[^@/:]+@[^:/]+:(.+)$').firstMatch(upstream);
    final repository = (scp?.group(1) ?? Uri.tryParse(upstream)?.path ?? '')
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .replaceFirst(RegExp(r'\.git$'), '');
    final segments = repository.split('/');
    return host != null && segments.length >= 2 && segments.every((segment) => segment.isNotEmpty)
        ? 'To $host $repository'
        : 'The upstream destination was not reported.';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.toOrigin ? 'Forward it to its origin' : 'Forward it upstream'),
    content: SizedBox(
      width: Sizes.dialogSmall,
      child: DialogScroll(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_destination),
            const SizedBox(height: Space.small),
            Text(widget.subject, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: Space.normal),
            // Chosen from the repository's own where its forge says them, the default first.
            if (_offered.isNotEmpty) ...<Widget>[
              DropdownButtonFormField<String?>(
                key: const Key('forward-branch'),
                initialValue: _chosen,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Branch to push to', border: OutlineInputBorder()),
                items: <DropdownMenuItem<String?>>[
                  for (final each in _offered)
                    DropdownMenuItem<String?>(
                      value: each,
                      child: Text(each == widget.defaultBranch ? '$each (its default branch)' : each),
                    ),
                  const DropdownMenuItem<String?>(value: null, child: Text('A new branch…')),
                ],
                onChanged: (chosen) => setState(() => _chosen = chosen),
              ),
              const SizedBox(height: Space.small),
            ],
            if (_chosen == null)
              TextField(
                key: const Key('forward-new-branch'),
                controller: _branch,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _offered.isEmpty ? 'Branch to push to' : 'The new branch',
                  hintText: 'e.g. fix-rounding',
                  border: const OutlineInputBorder(),
                  errorText: whyNotABranch(_branch.text.trim()),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            if (_named == widget.initialBranch && widget.branchSource.isNotEmpty) ...<Widget>[
              const SizedBox(height: Space.small),
              Text(widget.branchSource, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: Space.normal),
            Text(
              'This is the only thing the interface does that sends anything anywhere. '
              'The branch is named rather than guessed.',
              key: const Key('only-thing-that-sends'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _submit, child: const Text('Forward it')),
    ],
  );

  /// One answer for Return and the button, because an empty name is not a branch.
  void _submit() {
    final branch = _named;
    if (branch.isEmpty || whyNotABranch(branch) != null) return;
    Navigator.of(context).pop(branch);
  }

  @override
  void dispose() {
    _branch.dispose();
    super.dispose();
  }
}
