import 'package:flutter/material.dart';

/// The same machine line under every attention row's heading.
class NeedsMachine extends StatelessWidget {
  /// Names the machine whose condition or action this row describes.
  const NeedsMachine(this.machine, {super.key});

  /// The machine's display name.
  final String machine;

  @override
  Widget build(BuildContext context) => Text(
    'on ${machine.isEmpty ? 'this window' : machine}',
    key: const Key('needs-machine'),
    style: Theme.of(context).textTheme.bodySmall,
  );
}
