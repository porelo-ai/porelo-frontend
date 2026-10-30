import 'package:flutter/material.dart';

import '../app/fleet_backend.dart';
import '../app/forge_connection.dart';
import 'tokens.dart';

/// Explains the unavailable verified person picker without asking for names or keys.
Future<void> showProjectDevelopers(
  BuildContext context, {
  required String project,
  required FleetBackend backend,
  required ForgeConnection forges,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Persons in $project'),
    content: const SizedBox(
      width: Sizes.dialogSmall,
      child: Text('The verified registry person picker is not available yet.'),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ),
);
