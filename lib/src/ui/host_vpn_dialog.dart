import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/homeserver_publishing.dart';
import '../app/host_vpn.dart';
import '../app/host_runs.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// Completes the retained setup only after the local VPN check succeeds.
Future<void> openPreparationVpn(
  BuildContext context, {
  required HostPreparation run,
  required HostRuns runs,
  required Settings settings,
  OpenTerminal? open,
  SecretStore? secretStore,
  HostFiles Function(SecretStore)? hostFiles,
  Map<String, String>? environment,
}) async {
  if (run.vpnOpen || run.ready || !run.awaitingVpn) return;
  runs.vpnTerminalChanged(run, open: true);
  var verified = false;
  try {
    verified = await openHostVpnDialog(
      context,
      machine: Machine(name: run.name, kind: 'host', hostProject: run.project, socketPath: ''),
      settings: settings,
      up: true,
      open: open,
      secretStore: secretStore,
      hostFiles: hostFiles,
      environment: environment,
      requireFreshHandshake: true,
    );
    await runs.vpnChecked(run, verified: verified);
    await runs.refreshVpns();
  } finally {
    runs.vpnTerminalChanged(run, open: false);
  }
  // The VPN's address exists now: the host's tasks reach the room on this computer's own homeserver. Said after the
  // VPN's own outcome, which waits on neither the transport nor this dialog.
  if (runs.homeserver case final homeserver? when verified) {
    final peer = settings.hostUp(run.project)?.vpnPeerAddress ?? run.record.vpnPeerAddress;
    final outcome = await homeserver.publish(peer);
    if (outcome != null && context.mounted) {
      await showHomeserverPublished(context, outcome, laptopLineMissing: homeserver.laptopLineMissing);
    }
  }
}

/// Says what came of publishing this computer's homeserver for the host, and gives the laptop's own line where
/// `/etc/hosts` lacks it, to be added once by hand.
Future<void> showHomeserverPublished(BuildContext context, PublishOutcome outcome, {required bool laptopLineMissing}) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your homeserver for this server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.small,
          children: [
            Text(outcome.words, key: const Key('homeserver-published')),
            if (outcome.published && laptopLineMissing) ...[
              const Text(
                'This computer finds the homeserver under the same name only with this line in /etc/hosts. Add it '
                'once, by hand, with sudo:',
              ),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(HomeserverPublishing.laptopLine, key: const Key('homeserver-laptop-line')),
                  ),
                  IconButton(
                    key: const Key('homeserver-laptop-line-copy'),
                    tooltip: 'Copy the line',
                    icon: const Icon(Icons.copy, size: Sizes.rowIcon),
                    onPressed: () =>
                        unawaited(Clipboard.setData(const ClipboardData(text: HomeserverPublishing.laptopLine))),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('homeserver-published-close'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

/// Changes the local VPN only when needed, returning true only for a fresh handshake receipt.
Future<bool> openHostVpnDialog(
  BuildContext context, {
  required Machine machine,
  required Settings settings,
  required bool up,
  OpenTerminal? open,
  SecretStore? secretStore,
  HostFiles Function(SecretStore)? hostFiles,
  Map<String, String>? environment,
  DateTime Function()? now,
  Future<bool> Function()? probeLink,
  Future<bool> Function()? ping,
  bool requireFreshHandshake = false,
  bool? linux,
}) async {
  HostVpnAttempt? attempt;
  var verified = false;
  try {
    // Other platforms retain their existing preparation refusal and terminal command.
    if (linux ?? Platform.isLinux) {
      final linkUp = await (probeLink ?? probeHostVpnLink)();
      if (!up && !linkUp) return false;
      // Setup needs an expected peer's fresh receipt; a shared VPN address cannot prove its identity.
      if (up && linkUp && !requireFreshHandshake && await (ping ?? pingHostVpn)()) return false;
    }
    if (up) {
      final record = settings.hostUp(machine.hostProject);
      if (record == null || record.vpnHostPublicKey.isEmpty || record.vpnEndpointAddress.isEmpty) {
        throw const HostFilesRefused('This server has no confirmed VPN settings. Complete its host setup first.');
      }
      attempt = await prepareHostVpn(
        project: machine.hostProject,
        tunnel: HostTunnel(hostPublicKey: record.vpnHostPublicKey, peerPublicKey: record.vpnPeerPublicKey),
        address: record.vpnEndpointAddress,
        secretStore: secretStore,
        hostFiles: hostFiles,
        environment: environment,
        now: now,
        checkRootTools: open == null ? null : () async {},
        forgeCa: settings.forgeCa,
      );
    }
    if (!context.mounted) return false;
    final pending = attempt;
    await runInATerminal(
      context,
      key: const Key('host-vpn-terminal'),
      title: '${up ? 'Bring the VPN up' : 'Take the VPN down'} for ${machine.name}',
      explanation: [
        'This changes WireGuard on this computer. Type only your sudo password into this terminal.',
        if (up) ?forgeCaWarning(settings.forgeCa, (now ?? DateTime.now)()),
      ].join(' '),
      machine: Machine.local(),
      command: pending?.command ?? hostVpnDownCommand,
      shownCommand: up
          ? 'Install the private VPN configuration, bring it up, and check the server.'
          : 'sudo wg-quick down porelo, and the forge\'s name out of /etc/hosts',
      completed: up ? 'The VPN check did not confirm this server.' : 'The VPN was taken down.',
      afterClose: pending?.close,
      finish: pending == null
          ? null
          : (code) async {
              try {
                verified = code == 0 && await pending.verified();
                return verified;
              } finally {
                await pending.close();
              }
            },
      open: open,
    );
  } on Exception catch (error) {
    await attempt?.close();
    if (context.mounted) {
      final words = switch (error) {
        HostFilesRefused(:final message) => message,
        SecretStoreFailed() => 'The system secret store could not read the VPN key.',
        _ => 'The VPN setup could not complete.',
      };
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('The VPN command cannot run'),
          content: Text(words, key: const Key('vpn-problem')),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    }
  } finally {
    await attempt?.close();
  }
  return verified;
}
