import 'package:flutter/material.dart';

import 'dialog_scroll.dart';
import 'tokens.dart';

/// How much of an environment to rebuild.
///
/// **Three, because three are real.** The image layers are base → OS packages → agent layers →
/// project snippet, so invalidating from the agent's layers genuinely keeps the packages. It is a
/// mechanism rather than a switch: there is no *"rebuild from here"*, so the middle depth works by
/// changing a build argument placed where the agent's layers begin.
enum Depth {
  /// The build runs and the layer cache decides line by line. What every task start already does.
  cached(
    'CACHED',
    'Build what changed',
    'The build runs and the cache decides line by line, so an edited project file rebuilds what '
        'it changed and nothing else. This is what starting a task already does.',
    'seconds to a minute',
  ),

  /// Replaces the agent's tooling, keeping the base image and its packages.
  agent(
    'AGENT',
    'Replace the agent’s tooling',
    'Keeps the base image and the packages on it, and installs the agent again. For an agent that '
        'was updated underneath an image that still has the old one.',
    'a minute or two',
  ),

  /// Discards the base image's packages too.
  everything(
    'EVERYTHING',
    'Discard everything and build again',
    'Throws away the packages on the base image as well, which means downloading them again. For '
        'an image somebody no longer trusts.',
    'several minutes, and it downloads',
  );

  const Depth(this.name, this.label, this.what, this.cost);

  /// As the contract spells it.
  final String name;

  /// What the choice is called.
  final String label;

  /// What it replaces and what it keeps.
  final String what;

  /// Roughly what it costs, which is half of what somebody is deciding.
  final String cost;
}

/// Asks how much to rebuild, before anything is built.
///
/// **The cost is on the choice, not in a warning afterwards.** Somebody deciding to rebuild is
/// deciding what it will cost them, and *"rebuild"* with no answer to *"how much of it"* is a
/// button people press once and then avoid.
Future<Depth?> askHowMuchToBuild(BuildContext context, {required String project}) => showDialog<Depth>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Build the environment for $project'),
    content: SizedBox(
      width: Sizes.dialogMedium,
      child: DialogScroll(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Nothing is started. This builds the image a task here would otherwise build on '
              'its way to running, which is where the first task in a project spends its '
              'minutes.',
              key: Key('nothing-is-started'),
            ),
            const SizedBox(height: Space.normal),
            for (final depth in Depth.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.small),
                child: OutlinedButton(
                  key: Key('depth-${depth.name}'),
                  onPressed: () => Navigator.of(context).pop(depth),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: Space.small),
                        Text(depth.label, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: Space.tight),
                        Text(depth.what, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: Space.tight),
                        Text(
                          'Roughly ${depth.cost}.',
                          key: Key('cost-${depth.name}'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: Space.small),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        key: const Key('build-nothing'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Not now'),
      ),
    ],
  ),
);
