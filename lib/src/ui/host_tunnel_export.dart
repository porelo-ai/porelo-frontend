import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/host_vpn.dart';
import '../app/settings.dart';

/// Saves the explicitly chosen tunnel file, keeping its path only after a successful export.
Future<void> saveHostTunnel(
  BuildContext context, {
  required String project,
  required HostTunnel? tunnel,
  required String address,
  Settings? settings,
  SecretStore? secretStore,
  HostFiles Function(SecretStore)? hostFiles,
  Future<String?> Function()? saveTunnel,
  ValueChanged<bool>? saving,
  ValueChanged<String>? refused,
}) async {
  String? problem;
  try {
    final path = saveTunnel == null ? (await getSaveLocation(suggestedName: 'porelo.conf'))?.path : await saveTunnel();
    if (path == null || !context.mounted) return;
    checkVpnSaveFile(path);
    saving?.call(true);
    final record = settings?.hostUp(project);
    final connection =
        tunnel ??
        (record == null
            ? null
            : HostTunnel(hostPublicKey: record.vpnHostPublicKey, peerPublicKey: record.vpnPeerPublicKey));
    final endpoint = address.isEmpty ? record?.vpnEndpointAddress ?? '' : address;
    if (connection == null ||
        connection.hostPublicKey.isEmpty ||
        connection.peerPublicKey.isEmpty ||
        endpoint.isEmpty) {
      throw const HostFilesRefused(
        'The saved host setup lacks tunnel settings. Use Put this project on a server… again.',
      );
    }
    await withHostFiles(
      (files) => files.exportTunnel(
        project: record?.host ?? project,
        tunnel: connection,
        address: endpoint,
        destination: File(path),
        networkNumber: record?.vpnNetworkNumber ?? 0,
      ),
      secretStore: secretStore,
      hostFiles: hostFiles,
    );
    final kept = settings?.hostUp(project);
    if (kept != null) {
      await settings!.rememberHostUp(
        project,
        kept.withTunnel(hostPublicKey: connection.hostPublicKey, address: endpoint).withVpnFile(path),
      );
    }
  } on FormatException catch (error) {
    problem = error.message;
  } on HostFilesRefused catch (error) {
    problem = error.message;
  } on FileSystemException catch (error) {
    problem = 'Cannot save the tunnel file: ${error.path ?? "selected file"}.';
  } on SecretStoreFailed {
    problem = 'The system secret store could not read the WireGuard key.';
  } finally {
    if (context.mounted) saving?.call(false);
  }
  if (!context.mounted || problem == null) return;
  if (refused != null) {
    refused(problem);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('The VPN connection could not be saved'),
      content: Text(problem!, key: const Key('vpn-problem')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}
