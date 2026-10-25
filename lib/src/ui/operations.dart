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
    super.key,
  });

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
  int _lastSeen = 0;
  bool _startEnded = false;
  Timer? _age;

  @override
  void initState() {
    super.initState();
    widget.run?.addListener(_changed);
    widget.run?.follow();
    if (widget.run != null) _age = Timer.periodic(const Duration(minutes: 1), (_) => _changed());
  }

  void _changed() {
    if (mounted) setState(() {});
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
        if (operation.linesNotKept > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
            child: Text(
              'The first ${operation.linesNotKept} lines it printed were not kept.',
              key: const Key('lines-not-kept'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: operation.output.isEmpty && steps.isEmpty && (run == null || operation.running || operation.failed)
              ? Center(
                  child: Text(
                    operation.running ? 'Nothing printed yet.' : 'It printed nothing at all.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : Scrollbar(
                  controller: _scroll,
                  child: ListView.builder(
                    controller: _scroll,
                    primary: false,
                    padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
                    itemCount:
                        steps.length +
                        operation.output.length +
                        (run != null && !operation.running && !operation.failed ? 1 : 0),
                    itemBuilder: (context, index) => index == steps.length + operation.output.length
                        ? _RunState(run: run!, restart: widget.restart)
                        : index < steps.length
                        ? _StartStepView(step: steps[index])
                        : SelectableText(
                            operation.output[index - steps.length],
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                  ),
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
    widget.run?.removeListener(_changed);
    widget.run?.unfollow();
    _scroll.dispose();
    super.dispose();
  }
}

class _RunState extends StatelessWidget {
  const _RunState({required this.run, required this.restart});

  final UnattendedRun run;
  final Command? restart;

  @override
  Widget build(BuildContext context) {
    final task = run.task;
    final age = howLongSince(DateTime.tryParse(task?.lastWrote ?? ''));
    final connected = run.fleet.reachability == Reachability.connected;
    final state = switch (task?.activity.name) {
      'WORKING' => 'Working',
      'IDLE' => 'Resting',
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
