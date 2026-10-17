import 'package:flutter/material.dart';

import '../app/operations.dart';
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
  const OperationOutputView({required this.operation, required this.onBack, required this.onClose, super.key});

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

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    _followTheEnd(operation.output.length);

    return Column(
      children: <Widget>[
        PaneHeader(
          title: operation.title,
          leading: BackButton(onPressed: widget.onBack),
          trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: widget.onClose),
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
          child: operation.output.isEmpty
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
                    itemCount: operation.output.length,
                    itemBuilder: (context, index) => SelectableText(
                      operation.output[index],
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
  /// Only while running: scrolling somebody's place away after it has finished would take the
  /// thing they opened it to read off the screen.
  void _followTheEnd(int lines) {
    if (!widget.operation.running || lines == _lastSeen) return;
    _lastSeen = lines;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
      color: operation.failed ? scheme.errorContainer : scheme.surfaceContainerHighest,
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
