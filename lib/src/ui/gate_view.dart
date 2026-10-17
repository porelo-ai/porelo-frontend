import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';

import '../app/diff.dart';
import '../app/gate.dart';
import 'panes.dart';
import 'selection_list.dart';
import 'tokens.dart';

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
      if (gate.problem != null) GateProblem(words: gate.problem!),
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
    super.key,
  });

  /// How this computer reaches the machine over ssh (`user@host`, or a `Host` of its own), put in
  /// the fetch in place of the name the machine gives itself; null where it is reached otherwise.
  final String? login;

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
                          if (push.fetch.isNotEmpty) _OwnClone(fetch: push.fetchFrom(login)),
                          for (final file in files) _File(file: file),
                          if (files.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(Space.loose),
                              child: Text('This push changes no files.'),
                            ),
                        ]
                      : <Widget>[
                          if (push.fetch.isNotEmpty) _OwnClone(fetch: push.fetchFrom(login)),
                          ..._ranked(context, gate, files),
                        ],
                ),
        ),
        _Decision(gate: gate, onApprove: onApprove, onReject: onReject),
      ],
    );
  }
}

/// The review as the machine ranked it: what the task was asked, apart from what it touched, then
/// every file in the machine's order, the volume that is almost never a finding last.
List<Widget> _ranked(BuildContext context, Gate gate, List<ChangedFile> hunks) {
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
    const SizedBox(height: Space.small),
    for (final file in read) _RankedFile(file: file, hunks: byPath[file.path]),
    if (volume.isNotEmpty) ...<Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.normal, Space.normal, Space.normal, Space.tight),
        child: Text(
          'Almost never a finding: generated, or reformatting only',
          key: const Key('review-volume'),
          style: text.labelMedium,
        ),
      ),
      for (final file in volume) _RankedFile(file: file, hunks: byPath[file.path]),
    ],
  ];
}

/// One file as the machine ranked it: its rank and reason beside its name, its hunks on opening.
class _RankedFile extends StatefulWidget {
  const _RankedFile({required this.file, this.hunks});

  final ReviewFile file;
  final ChangedFile? hunks;

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
          // Work without a project goes to its repository's origin, never to a project's upstream.
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.errorContainer,
    padding: const EdgeInsets.all(Space.normal),
    child: Text(words, key: const Key('gate-problem')),
  );
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
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _WhichBranch(subject: subject, toOrigin: toOrigin, branches: branches, defaultBranch: defaultBranch),
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
  });

  final String subject;

  /// The repository's branches, as its forge lists them; empty where no forge here could be asked.
  final List<String> branches;

  /// Its default branch, offered first and chosen.
  final String? defaultBranch;

  /// Whether it goes to the repository's origin: work without a project.
  final bool toOrigin;

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
    _chosen = _offered.isEmpty ? null : _offered.first;
  }

  String get _named => _chosen ?? _branch.text.trim();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.toOrigin ? 'Forward it to its origin' : 'Forward it upstream'),
    content: SizedBox(
      width: Sizes.dialogSmall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                hintText: 'fix-rounding',
                border: const OutlineInputBorder(),
                errorText: whyNotABranch(_branch.text.trim()),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
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
