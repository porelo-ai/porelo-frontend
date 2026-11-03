import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show forgeAddress;

import '../app/core_credentials.dart';
import '../app/device_key.dart';
import '../app/fleet_backend.dart';
import '../app/forge_connection.dart';
import '../app/keystore.dart';
import '../app/machines.dart';
import '../app/organization_source.dart';
import '../app/run_here.dart';
import '../app/session.dart';
import '../app/vault.dart';
import '../app/vault_unlock.dart';
import 'forges_view.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';
import 'vault_actions.dart';

/// The independent comparison required before trusting any fetched host key.
const hostKeyComparisonWords = "Compare this with what your provider or the forge's own page publishes";

/// Decides when a read that met an unknown host key may ask the person: never from a timer, and once per host at a time.
class ForgeTrustAsking {
  /// Asks through [show].
  ForgeTrustAsking(this.show);

  /// Puts the question to the person.
  final Future<bool> Function(String host) show;

  final _open = <String, Future<bool>>{};
  int _quiet = 0;

  /// Runs [reads], which nobody asked for: an unknown key found in them is said and not asked about.
  Future<void> quietly(Future<void> Function() reads) async {
    _quiet++;
    try {
      await reads();
    } finally {
      _quiet--;
    }
  }

  /// Whether the host's key is now trusted; reads running side by side share one dialog.
  Future<bool> ask(String host) {
    if (_quiet > 0) return Future<bool>.value(false);
    return _open[host] ??= show(host).whenComplete(() {
      _open.remove(host);
    });
  }
}

/// Shows Core's offered keys and records only the one the person explicitly confirms.
Future<bool> trustOrganizationForge(BuildContext context, String host, {CoreCredentials? core}) async {
  final credentials = core ?? CoreCredentials();
  return await showDialog<bool>(
        context: context,
        builder: (_) => _ForgeHostDialog(host: host, core: credentials),
      ) ??
      false;
}

class _ForgeHostDialog extends StatefulWidget {
  const _ForgeHostDialog({required this.host, required this.core});

  final String host;
  final CoreCredentials core;

  @override
  State<_ForgeHostDialog> createState() => _ForgeHostDialogState();
}

class _ForgeHostDialogState extends State<_ForgeHostDialog> {
  List<OfferedHostKey> _keys = [];
  OfferedHostKey? _chosen;
  String? _problem;
  bool _busy = true;
  bool _known = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final offer = await widget.core.offered(widget.host);
      if (!mounted) return;
      setState(() {
        _keys = offer.keys;
        _known = offer.known;
        _chosen = _keys.length == 1 ? _keys.single : null;
      });
    } on WorkspaceRefused catch (refused) {
      if (mounted) setState(() => _problem = refused.words);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _trust() async {
    final key = _chosen;
    if (_busy || key == null) return;
    setState(() => _busy = true);
    try {
      await widget.core.trust(widget.host, key);
      if (mounted) Navigator.pop(context, true);
    } on WorkspaceRefused catch (refused) {
      if (mounted) {
        setState(() {
          _problem = refused.words;
          _chosen = null;
          _keys = [];
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Trust ${widget.host}?'),
      content: SizedBox(
        width: Sizes.dialog,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_known)
                const Text('This computer already remembers a key for this host. Compare before replacing it.'),
              for (final key in _keys)
                ListTile(
                  title: SelectableText('${key.type}  ${key.fingerprint}'),
                  leading: Icon(_chosen == key ? Icons.check_circle_outline : Icons.circle_outlined),
                  onTap: _busy ? null : () => setState(() => _chosen = key),
                ),
              const Text(hostKeyComparisonWords),
              if (_problem != null) Text(_problem!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy || _chosen == null ? null : _trust, child: const Text('Trust it')),
      ],
    ),
  );
}

/// Opens the local vault first, then copies only a missing forge token from the system secret store.
Future<void> prepareOrganizationForge(
  BuildContext context,
  String repository,
  ForgeConnection forges, {
  OpenTerminal? open,
  FleetBackend? localBackend,
  DeviceKeyStore? deviceKeys,
  CoreCredentials? core,
}) async {
  final String address;
  final String destination;
  final int? namedPort;
  try {
    final scp = RegExp(r'^git@([^:]+):[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$').firstMatch(repository);
    final uri = scp == null ? Uri.tryParse(repository) : null;
    if (scp == null &&
        (uri == null ||
            !const ['https', 'ssh'].contains(uri.scheme) ||
            (uri.hasPort && (uri.port < 1 || uri.port > 65535)) ||
            !RegExp(r'^/[A-Za-z0-9][A-Za-z0-9._-]{0,99}/[A-Za-z0-9][A-Za-z0-9._-]{0,99}/?$').hasMatch(uri.path) ||
            uri.hasQuery ||
            uri.hasFragment ||
            (uri.scheme == 'https' ? uri.userInfo.isNotEmpty : uri.userInfo != 'git'))) {
      throw const FormatException();
    }
    address = forgeAddress(scp?.group(1) ?? uri!.host);
    namedPort = uri != null && uri.hasPort ? uri.port : null;
    final api = '$address${uri?.scheme == 'https' && namedPort != null ? ':$namedPort' : ''}';
    final path = scp == null ? uri!.path.substring(1).replaceAll(RegExp(r'/+$'), '') : repository.split(':').last;
    destination = 'https://$api/$path';
  } on FormatException {
    throw const OrganizationRefused(
      'The forge token destination could not be determined. '
      'Addresses with an explicit port need a declared credential.',
    );
  }
  // Organization commands run here, regardless of which machine happens to be selected in the window.
  final machine = Machine(name: 'this machine', socketPath: Backend.local().socketPath);
  final backend = localBackend ?? PoreloBackend(Machines.backendFor(machine));
  final vault = Vault(keys: deviceKeys ?? PlatformDeviceKeyStore());
  try {
    await backend.open();
    await vault.lookAt(backend, machine.name);
    if (!context.mounted) throw const OrganizationRefused('The forge token handoff was canceled.');
    if (vault.problem != null || vault.state == null) {
      throw const OrganizationRefused('Porelo cannot say what the local vault holds. Nothing was handed over.');
    }
    if (!vault.readable || vault.missing) {
      final opened = await showDialog<bool>(
        context: context,
        builder: (_) => _OrganizationVaultDialog(vault: vault, backend: backend, machine: machine, open: open),
      );
      if (opened != true || !context.mounted) {
        throw const OrganizationRefused('The vault must be open before the forge token can be handed over.');
      }
    }
    final name = 'git.token.$address';
    Connection? declared;
    for (final entry in vault.state!.connections) {
      final match = entry.match;
      if (match.isEmpty || (entry.purpose != 'git' && entry.purpose != 'any') || !destination.startsWith(match)) {
        continue;
      }
      final boundary =
          destination.length == match.length ||
          match.endsWith('/') ||
          match.endsWith(':') ||
          '/:?#'.contains(destination[match.length]);
      if (boundary && (declared == null || match.length > declared.match.length)) declared = entry;
    }
    if (declared != null && declared.kind == 'TOKEN') {
      final authority = Uri.tryParse(declared.match)?.authority.toLowerCase();
      if (namedPort != null && authority != '$address:$namedPort') {
        throw const OrganizationRefused('This forge port needs its own declared token. No token was handed over.');
      }
      if (declared.present) return;
      if (declared.source != 'VAULT' || declared.id != name) {
        throw const OrganizationRefused(
          'This forge uses a declared credential. Check that credential before continuing.',
        );
      }
    }
    if (namedPort != null) {
      throw const OrganizationRefused('This forge port needs its own declared token. No token was handed over.');
    }
    if (vault.credentials.any((entry) => entry.name == name && entry.characters > 0)) return;
    if (!await forges.hasToken(address)) {
      if (!context.mounted || !await askForForgeToken(context, address, open: open)) {
        throw const OrganizationRefused('No forge token was handed over.');
      }
    }
    if (!context.mounted) throw const OrganizationRefused('The forge token handoff was canceled.');
    await forges.handTokenToVault(address, core: core);
    await vault.look(backend);
    if (vault.problem != null ||
        !vault.readable ||
        !vault.credentials.any((entry) => entry.name == name && entry.characters > 0)) {
      throw const OrganizationRefused('Porelo did not confirm the forge token in the local vault.', answered: false);
    }
  } on WorkspaceRefused catch (refused) {
    throw OrganizationRefused(refused.words, answered: false);
  } on OrganizationRefused {
    rethrow;
  } on Exception {
    throw const OrganizationRefused('The forge token handoff could not be confirmed.', answered: false);
  } finally {
    vault.dispose();
  }
}

class _OrganizationVaultDialog extends StatefulWidget {
  const _OrganizationVaultDialog({required this.vault, required this.backend, required this.machine, this.open});

  final Vault vault;
  final FleetBackend backend;
  final Machine machine;
  final OpenTerminal? open;

  @override
  State<_OrganizationVaultDialog> createState() => _OrganizationVaultDialogState();
}

class _OrganizationVaultDialogState extends State<_OrganizationVaultDialog> {
  bool _busy = false;

  Future<void> _act({bool device = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (device) {
        await showDialog<void>(
          context: context,
          builder: (_) => OpenDialog(
            onOpen: (minutes) => widget.vault.devices.unlock(widget.backend, minutes: minutes),
            answer: () => widget.vault.devices.problem ?? widget.vault.devices.said ?? '',
          ),
        );
      } else if (widget.vault.missing) {
        await runInATerminal(
          context,
          title: 'Make the vault on ${widget.machine.name}',
          explanation: 'Choose a passphrase and type it twice. It goes straight to the machine.',
          machine: widget.machine,
          command: makeCommandFor(widget.machine)!,
          open: widget.open,
        );
      } else {
        await unlockInATerminal(
          context,
          machine: widget.machine,
          command: unlockCommandFor(widget.machine)!,
          open: widget.open,
        );
      }
      await widget.vault.lookAt(widget.backend, widget.machine.name);
      if (mounted && widget.vault.problem == null && widget.vault.readable && !widget.vault.missing) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('The vault'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.vault.lockSays),
          if (widget.vault.problem != null) Text(widget.vault.problem!),
          VaultButtons(
            vault: widget.vault,
            onLock: _busy ? null : () => _act(device: true),
            onOpenWithThePassphrase: _busy ? null : () => _act(),
            onMakeIt: _busy ? null : () => _act(),
          ),
          if (!_busy && widget.vault.devices.enrolledHere)
            OutlinedButton(onPressed: _act, child: const Text('Open it here, with its passphrase, in a terminal')),
        ],
      ),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel'))],
    ),
  );
}
