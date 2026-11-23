import 'dart:async';

import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/fleet_model.dart';
import '../app/operations.dart';
import '../app/unattended_run.dart';
import '../client/models.dart';
import 'how_long.dart';
import 'panes.dart';
import 'selection_list.dart';
import 'tokens.dart';

/// What this session has run, in the order it ran.
///
/// Somebody comes back after an hour and needs to know what happened without having watched, so
/// this is a record rather than a notification: nothing here disappears on its own.
class OperationsList extends StatelessWidget {
  /// Constructor taking the record, the keyboard and what a row opens.
  const OperationsList({
    required this.operations,
    required this.focusNode,
    required this.onOpen,
    this.machine,
    this.onClose,
    super.key,
  });

  /// Everything started in this session.
  final Operations operations;

  /// The machine whose operations are listed, or null for all of them.
  final String? machine;

  /// Puts the list away, or null where it is not over anything.
  final VoidCallback? onClose;

  /// This view's keyboard focus.
  final FocusNode focusNode;

  /// Opens one operation's output.
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final all = machine == null ? operations.all : operations.all.where((each) => each.machine == machine).toList();
    return Column(
      children: <Widget>[
        PaneHeader(
          page: true,
          title: machine == null ? 'This session' : 'What was run on $machine',
          trailing: onClose == null
              ? null
              : IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: onClose),
        ),
        if (operations.file != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
            child: SelectableText(
              'Kept for ${Operations.kept.inDays} days in ${operations.file!.path}'
              '${operations.droppedAsOld == 0 ? '' : ' — ${operations.droppedAsOld} older than that were dropped'}',
              key: const Key('operations-file'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: SelectionList<Operation>(
            items: all,
            idOf: (operation) => operation.id,
            selected: all.isEmpty ? null : all.last.id,
            onSelect: onOpen,
            onActivate: onOpen,
            focusNode: focusNode,
            emptyMessage: 'Nothing has been run from here yet.',
            rowOf: (context, operation, selected) => _OperationRow(operation: operation),
          ),
        ),
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.operation});

  final Operation operation;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      OperationMark(operation: operation),
      const SizedBox(width: Space.small),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(operation.title, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              '${operation.fromBefore ? 'earlier, ${_on(operation.startedAt)} ' : ''}'
              '${_at(operation.startedAt)} · ${operation.summary}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const Icon(Icons.chevron_right, size: Sizes.rowIcon),
    ],
  );

  static String _on(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

  static String _at(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';
}

/// Everything one operation printed.
///
/// Opening this never starts or stops anything, and leaving it never stops anything either: the
/// operation is watched by the session, not by whoever happens to be looking.
class OperationOutputView extends StatefulWidget {
  /// Constructor taking what to show and the ways out.
  const OperationOutputView({
    required this.operation,
    required this.onBack,
    required this.onClose,
    this.run,
    this.restart,
    this.signIn,
    super.key,
  });

  /// The sign-in offered where a start failed while its agent read not signed in, or null.
  final Widget? signIn;

  /// The unattended task this operation started, when it is a task start.
  final UnattendedRun? run;

  /// Opens that task's start form, with the reason it is unavailable now.
  final Command? restart;

  /// What is being watched.
  final Operation operation;

  /// Goes back to the list.
  final VoidCallback onBack;

  /// Closes the view and goes back to the frame.
  final VoidCallback onClose;

  @override
  State<OperationOutputView> createState() => _OperationOutputViewState();
}

class _OperationOutputViewState extends State<OperationOutputView> {
  final _scroll = ScrollController();
  final _newer = GlobalKey();
  final _view = GlobalKey();
  bool _openedAtEnd = false;
  bool _reading = false;
  int _lastSeen = 0;
  bool _startEnded = false;
  Timer? _age;

  @override
  void initState() {
    super.initState();
    widget.run?.addListener(_changed);
    widget.run?.follow();
    _scroll.addListener(_wantsMore);
    if (widget.operation.recordOf != null) unawaited(_open(rebuild: false));
    if (widget.run != null) _age = Timer.periodic(const Duration(minutes: 1), (_) => _changed());
  }

  /// The line on screen nearest the top, and where its top is in the view, for [_keepPlace].
  ({int index, double top})? _probe() {
    final view = _view.currentContext;
    final box = view?.findRenderObject();
    if (view == null || box is! RenderBox || !box.attached) return null;
    final viewTop = box.localToGlobal(Offset.zero).dy;
    ({int index, double top})? nearest;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is _Line) {
        final line = element.renderObject;
        if (line is RenderBox && line.attached && line.hasSize) {
          final top = line.localToGlobal(Offset.zero).dy - viewTop;
          if (top >= 0 && top < box.size.height && (nearest == null || top < nearest!.top)) {
            nearest = (index: widget.index, top: top);
          }
        }
        return;
      }
      element.visitChildren(visit);
    }

    view.visitChildElements(visit);
    return nearest;
  }

  /// Puts the reader back where they were after lines were let go of.
  ///
  /// Where the lines are counted from moved to [probe], a line the reader sees: its place is known exactly, which a
  /// distance over lines that were never built is not.
  Future<void> _keepPlace(bool moved, ({int index, double top})? probe) async {
    if (!mounted) return;
    // The lines were let go of just now, also where nothing moved: what is built must be built from them.
    setState(() {});
    if (!moved || probe == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scroll.hasClients) return;
    // The line at the center of the view lies at scroll offset zero.
    _scroll.jumpTo(-probe.top);
  }

  /// Opens the record at its end, as it is each time it is shown: a window left where an earlier opening ended is
  /// not where this one starts.
  Future<void> _open({bool rebuild = true}) async {
    final operation = widget.operation;
    operation.opened = false;
    if (rebuild) setState(() {});
    await operation.openAtEnd();
    if (!mounted) return;
    _openedAtEnd = false;
    setState(() {});
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Reads the next page of the record when the reader is near the end of what is held, at either end.
  ///
  /// Only a bounded window of the record is held: reading at one end lets go of the other.
  void _wantsMore() {
    final operation = widget.operation;
    if (_reading || operation.opening || !_scroll.hasClients || operation.source == null) return;
    if (operation.readProblem != null) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    const near = 400.0;
    final older = operation.hasOlder && position.pixels - position.minScrollExtent < near;
    final newer = !older && operation.hasNewer && position.maxScrollExtent - position.pixels < near;
    if (!older && !newer) return;
    _reading = true;
    // After the frame that follows: where the lines lie on screen is known only once it is laid out, and the lines
    // change under it, which it is told at once.
    final probed = Completer<({int index, double top})?>();
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => probed.complete(mounted ? _probe() : null))
      ..ensureVisualUpdate();
    unawaited(
      probed.future
          .then((probe) {
            if (!mounted) return false;
            return older
                ? operation.loadOlder(keep: probe?.index, settle: (moved) => _keepPlace(moved, probe))
                : operation.loadNewer(keep: probe?.index, settle: (moved) => _keepPlace(moved, probe));
          })
          .whenComplete(() {
            _reading = false;
            if (!mounted) return;
            setState(() {});
            // A page may not fill the view, and a failed one is shown rather than asked for again.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _wantsMore();
            });
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    final steps = operation.steps.values.toList();
    final run = widget.run;
    final leave = leaveWorkCommand(widget.onClose);
    _followTheEnd(operation.output.length);

    return Column(
      children: <Widget>[
        PaneHeader(
          page: true,
          title: operation.title,
          leading: BackButton(onPressed: widget.onBack),
          trailing: run != null && !operation.running
              ? TextButton.icon(
                  key: const Key('leave-run'),
                  onPressed: leave.run,
                  icon: const Icon(Icons.logout, size: Sizes.rowIcon),
                  label: Text(leave.label),
                )
              : IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: widget.onClose),
        ),
        _Summary(operation: operation),
        if (widget.signIn case final signIn?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.normal),
            child: signIn,
          ),
        if (operation.readProblem case final problem?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Reading what it printed failed: $problem',
                    key: const Key('record-read-failed'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  key: const Key('record-read-again'),
                  onPressed: () async {
                    operation.readProblem = null;
                    if (operation.source == null && operation.recordOf != null) {
                      // Opening the record is what failed: that is what is tried again.
                      await _open();
                      return;
                    }
                    setState(() {});
                    _wantsMore();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        if (operation.linesMissing)
          _Note(
            key: const Key('lines-missing'),
            text: operation.source == null
                ? 'Its ${operation.linesGone} lines are missing: the file that held them is not there.'
                : '${operation.linesGone} of the lines it printed are missing from the file that holds them.',
          ),
        if (operation.linesLost > 0)
          _Note(
            key: const Key('lines-lost'),
            text: '${operation.linesLost} lines it printed could not be kept in its record.',
          ),
        Expanded(
          child: operation.recordOf != null && !operation.opened
              ? Center(
                  child: Text(
                    'Reading what it printed…',
                    key: const Key('record-opening'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : operation.output.isEmpty && steps.isEmpty && (run == null || operation.running || operation.failed)
              ? Center(
                  child: Text(
                    operation.running
                        ? 'Nothing printed yet.'
                        : operation.readProblem != null
                        ? 'What it printed could not be read.'
                        : operation.linesMissing
                        ? 'What it printed is not there to be read.'
                        : operation.fromBefore && operation.linesPrinted == null
                        ? 'The record does not say whether it printed anything.'
                        : 'It printed nothing at all.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : Scrollbar(controller: _scroll, child: _lines(operation, steps, run)),
        ),
      ],
    );
  }

  /// The lines, growing up from where the record was opened and down from it, so that reading older lines
  /// never moves what is on screen.
  Widget _lines(Operation operation, List<StartStep> steps, UnattendedRun? run) {
    final before = operation.anchor;
    final after = operation.output.length - before;
    final starts = !operation.hasOlder;
    // Nothing that was read from the file lies above where the lines begin, so the steps start the lines below.
    final stepsBelow = operation.source == null || (starts && before == 0);
    final upward = before + (stepsBelow ? 0 : (starts ? steps.length + 1 : 1));
    final runState = run != null && !operation.running && !operation.failed && !operation.hasNewer;
    const padding = EdgeInsets.symmetric(horizontal: Space.normal);
    const style = TextStyle(fontFamily: 'monospace', fontSize: 12);
    return CustomScrollView(
      key: _view,
      controller: _scroll,
      primary: false,
      center: _newer,
      slivers: <Widget>[
        SliverPadding(
          padding: padding.copyWith(top: Space.small),
          sliver: SliverList.builder(
            itemCount: upward,
            // Counted from the middle outward: the line just before it first, the start last.
            itemBuilder: (context, index) => index < before
                ? _Line(before - 1 - index, operation.output[before - 1 - index], style)
                : starts && index - before < steps.length
                ? _StartStepView(step: steps[steps.length - 1 - (index - before)])
                // The same row, same height, whether older lines wait or the start is reached: nothing under the
                // reader moves when the last page is read.
                : Text(
                    starts ? 'This is where it began.' : 'Older lines are read from the file as you scroll up.',
                    key: Key(starts ? 'record-start' : 'older-lines'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          ),
        ),
        SliverPadding(
          key: _newer,
          padding: padding.copyWith(bottom: Space.small),
          sliver: SliverList.builder(
            itemCount: (stepsBelow ? steps.length : 0) + after + (runState ? 1 : 0),
            itemBuilder: (context, index) {
              final at = index - (stepsBelow ? steps.length : 0);
              if (at < 0) return _StartStepView(step: steps[index]);
              if (at == after) return _RunState(run: run!, restart: widget.restart);
              return _Line(before + at, operation.output[before + at], style);
            },
          ),
        ),
      ],
    );
  }

  /// Keeps the newest line in view while it is still being written to.
  ///
  /// The start's end is followed once so the task state is visible; later updates keep the reader's place.
  void _followTheEnd(int lines) {
    final justEnded = widget.run != null && !widget.operation.running && !widget.operation.failed && !_startEnded;
    if (!_openedAtEnd && widget.operation.source != null && widget.operation.opened && !widget.operation.opening) {
      // A record read back opens at its end, where what happened last is.
      _openedAtEnd = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        _wantsMore();
      });
    }
    if (!justEnded && (!widget.operation.running || lines == _lastSeen)) return;
    if (justEnded) _startEnded = true;
    _lastSeen = lines;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _age?.cancel();
    _scroll.removeListener(_wantsMore);
    widget.run?.removeListener(_changed);
    widget.run?.unfollow();
    _scroll.dispose();
    super.dispose();
  }
}

/// One line of what was printed, knowing which it is, so that the reader's place can be kept by it.
class _Line extends StatelessWidget {
  const _Line(this.index, this.text, this.style);

  final int index;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SelectableText(text, style: style);
}

class _Note extends StatelessWidget {
  const _Note({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _RunState extends StatelessWidget {
  const _RunState({required this.run, required this.restart});

  final UnattendedRun run;
  final Command? restart;

  @override
  Widget build(BuildContext context) {
    final task = run.task;
    final age = howLongSince(DateTime.tryParse(task?.lastWrote ?? ''));
    final connected = run.fleet?.reachability == Reachability.connected;
    final state = switch (task?.activity.name) {
      'WORKING' => 'Working',
      'IDLE' => 'Resting',
      'AT_REST' => 'At rest',
      'DONE' => 'Done',
      'ENDED' => 'Ended',
      'WAITING' => 'Waiting for clearance${task!.waitingFor.isEmpty ? '' : ': ${task.waitingFor}'}',
      '' || null => 'The agent state has not been reported',
      final other => other,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The task runs; the agent works now'),
          Text('${run.named} · ${run.project} · ${run.machine.name}'),
          if (!connected) const Text('Lost contact with the machine; showing its last report.'),
          Text(state),
          if (run.lastLine != null) SelectableText(run.lastLine!),
          if (age != null) Text('no output for $age'),
          if (run.problem != null) SelectableText('The run could not be read: ${run.problem}'),
          if (task?.activity.name == 'ENDED' && (task?.inboxWaiting ?? 0) > 0 && restart != null)
            Tooltip(
              message: restart!.unavailable ?? restart!.label,
              child: TextButton(
                key: const Key('restart-run'),
                onPressed: restart!.available ? restart!.run : null,
                child: Text(restart!.label),
              ),
            ),
          if (task?.activity.name == 'ENDED' && (task?.inboxWaiting ?? 0) > 0)
            if (restart?.unavailable case final why?) Text(why, key: const Key('restart-run-why')),
        ],
      ),
    );
  }
}

class _StartStepView extends StatelessWidget {
  const _StartStepView({required this.step});

  final StartStep step;

  @override
  Widget build(BuildContext context) {
    final icon = switch (step.state) {
      'STARTED' => Icons.autorenew_outlined,
      'WAITING' => Icons.hourglass_empty,
      'DONE' => Icons.check_circle_outline,
      'FAILED' => Icons.error_outline,
      _ => Icons.help_outline,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: Sizes.mark),
          const SizedBox(width: Space.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText(step.text),
                if (!const <String>[
                  'SOURCE',
                  'CHECKS',
                  'CREDENTIALS',
                  'WORKSPACE',
                  'CONVERSATION',
                  'IMAGE',
                  'CONTAINER',
                  'HELPERS',
                  'AGENT',
                ].contains(step.step))
                  Text(step.step),
                if (!const <String>['STARTED', 'WAITING', 'DONE', 'FAILED'].contains(step.state)) Text(step.state),
                if (step.state == 'WAITING' && step.waitingOn.isNotEmpty) SelectableText('waits on ${step.waitingOn}'),
                if (step.state == 'FAILED' && step.cause.isNotEmpty) SelectableText(step.cause),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.operation});

  final Operation operation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: operation.failed ? scheme.surfaceContainerLow : scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
      child: Row(
        children: <Widget>[
          OperationMark(operation: operation),
          const SizedBox(width: Space.small),
          Expanded(child: Text(operation.summary)),
        ],
      ),
    );
  }
}

/// Whether an operation is going, went well, or failed — the same mark wherever it is shown.
class OperationMark extends StatelessWidget {
  /// Constructor taking the operation to mark.
  const OperationMark({required this.operation, super.key});

  /// What is being marked.
  final Operation operation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (operation.running) {
      return SizedBox(
        width: Sizes.operationSpinner,
        height: Sizes.operationSpinner,
        child: CircularProgressIndicator(strokeWidth: Sizes.spinnerStroke, color: scheme.primary),
      );
    }
    return Icon(
      operation.failed ? Icons.error_outline : Icons.check_circle_outline,
      size: Sizes.mark,
      color: operation.failed ? scheme.error : scheme.primary,
    );
  }
}
