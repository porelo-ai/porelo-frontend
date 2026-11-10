import 'package:flutter/material.dart';

import '../app/central_release.dart';
import 'tokens.dart';

/// Asks before [project]'s finished `main` on [host] goes to the central forge, naming the commits [ahead] brings.
/// Answers true only where the person agreed.
Future<bool> confirmBringToCentral(
  BuildContext context, {
  required String project,
  required String host,
  required List<AheadOfCentral> ahead,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('bring-to-central'),
        title: Text('Bring $project to central?'),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: Text(
            'This brings ${commitsToBring(ahead)} from the approved main on $host to the central forge, where '
            'everyone who reads central gets them. A push to central is not called back.\n\n'
            'Central’s main is never forced: where it has moved on, that repository is not pushed, and its commits '
            'come to the host for a task to merge.',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('bring-them-to-central'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bring them to central'),
          ),
        ],
      ),
    ) ??
    false;
