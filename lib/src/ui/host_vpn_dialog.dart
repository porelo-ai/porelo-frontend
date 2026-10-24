import 'dart:io';

import 'package:flutter/material.dart';

import '../app/host_vpn.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// Runs the host's VPN command on this computer; sudo alone asks for root in the terminal.
/// [deleteSavedFile] replaces only the explicitly requested deletion in tests.
Future<void> openHostVpnDialog(
  BuildContext context, {
  required Machine machine,
  required Settings settings,
  required bool up,
  OpenTerminal? open,
  Future<void> Function(String file)? deleteSavedFile,
}) async {
  final file = settings.hostUp(machine.hostProject)?.vpnFile;
  final List<String> command;
  try {
    if (up && file == null) {
      throw const FormatException('Save the VPN connection to this server first.');
    }
    command = up ? hostVpnUpCommand(file!) : ['sudo', 'wg-quick', 'down', 'porelo'];
  } on FormatException catch (error) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('The VPN command cannot run'),
        content: Text(error.message, key: const Key('vpn-problem')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
    return;
  }
  if (!context.mounted) return;
  int? exit;
  await runInATerminal(
    context,
    title: '${up ? 'Bring the VPN up' : 'Take the VPN down'} for ${machine.name}',
    explanation: 'This changes WireGuard on this computer and needs root; sudo asks for it in this terminal.',
    machine: Machine.local(),
    command: command,
    shownCommand: up
        ? "sudo install -m 600 '$file' /etc/wireguard/porelo.conf && sudo wg-quick up porelo"
        : command.join(' '),
    completed: up ? 'The VPN command completed successfully.' : 'The VPN was taken down.',
    onExit: (code) => exit = code,
    open: open,
  );
  if (!context.mounted || !up || exit != 0) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteVpnFile(
      file: file!,
      project: machine.hostProject,
      settings: settings,
      deleteSavedFile:
          deleteSavedFile ??
          (file) async {
            await File(file).delete();
          },
    ),
  );
}

class _DeleteVpnFile extends StatefulWidget {
  const _DeleteVpnFile({
    required this.file,
    required this.project,
    required this.settings,
    required this.deleteSavedFile,
  });

  final String file;
  final String project;
  final Settings settings;
  final Future<void> Function(String file) deleteSavedFile;

  @override
  State<_DeleteVpnFile> createState() => _DeleteVpnFileState();
}

class _DeleteVpnFileState extends State<_DeleteVpnFile> {
  String? _problem;
  bool _busy = false;

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await widget.deleteSavedFile(widget.file);
      final kept = widget.settings.hostUp(widget.project);
      if (kept?.vpnFile == widget.file) {
        await widget.settings.rememberHostUp(widget.project, kept!.withVpnFile(null));
      }
      if (mounted) Navigator.pop(context);
    } on FileSystemException {
      if (mounted) {
        setState(() => _problem = 'The saved VPN file could not be deleted or its removal kept in settings.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete the saved VPN file?'),
    content: SizedBox(
      width: Sizes.dialogMedium,
      child: DialogScroll(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This file holds the private key. The installed connection now sits in /etc/wireguard/porelo.conf. Delete the saved copy?',
            ),
            SelectableText(widget.file),
            if (_problem != null) Text(_problem!, key: const Key('vpn-problem')),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('vpn-keep'),
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Keep it'),
      ),
      FilledButton(
        key: const Key('vpn-delete'),
        onPressed: _busy ? null : _delete,
        child: const Text('Delete the saved file'),
      ),
    ],
  );
}
