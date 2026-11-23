import 'dart:async';

import 'package:flutter/material.dart';

import 'package:porelo_frontend/client.dart';

import '../app/logs.dart';
import 'ansi.dart';
import 'console_lines.dart';
import 'panes.dart';
import 'small_switch.dart';
import 'terminal_look.dart';
import 'tokens.dart';

/// The log an agent writes as it works.
const String taskLog = 'task.log';

/// One of a task's logs, as it is written.
///
/// Inside the interface, deliberately. The alternative — a window per piece of work — does not
/// survive five concurrent runs, which is the number this is for.
class LogView extends StatefulWidget {
  /// Constructor taking what to show and how to leave it.
  const LogView({required this.tail, required this.logs, required this.onClose, this.headed = true, super.key});

  /// Whether it says what it shows and holds its own switch; a tab has a bar above it that does.
  final bool headed;

  /// The log being read.
  final LogTail tail;

  /// What is holding it open.
  final Logs logs;

  /// Closes the view. Never stops the reading.
  final VoidCallback onClose;

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final _scroll = ScrollController();
  static const _center = ValueKey<String>('log-newer-lines');
  int _drawn = 0;
  int _generation = 0;

  // Set while this view moves itself to the end, so that the move is not taken for a person's scroll.
  bool _jumping = false;

  /// How near the top, in logical pixels, the view asks for the lines before the first one held.
  static const double _nearTheTop = 400;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrolled);
  }

  // Reaching the top is what asks for earlier lines. Reading back means not being taken to the end by
  // what arrives meanwhile, so following is let go of at the same time.
  void _scrolled() {
    if (_jumping || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels - position.minScrollExtent > _nearTheTop) return;
    final tail = widget.tail;
    widget.logs.scrolledToTheTop(tail);
    if (!tail.wantsOlder) return;
    widget.logs.follow(tail, following: false);
    unawaited(widget.logs.readOlder(tail));
  }

  void _fillTheView() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final tail = widget.tail;
    // Lines too few to scroll, or a page that came back short and left the view still at the top.
    final fits = position.maxScrollExtent - position.minScrollExtent <= _nearTheTop;
    final stillAtTheTop = tail.earlier > 0 && position.pixels - position.minScrollExtent <= _nearTheTop;
    if (!fits && !stillAtTheTop) return;
    if (tail.wantsOlder && tail.lines.isNotEmpty) unawaited(widget.logs.readOlder(tail));
  }

  @override
  Widget build(BuildContext context) {
    final tail = widget.tail;
    _keepUp(tail);

    return Column(
      children: <Widget>[
        if (widget.headed)
          PaneHeader(
            page: true,
            title: tail.formatted ? '${tail.task} · what its agent writes' : '${tail.log} · ${tail.task}',
            trailing: Row(
              children: <Widget>[
                // Following is a switch and not a scroll position, so reading back cannot turn it
                // off by accident and turning it on again cannot lose what arrived meanwhile.
                Text('Follow', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: Space.small),
                SmallSwitch(
                  key: const Key('follow'),
                  label: 'Follow',
                  value: tail.following,
                  onChanged: (following) => widget.logs.follow(tail, following: following),
                ),
                IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: widget.onClose),
              ],
            ),
          ),
        if (tail.problem != null) _Problem(words: tail.problem!),
        if (tail.notice != null) _Said(words: tail.notice!, id: 'log-replaced'),
        if (tail.dropped > 0)
          _Said(
            words: 'The ${tail.dropped} earlier lines are not kept here; the whole log stays on the machine.',
            id: 'log-dropped',
          ),
        if (tail.older == OlderLines.loading) const _Said(words: 'Reading earlier lines...', id: 'log-older-loading'),
        if (tail.older == OlderLines.failed)
          _Said(
            words: tail.olderWords ?? 'Earlier lines could not be read.',
            id: 'log-older-failed',
            action: TextButton(
              key: const Key('log-older-retry'),
              onPressed: () => unawaited(widget.logs.retryOlder(tail)),
              child: const Text('Try again'),
            ),
          ),
        if (tail.atStart && tail.lines.isNotEmpty) const _Said(words: 'This is the start of the log.', id: 'log-start'),
        if (tail.newerDropped)
          _Said(
            words: 'Newer lines are not kept while you read back.',
            id: 'log-newer-dropped',
            action: TextButton(
              key: const Key('log-newest'),
              onPressed: () => widget.logs.readNewest(tail),
              child: const Text('Show the newest'),
            ),
          ),
        Expanded(child: _lines(context, tail)),
      ],
    );
  }

  Widget _lines(BuildContext context, LogTail tail) {
    if (tail.lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.loose),
          child: Text(
            tail.problem != null ? 'Nothing was read.' : 'Nothing has been written to this log yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // What an agent writes looks like the terminal it would work in, marked with what the window can
    // tell of each line; a plain log keeps the window's look.
    final terminal = tail.formatted;
    final scheme = Theme.of(context).colorScheme;
    final padding = terminal
        ? const EdgeInsets.symmetric(horizontal: Sizes.terminalSide)
        : const EdgeInsets.symmetric(horizontal: Space.normal);
    final vertical = terminal ? Space.normal : Space.small;
    Widget line(int index) => SelectableText.rich(
      terminal
          ? markedLine(context, _shortened(tail.lines[index]))
          : TextSpan(
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              children: ansiSpans(_shortened(tail.lines[index]), scheme),
            ),
    );
    // Two lists around one centre: the lines read before the first reply grow upward from it, so that
    // putting earlier lines in front leaves what is being read where it is.
    final list = Scrollbar(
      controller: _scroll,
      child: CustomScrollView(
        controller: _scroll,
        primary: false,
        center: _center,
        slivers: <Widget>[
          SliverPadding(
            padding: padding.copyWith(top: vertical),
            sliver: SliverList.builder(
              itemCount: tail.earlier,
              itemBuilder: (context, index) => line(tail.earlier - 1 - index),
            ),
          ),
          SliverPadding(
            key: _center,
            padding: padding.copyWith(bottom: vertical),
            sliver: SliverList.builder(
              itemCount: tail.lines.length - tail.earlier,
              itemBuilder: (context, index) => line(tail.earlier + index),
            ),
          ),
        ],
      ),
    );
    return terminal ? ColoredBox(color: TerminalLook.screen.background, child: list) : list;
  }

  /// How much of one line is drawn. An agent writes whole conversations as one line of JSON, 85 000
  /// characters and more, and laying those out stalled the window (walk 9).
  static const int longestDrawn = 2000;

  static String _shortened(String line) => line.length <= longestDrawn
      ? line
      : '${line.substring(0, longestDrawn)} … (${line.length - longestDrawn} more characters)';

  /// Keeps the newest line in view, but only while following.
  ///
  /// The whole point of suspending is to read back: moving the view under somebody who has just
  /// scrolled up is the same as not having a switch at all.
  void _keepUp(LogTail tail) {
    if (tail.generation != _generation) {
      // Read again from its end: what arrives counts from nothing again.
      _generation = tail.generation;
      _drawn = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillTheView());
    if (!tail.following || tail.arrived == _drawn) return;
    _drawn = tail.arrived;
    WidgetsBinding.instance.addPostFrameCallback((_) => _toTheEnd(tail, 3));
  }

  /// Jumps to the end, and again while the end moves: a list of lines of different heights only
  /// estimates where it ends until the last lines are laid out, and one jump to the estimate left
  /// the view between the two, which flickered under a log written hard (walk 9).
  void _toTheEnd(LogTail tail, int tries) {
    if (!mounted || !tail.following || !_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (_scroll.offset == end) return;
    _jumping = true;
    try {
      _scroll.jumpTo(end);
    } finally {
      _jumping = false;
    }
    if (tries > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toTheEnd(tail, tries - 1));
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_scrolled);
    _scroll.dispose();
    super.dispose();
  }
}

/// A line above the log saying how it stands, with what a person may do about it.
class _Said extends StatelessWidget {
  const _Said({required this.words, required this.id, this.action});

  final String words;
  final String id;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.normal, Space.tight, Space.normal, 0),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.small,
      children: <Widget>[
        Text(words, key: Key(id), style: Theme.of(context).textTheme.bodySmall),
        ?action,
      ],
    ),
  );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.words});

  final String words;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant, width: Sizes.divider),
      ),
      padding: const EdgeInsets.all(Space.normal),
      child: Text(words, key: const Key('log-problem')),
    );
  }
}

/// Asks which of a task's logs to read.
///
/// The list comes from the daemon, never from a set of names held here: which files a task has
/// depends on what it started — one with no gate has no `gate.log` — so a client that knew the
/// names would offer a file that was never going to exist and would never show one a later
/// release adds. Same rule as a prompt's key: derive nothing at this end that the far end knows.
Future<String?> askWhichLog(BuildContext context, {required String task, required Future<List<Log>> logs}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _WhichLog(task: task, logs: logs),
    );

class _WhichLog extends StatelessWidget {
  const _WhichLog({required this.task, required this.logs});

  final String task;
  final Future<List<Log>> logs;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Read a log of $task'),
    content: SizedBox(
      width: Sizes.dialogSmall,
      child: FutureBuilder<List<Log>>(
        future: logs,
        builder: (context, asked) {
          if (asked.hasError) {
            return Text('Its logs could not be asked for: ${asked.error}');
          }
          if (!asked.hasData) {
            return const Center(
              child: Padding(padding: EdgeInsets.all(Space.loose), child: CircularProgressIndicator()),
            );
          }
          final found = asked.data!;
          if (found.isEmpty) {
            // A normal answer, not a failure: a task whose state directory is gone — which is
            // what stopping with purge does — has no logs at all.
            return const Padding(
              padding: EdgeInsets.all(Space.normal),
              child: Text(
                'This task has no logs. One that has been removed keeps none, and neither '
                'does a name that is not a Porelo task.',
                key: Key('no-logs'),
              ),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final log in found)
                ListTile(
                  dense: true,
                  isThreeLine: log.what != null,
                  title: Text(log.name),
                  // **The name is not always the answer.** `events.jsonl` is what the firewall
                  // blocked — the file to read when a task starts and then does nothing — and
                  // nothing about the name says so. The sentence comes from the machine, so a
                  // file added later arrives explained rather than bare.
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (log.what != null) Text(log.what!, key: const Key('what-the-log-holds')),
                      Text('${_size(log.bytes)} · last written ${log.at}'),
                    ],
                  ),
                  onTap: () => Navigator.of(context).pop(log.name),
                ),
            ],
          );
        },
      ),
    ),
    actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
  );

  /// Size as a person reads it. What it is *now*: a log being written passes it.
  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} kB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
