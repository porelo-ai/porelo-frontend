import 'agent_inventory.dart';
import 'authentication.dart';
import 'connections.dart';
import 'device_key.dart';
import 'host_readiness.dart';
import 'vault.dart';

/// Observations and pending answers belonging to exactly one watched machine.
class MachineTools {
  /// Creates independent observations sharing only this device's key store.
  MachineTools(DeviceKeyStore keys)
    : vault = Vault(keys: keys),
      connections = Connections(),
      inventory = AgentInventory(),
      authentication = Authentication(),
      readiness = HostReadiness();

  /// Keeps the observations supplied by the application for its initial machine.
  MachineTools.existing({
    required this.vault,
    required this.connections,
    required this.inventory,
    required this.authentication,
    required this.readiness,
  });

  /// The machine's vault, never another machine's pending answer.
  final Vault vault;

  /// The machine's declared connections.
  final Connections connections;

  /// The machine's installed agents.
  final AgentInventory inventory;

  /// The machine's providers and credential imports.
  final Authentication authentication;

  /// The machine's readiness checks.
  final HostReadiness readiness;

  int _pending = 0;
  bool _released = false;

  /// Keeps observations alive until this asynchronous action has delivered its final notification.
  Future<T> run<T>(Future<T> Function() action) async {
    if (_released) throw StateError('This machine page has been closed.');
    _pending++;
    try {
      return await action();
    } finally {
      _pending--;
      if (_released && _pending == 0) _dispose();
    }
  }

  /// Releases frame-owned observations once their pending actions finish.
  void dispose() {
    if (_released) return;
    _released = true;
    if (_pending == 0) _dispose();
  }

  void _dispose() {
    vault.devices.dispose();
    vault.dispose();
    connections.dispose();
    inventory.dispose();
    authentication.dispose();
    readiness.dispose();
  }
}
