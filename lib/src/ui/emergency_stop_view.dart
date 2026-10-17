import 'package:flutter/material.dart';

import '../app/emergency_stop.dart';
import '../app/fleet_backend.dart';
import 'tokens.dart';
import 'window_size.dart';
import 'dialog_scroll.dart';

/// The button that cuts everything off, always on screen.
///
/// **Not in a menu.** Somebody reaching for this has just realized something is wrong and does not
/// yet know what; a person in that minute does not go looking through menus. It is deliberately
/// plain rather than loud: an alarm-colored button sitting on every screen all day stops being
/// read, and this one has to be read the first time it matters.
class EmergencyStopButton extends StatelessWidget {
  /// Constructor taking what pressing it does.
  const EmergencyStopButton({required this.onPressed, super.key});

  /// Opens the confirmation. **Never stops anything by itself** — one press away from stopping a
  /// machine is not a design, it is an accident waiting for a stray click.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).colorScheme.error;
    final icon = Icon(Icons.pan_tool_outlined, size: Sizes.rowIcon, color: red);

    return Tooltip(
      message:
          'Stop everything on this machine (Ctrl+Shift+.)\n'
          'Work is stopped, never removed.',
      // The label goes on a narrow window; **the button never does.** An emergency stop that fell
      // off the edge would be missing exactly when somebody reached for it — which is what a
      // scenario about narrow windows caught, with the whole status line overflowing.
      child: WindowSize.fromContext(context).statusLineShowsLabels
          ? TextButton.icon(
              key: const Key('stop-everything'),
              onPressed: onPressed,
              icon: icon,
              label: Text('Stop everything', style: TextStyle(color: red)),
            )
          : IconButton(
              key: const Key('stop-everything'),
              onPressed: onPressed,
              icon: icon,
              visualDensity: VisualDensity.compact,
            ),
    );
  }
}

/// Asks before stopping everything, then says what survived.
///
/// Two things it will not do. **It never stops on the first press** — what would be stopped is
/// shown first, and agreeing to it is a second, separate act. And **the stop is never the default
/// choice**: leaving is, so a stray Return or a mis-aimed click carries nothing.
Future<void> openEmergencyStop(
  BuildContext context, {
  required EmergencyStop stopping,
  required VoidCallback onStopEverything,
}) => showDialog<void>(
  context: context,
  builder: (context) => EmergencyStopDialog(stopping: stopping, onStopEverything: onStopEverything),
);

/// The dialog itself, separated so it can be built directly in a test.
class EmergencyStopDialog extends StatelessWidget {
  /// Constructor taking the model and what agreeing does.
  const EmergencyStopDialog({required this.stopping, required this.onStopEverything, super.key});

  /// What would be stopped, and what was.
  final EmergencyStop stopping;

  /// Stops everything.
  final VoidCallback onStopEverything;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: stopping,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final done = stopping.done;
      final preview = stopping.preview;

      return AlertDialog(
        title: Text(done == null ? 'Stop everything?' : 'Everything is stopped'),
        content: SizedBox(
          width: Sizes.emergencyStopDialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (stopping.problem != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Space.normal),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(Radii.small),
                    ),
                    child: Text(stopping.problem!, key: const Key('stop-problem')),
                  )
                else if (done != null) ...<Widget>[
                  Text(stopping.words, key: const Key('stop-result'), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: Space.normal),
                  // The sentence that keeps somebody from going looking for work that is
                  // still there. It stops; it does not clear away.
                  const Text(
                    'Every workspace, every log and every commit that never reached the gate '
                    'is exactly where it was.',
                    key: Key('nothing-was-removed'),
                  ),
                  const SizedBox(height: Space.wide),
                  Text('What was stopped', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Space.tight),
                  // Named, because the name is what `Start` takes: the row that says what
                  // was stopped is the row that says how to bring it back.
                  for (final task in done.tasks)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.tight),
                      child: Text(
                        task.helpers == 0
                            ? task.name
                            : '${task.name}  ·  ${task.helpers} '
                                  '${task.helpers == 1 ? 'helper' : 'helpers'}',
                        key: const Key('stopped-task'),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  if (done.surviving.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Space.wide),
                    Text('Still running, and not stopped by this', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: Space.tight),
                    const Text(
                      'These outlived their stop. Nothing here can end them; they have to be '
                      'killed on the machine by hand.',
                    ),
                    for (final helper in done.surviving)
                      Padding(
                        padding: const EdgeInsets.only(left: Space.small, top: Space.tight),
                        child: Text(
                          helper,
                          key: const Key('surviving-helper'),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                  ],
                  const SizedBox(height: Space.wide),
                  Text('Getting back to work', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Space.tight),
                  for (final step in stopping.howToRecover)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.tight),
                      child: Text('· $step', key: const Key('how-to-recover')),
                    ),
                ] else ...<Widget>[
                  const Text(
                    'This stops every piece of work on this machine at once, and everything '
                    'helping it: what it can reach, what it can authenticate with, and what '
                    'it can push.',
                  ),
                  const SizedBox(height: Space.normal),
                  // Said before the button, not after it. Somebody hesitating over this needs
                  // to know it is recoverable more than they need to know what it costs.
                  const Text(
                    'Nothing is removed. Work comes back with the workspace, the branch and '
                    'the commits it had.',
                    key: Key('nothing-will-be-removed'),
                  ),
                  if (stopping.busy) ...<Widget>[
                    const SizedBox(height: Space.normal),
                    const Text('Asking what is running…'),
                  ] else if (preview != null) ...<Widget>[
                    const SizedBox(height: Space.normal),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Space.normal),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(Radii.small),
                      ),
                      child: Text(
                        preview.stopped == 0
                            ? 'Nothing is running. This would stop nothing.'
                            // "that are running", never a total: a task already stopped is
                            // not in the answer, so a total would be one this call never saw.
                            : 'This would stop the ${preview.stopped} '
                                  '${preview.stopped == 1 ? 'piece' : 'pieces'} of work '
                                  'that ${preview.stopped == 1 ? 'is' : 'are'} running.',
                        key: const Key('what-would-stop'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (done != null || stopping.problem != null)
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Right'))
          else ...<Widget>[
            // The default, and the primary button: a stray Return leaves rather than stops a
            // machine. The one that acts is deliberately the plainer of the two.
            FilledButton(
              key: const Key('leave-it-running'),
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Leave it running'),
            ),
            TextButton(
              key: const Key('stop-it-all'),
              onPressed: stopping.busy ? null : onStopEverything,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('Stop everything'),
            ),
          ],
        ],
      );
    },
  );
}

/// Asks before stopping everything on every machine, then says what survived on each.
///
/// The same two refusals as one machine's: nothing stops on the first press, and leaving is the
/// default. Each machine is asked on its own, so one that cannot be reached says so and the others
/// still stop.
Future<void> openEmergencyStopEverywhere(BuildContext context, {required Map<String, FleetBackend> machines}) =>
    showDialog<void>(
      context: context,
      builder: (context) => _Everywhere(machines: machines),
    );

class _Everywhere extends StatefulWidget {
  const _Everywhere({required this.machines});

  final Map<String, FleetBackend> machines;

  @override
  State<_Everywhere> createState() => _EverywhereState();
}

class _EverywhereState extends State<_Everywhere> {
  late final Map<String, EmergencyStop> _stops = <String, EmergencyStop>{
    for (final name in widget.machines.keys) name: EmergencyStop(),
  };
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    for (final MapEntry(:key, :value) in _stops.entries) {
      value.addListener(_changed);
      value.consider(widget.machines[key]!);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _stopEverything() async {
    setState(() => _stopped = true);
    await Future.wait(<Future<void>>[
      for (final MapEntry(:key, :value) in _stops.entries) value.stopEverything(widget.machines[key]!),
    ]);
  }

  String _about(EmergencyStop stop) {
    if (stop.busy) return 'asking…';
    if (stop.problem != null) return stop.problem!;
    if (stop.done != null) return stop.words;
    final preview = stop.preview;
    if (preview == null) return '';
    return preview.tasks.isEmpty
        ? 'nothing is running'
        : 'would stop ${preview.tasks.map((task) => task.name).join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('Stop everything on every machine?'),
      content: SizedBox(
        width: Sizes.emergencyStopDialog,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Work is stopped, never removed: every workspace, log and commit stays '
                'where it is, and Start brings each piece of work back.',
              ),
              const SizedBox(height: Space.normal),
              for (final MapEntry(:key, :value) in _stops.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.small),
                  child: Text.rich(
                    key: ValueKey<String>('everywhere $key'),
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ': ${_about(value)}'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_stopped ? 'Close' : 'Leave it'),
        ),
        if (!_stopped)
          FilledButton(
            key: const Key('stop-everywhere-now'),
            style: FilledButton.styleFrom(backgroundColor: red),
            onPressed: _stopEverything,
            child: const Text('Stop everything everywhere'),
          ),
      ],
    );
  }

  @override
  void dispose() {
    for (final stop in _stops.values) {
      stop
        ..removeListener(_changed)
        ..dispose();
    }
    super.dispose();
  }
}
