import 'package:flutter/material.dart';

import '../app/fleet_model.dart';
import '../app/operations.dart';
import 'machine_view.dart';
import 'tokens.dart';

/// One line across the bottom of a machine, saying what just happened there.
///
/// The words stay put while something else runs: a status line that is replaced by a spinner
/// answers "is it busy" and forgets "did the last thing work", which is the question somebody
/// coming back to the window actually has.
class StatusLine extends StatelessWidget {
  /// Constructor taking what it reports on and the way into the record.
  const StatusLine({
    required this.fleet,
    required this.operations,
    required this.machine,
    required this.onShowOperations,
    this.highlighted = false,
    this.cannotNotify,
    super.key,
  });

  /// What is being talked to.
  final FleetModel fleet;

  /// What this session has run.
  final Operations operations;

  /// The machine, by name: only what ran there is counted.
  final String machine;

  /// Opens the record.
  final VoidCallback onShowOperations;

  /// Whether the finder went to the record.
  final bool highlighted;

  /// Why nothing can be notified, when that is so.
  final String? cannotNotify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = fleet.info;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: Sizes.progressBar,
          child: fleet.busy || operations.all.any((each) => each.machine == machine && each.running)
              ? const LinearProgressIndicator(minHeight: Sizes.progressBar)
              : null,
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.tight),
          child: Row(
            children: <Widget>[
              _Reachability(reachability: fleet.reachability),
              const SizedBox(width: Space.small),
              Expanded(
                child: Text(
                  fleet.status,
                  key: const Key('status-line'),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Flexible(
                child: Highlight(
                  active: highlighted,
                  child: _Operations(
                    operations: operations,
                    machine: machine,
                    onShow: onShowOperations,
                    autofocus: highlighted,
                  ),
                ),
              ),
              // Said rather than left silent: believing notifications are on when they are not is
              // worse than knowing they are off, which is the whole point of the requirement.
              if (cannotNotify != null)
                Padding(
                  padding: const EdgeInsets.only(left: Space.small),
                  child: Tooltip(
                    message: cannotNotify!,
                    child: Icon(Icons.notifications_off_outlined, size: Sizes.mark, color: theme.colorScheme.error),
                  ),
                ),
              if (fleet.reachability == Reachability.connected && !fleet.liveUpdates)
                Padding(
                  padding: const EdgeInsets.only(left: Space.small),
                  child: Text('not live', style: theme.textTheme.bodySmall),
                ),
              if (info != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: Space.small),
                    // The daemon's build version, for a bug report. Never for gating a feature.
                    child: Text(
                      '${fleet.backend.label} · ${info.version}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Reachability extends StatelessWidget {
  const _Reachability({required this.reachability});

  final Reachability reachability;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String words) = switch (reachability) {
      Reachability.connecting => (Icons.cloud_queue, scheme.outline, 'Connecting'),
      Reachability.connected => (Icons.cloud_done, scheme.primary, 'Connected'),
      Reachability.unreachable => (Icons.cloud_off, scheme.error, 'Not connected'),
      Reachability.incompatible => (Icons.warning_amber_outlined, scheme.error, 'Incompatible backend'),
    };
    return Tooltip(
      message: words,
      child: Icon(icon, size: Sizes.mark, color: color),
    );
  }
}

/// How much this session has run, and the way into it.
///
/// A count rather than the newest line: output belongs in the operation's own view, and a status
/// line that scrolled a build would bury the outcome of the last action under it.
class _Operations extends StatelessWidget {
  const _Operations({required this.operations, required this.machine, required this.onShow, required this.autofocus});

  final Operations operations;
  final String machine;
  final VoidCallback onShow;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final all = operations.all.where((each) => each.machine == machine).toList();
    final running = all.where((each) => each.running).length;
    final failed = all.where((operation) => operation.failed).length;
    return TextButton(
      key: const Key('operations-indicator'),
      autofocus: autofocus,
      onPressed: onShow,
      child: Text(
        all.isEmpty
            ? 'nothing run yet'
            : running > 0
            ? '$running running'
            : failed > 0
            ? '${all.length} run, $failed failed'
            : '${all.length} run',
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
