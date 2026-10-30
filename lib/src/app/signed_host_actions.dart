import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart';

import 'machines.dart';
import 'settings.dart';
import 'registry.dart';

/// Core's accepted project state, tied to one host and one signed revision.
@immutable
class VerifiedHostProject {
  /// Retains public verified state; authorization is checked again before each action.
  VerifiedHostProject({
    required this.project,
    required this.host,
    required this.revision,
    required List<String> adminSigners,
    required this.admitted,
  }) : adminSigners = List.unmodifiable(adminSigners);

  /// The admitted project's name.
  final String project;

  /// The accepted host card's completion values.
  final PreparedHost host;

  /// The accepted project revision.
  final String revision;

  /// The verified project admins' public keys.
  final List<String> adminSigners;

  /// Whether Core admits the current person for this operation.
  final bool admitted;

  /// Refuses incomplete trust before any host connection or mutation.
  void check(String expectedProject) {
    if (project != expectedProject ||
        !admitted ||
        adminSigners.isEmpty ||
        !RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(revision)) {
      throw const FormatException('Verified admission and project-admin signers are required.');
    }
    for (final signer in adminSigners) {
      checkedEd25519(signer);
    }
  }
}

/// The boundary to Core's verified state and the host's SSH-only operations.
///
/// Implementations supply their served contracts. No CLI or wire format is guessed here.
abstract interface class SignedHostActions {
  /// Rechecks current admission and signers for the selected project.
  Future<VerifiedHostProject> verify(String project, {required bool registering});

  /// Opens the accepted card through the person's agent and the shared host tunnel.
  Future<Machine> connect(VerifiedHostProject state);

  /// Registers the verified project and returns the revision confirmed by the host.
  Future<String> register(VerifiedHostProject state, Machine machine);

  /// Joins with the verified admin signers and returns the host's confirmed revision.
  Future<String> join(VerifiedHostProject state, Machine machine);
}

class _Refused implements Exception {
  const _Refused(this.words);
  final String words;
}

/// An explicit project operation, confirmed before its machine association is saved.
class SignedHostAction extends ChangeNotifier {
  /// Uses Core and host boundaries supplied by the application or a test.
  SignedHostAction({
    required this.project,
    required this.machines,
    required this.settings,
    required this.actions,
    required this.registering,
  });

  /// The selected project, captured before the operation starts.
  final String project;

  /// The watched machine list.
  final Machines machines;

  /// The durable confirmed project association.
  final Settings settings;

  /// The verified state and SSH operation boundary.
  final SignedHostActions? actions;

  /// Whether this operation registers the project.
  final bool registering;

  /// Whether the operation is waiting for its dependencies.
  bool busy = false;

  /// Whether the intended revision was confirmed and kept.
  bool completed = false;

  /// The public refusal, without dependency errors or credential values.
  String? problem;
  bool _disposed = false;

  /// Runs only a currently authorized, verified operation through the host tunnel.
  Future<void> run() async {
    if (busy || completed) return;
    busy = true;
    problem = null;
    _notify();
    try {
      final service = actions;
      if (service == null) {
        throw const _Refused('Verified registry joining is not available yet.');
      }
      final state = await service.verify(project, registering: registering);
      try {
        state.check(project);
      } on FormatException {
        throw const _Refused('Verified admission and project-admin signers are required.');
      }
      final machine = await service.connect(state);
      if (machine.kind != 'host' || machine.hostProject != state.host.name || machine.identity.isNotEmpty) {
        throw const _Refused('The shared SSH tunnel did not confirm this host and person identity.');
      }
      if (registering) {
        final latest = await service.verify(project, registering: true);
        latest.check(project);
        if (latest.host.name != state.host.name ||
            latest.revision != state.revision ||
            jsonEncode(latest.host.stored) != jsonEncode(state.host.stored) ||
            !listEquals(latest.adminSigners, state.adminSigners)) {
          throw const _Refused('The verified project admission changed. Try again.');
        }
      }
      final observed = registering ? await service.register(state, machine) : await service.join(state, machine);
      if (observed != state.revision) {
        throw const _Refused('The host did not confirm the intended verified project revision.');
      }
      await machines.add(machine);
      await settings.rememberProjectHost(project, state.host.name);
      completed = true;
    } on RegistryRefusal catch (error) {
      problem = error.words;
    } on _Refused catch (error) {
      problem = error.words;
    } on Exception {
      problem = 'The host operation could not be confirmed. The saved rental and project state were kept.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
