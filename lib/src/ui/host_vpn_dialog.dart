import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/homeserver_publishing.dart';
import '../app/host_vpn.dart';
import '../app/host_runs.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'command_to_copy.dart';
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
  String? Function()? confinement,
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
      confinement: confinement,
      // Kept in the setup's protocol: the terminal that said it is gone once closed.
      failed: (line) => run.session.note('Bringing the VPN up on this computer: $line'),
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
                'This computer finds the homeserver under the same name only with its line in /etc/hosts. Run this '
                'once in a terminal of your own; it asks your sudo password and adds the line only where it is '
                'missing:',
              ),
              const CommandToCopy(command: HomeserverPublishing.laptopCommand, textKey: Key('homeserver-laptop-line')),
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
  Future<void> Function()? checkNetwork,
  bool requireFreshHandshake = false,
  bool? linux,
  String? Function()? confinement,
  ValueChanged<String>? failed,
}) async {
  HostVpnAttempt? attempt;
  var verified = false;
  // The terminal's last line when its command ended: the root step's fail line, wg-quick's own words in it.
  var said = '';
  try {
    final record = settings.hostUp(machine.hostProject);
    final host = record?.host ?? machine.hostProject;
    final network = record?.vpnNetworkNumber ?? 0;
    final interface = up ? 'porelo-$network' : record?.vpnInterface ?? 'porelo-$network';
    if (up && (linux ?? Platform.isLinux)) {
      final inspect =
          checkNetwork ??
          (open == null
              ? () => checkHostVpnNetwork(
                  host: host,
                  networkNumber: network,
                  hostsByInterface: {
                    if (record != null) record.vpnInterface: host,
                    for (final entry in settings.hostUps.entries)
                      if (entry.key != host) entry.value.vpnInterface: entry.key,
                  },
                )
              : () async {});
      await inspect();
    }
    // Other platforms retain their existing preparation refusal and terminal command.
    if (linux ?? Platform.isLinux) {
      final linkUp = await (probeLink ?? () => probeHostVpnLink(interface: interface, host: host))();
      if (!up && !linkUp) return false;
      // Setup needs an expected peer's fresh receipt; a shared VPN address cannot prove its identity.
      if (up && linkUp && !requireFreshHandshake && await (ping ?? () => pingHostVpn(networkNumber: network))()) {
        return false;
      }
      // A snap's AppArmor label is inherited by the terminal and sudo, and wg-quick's own profile refuses to run under
      // it: said before sudo, instead of a root step that fails.
      final label = (confinement ?? appArmorLabel)();
      if (label != null && label.startsWith('snap.')) {
        throw HostFilesRefused(
          'This interface runs confined by a snap ($label), where wg-quick cannot run. Start its program directly, '
          'not through the flutter snap: flutter build linux --debug, then build/linux/x64/debug/bundle/porelo_frontend.',
        );
      }
    }
    if (up) {
      if (record == null || record.vpnHostPublicKey.isEmpty || record.vpnEndpointAddress.isEmpty) {
        throw const HostFilesRefused('This server has no confirmed VPN settings. Complete its host setup first.');
      }
      attempt = await prepareHostVpn(
        project: host,
        tunnel: HostTunnel(hostPublicKey: record.vpnHostPublicKey, peerPublicKey: record.vpnPeerPublicKey),
        address: record.vpnEndpointAddress,
        secretStore: secretStore,
        hostFiles: hostFiles,
        environment: environment,
        now: now,
        checkRootTools: open == null ? null : () async {},
        forgeCa: record.forgeCa,
        networkNumber: record.vpnNetworkNumber,
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
        if (up)
          ?forgeCaWarning(machine.hostProject, settings.hostUp(machine.hostProject)?.forgeCa, (now ?? DateTime.now)()),
      ].join(' '),
      machine: Machine.local(),
      command: pending?.command ?? hostVpnDownCommand(host: host, networkNumber: network, interface: interface),
      shownCommand: up
          ? 'Install the private VPN configuration, bring it up, and check the server.'
          : 'sudo wg-quick down $interface, and this host’s names and CA out of this computer',
      completed: up ? 'The VPN check did not confirm this server.' : 'The VPN was taken down.',
      afterClose: pending?.close,
      lastLine: (line) => said = line,
      finish: pending == null
          ? null
          : (code) async {
              try {
                verified = code == 0 && await pending.verified();
                if (verified && record != null) {
                  await settings.rememberHostUp(
                    host,
                    HostUpRecord.fromStored({...record.stored, 'host': host, 'vpnInterface': interface})!,
                  );
                }
                if (!verified && said.isNotEmpty) failed?.call(said);
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

/// This process's AppArmor label; tests run under the flutter snap's own and set this to say none.
String? Function() appArmorLabel = _appArmorLabel;

/// This process's AppArmor label, as `/proc/self/attr/current` says it; null where it cannot be read.
String? _appArmorLabel() {
  try {
    final label = File('/proc/self/attr/current').readAsStringSync().replaceAll('\x00', '').trim();
    return label.isEmpty ? null : label;
  } on FileSystemException {
    return null;
  }
}
