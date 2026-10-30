import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/session.dart';
import '../app/settings.dart';
import 'tokens.dart';

/// Explains that host membership changes require Core's verified registry person list.
Future<void> openHostAdminDialog(
  BuildContext context, {
  required HostUpRecord record,
  required String action,
  String? project,
  OpenTerminal? openTerminal,
  String? secretsFile,
  Map<String, String>? environment,
  Future<void> Function(String project)? onRemoved,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Host persons'),
    content: const SizedBox(
      width: Sizes.dialogSmall,
      child: Text('Verified registry host administration is not available yet.'),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ),
);

/// Shows public completion status without a manual value handover.
class PreparedHostPanel extends StatelessWidget {
  /// Shows the checked server awaiting signed-card publication.
  const PreparedHostPanel({required this.host, super.key});

  /// The checked SSH completion.
  final PreparedHost host;
  @override
  Widget build(BuildContext context) =>
      Text('${host.name}: SSH setup completed. Signed host-card publication is not available yet.');
}

/// Opens the server's completion status.
Future<void> showPreparedHost(BuildContext context, PreparedHost host) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(host.name),
    content: PreparedHostPanel(host: host),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ),
);
