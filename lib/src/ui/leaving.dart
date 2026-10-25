import 'package:flutter/material.dart';

import 'dialog_scroll.dart';
import 'tokens.dart';

/// Asks before leaving, naming what carries on without the window.
Future<bool> confirmQuit(
  BuildContext context, {
  required List<String> running,
  required int waiting,
  List<String> preparing = const [],
  List<String> continuingSetup = const [],
  Future<void> Function()? onLeave,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        var leaving = false;
        String? problem;
        return StatefulBuilder(
          builder: (context, setState) => PopScope(
            canPop: !leaving,
            child: AlertDialog(
              title: const Text('Close Porelo?'),
              content: SizedBox(
                width: Sizes.dialogSmall,
                child: DialogScroll(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        running.isEmpty && preparing.isEmpty
                            ? 'Nothing is running. Closing this changes nothing on any machine.'
                            : 'Remote work keeps running without this window. Server preparations are listed below:',
                        key: const Key('what-keeps-running'),
                      ),
                      if (running.isNotEmpty) ...<Widget>[
                        const SizedBox(height: Space.small),
                        for (final task in running)
                          Padding(
                            padding: const EdgeInsets.only(left: Space.normal, top: Space.tight),
                            child: Text(task, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          ),
                      ],
                      for (final project in preparing)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.normal),
                          child: Text(
                            continuingSetup.contains(project)
                                ? '$project server: Setup runs on without the interface; it shows again when you start it'
                                : '$project server: Setup stops if it is still renting; the server stays rented and billed. Go on from Needs you.',
                            key: ValueKey('leaving-host $project'),
                          ),
                        ),
                      if (problem != null) Text(problem!),
                      // Questions with deadlines expire while the interface is closed.
                      if (waiting > 0) ...<Widget>[
                        const SizedBox(height: Space.normal),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Space.normal),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                              width: Sizes.divider,
                            ),
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(Radii.small),
                          ),
                          child: Text(
                            '$waiting ${waiting == 1 ? 'decision is' : 'decisions are'} waiting. '
                            'Nothing will be listening for them once this closes, and they run out on '
                            'their own.',
                            key: const Key('what-will-be-missed'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  key: const Key('quit-cancel'),
                  onPressed: leaving ? null : () => Navigator.of(context).pop(false),
                  child: Text(preparing.isEmpty ? 'Stay' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: leaving
                      ? null
                      : () async {
                          setState(() => leaving = true);
                          try {
                            await onLeave?.call();
                            if (context.mounted) Navigator.of(context).pop(true);
                          } on Exception {
                            if (context.mounted) {
                              setState(() {
                                leaving = false;
                                problem = 'Setup could not be stopped. Keep the interface open and try leaving again.';
                              });
                            }
                          }
                        },
                  child: Text(preparing.isEmpty ? 'Close it' : 'Leave'),
                ),
              ],
            ),
          ),
        );
      },
    ) ??
    false;

/// Says a newer build has been installed underneath, and offers to restart into it.
///
/// Declining leaves everything exactly as it was: nothing here restarts anything on its own.
class NewerVersionBanner extends StatelessWidget {
  /// Constructor taking what restarting does.
  const NewerVersionBanner({required this.onRestart, super.key});

  /// Restarts into the newer build.
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.tertiaryContainer,
    padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.small),
    child: Row(
      children: <Widget>[
        const Icon(Icons.upgrade, size: Sizes.rowIcon),
        const SizedBox(width: Space.small),
        const Expanded(
          child: Text(
            'A newer Porelo has been installed. This window is still running the old one.',
            key: Key('newer-version'),
          ),
        ),
        TextButton(onPressed: onRestart, child: const Text('Restart into it')),
      ],
    ),
  );
}
