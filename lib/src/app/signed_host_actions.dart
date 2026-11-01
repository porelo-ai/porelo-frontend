import 'dart:async';
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
      throw const RegistryRefusal('Verified admission and project-admin signers are required.');
    }
    try {
      for (final signer in adminSigners) {
        checkedEd25519(signer);
      }
    } on FormatException {
      throw const RegistryRefusal('Verified admission and project-admin signers are required.');
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
    this.stepLimit = const Duration(minutes: 3),
  });

  /// How long one step may take before the dialog says so and lets go; what the step did is kept.
  final Duration stepLimit;

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

  /// What the running operation does now, in words; null while none runs.
  String? step;

  /// The public refusal, without dependency errors or credential values.
  String? problem;
  bool _disposed = false;

  /// Runs only a currently authorized, verified operation through the host tunnel.
  Future<void> run() async {
    if (busy || completed) return;
    busy = true;
    problem = null;
    try {
      final service = actions;
      if (service == null) {
        throw const RegistryRefusal('Verified registry joining is not available yet.');
      }
      final state = await _within('Checking the project with Core', service.verify(project, registering: registering));
      state.check(project);
      final machine = await _within('Opening the connection to ${state.host.name}', service.connect(state));
      if (machine.kind != 'host' || machine.hostProject != state.host.name || machine.identity.isNotEmpty) {
        throw const RegistryRefusal('The shared SSH tunnel did not confirm this host and person identity.');
      }
      if (registering) {
        final latest = await _within(
          'Checking the project with Core again',
          service.verify(project, registering: true),
        );
        latest.check(project);
        if (latest.host.name != state.host.name ||
            latest.revision != state.revision ||
            jsonEncode(latest.host.stored) != jsonEncode(state.host.stored) ||
            !listEquals(latest.adminSigners, state.adminSigners)) {
          throw const RegistryRefusal('The verified project admission changed. Try again.');
        }
      }
      final observed = await _within(
        'Registering on ${state.host.name}: Core files the access change and the host takes it',
        service.register(state, machine),
      );
      if (observed != state.revision) {
        throw const RegistryRefusal('The host did not confirm the intended verified project revision.');
      }
      await machines.add(machine);
      await settings.rememberProjectHost(project, state.host.name);
      completed = true;
    } on RegistryRefusal catch (error) {
      problem = error.toString();
    } on Exception {
      problem = 'The host operation could not be confirmed. The saved rental and project state were kept.';
    } finally {
      busy = false;
      step = null;
      _notify();
    }
  }

  /// Shows [words] while [work] runs, and ends with them once it took longer than [stepLimit]. The step itself is not
  /// stopped: what it finishes is kept, and the dialog can be closed or tried again.
  Future<T> _within<T>(String words, Future<T> work) async {
    step = '$words…';
    _notify();
    try {
      return await work.timeout(stepLimit);
    } on TimeoutException {
      throw RegistryRefusal(
        '$words did not end within ${stepLimit.inMinutes} minutes. What it did is kept; '
        'close this and try again later.',
      );
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
