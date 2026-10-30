import 'host_record.dart';
import 'remote.dart';

/// Checks an account or project name before it reaches a host operation.
void checkAdminName(String value) {
  if (!RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(value)) {
    throw const FormatException('Use a lower-case login or project name, at most 32 characters.');
  }
}

/// The agreed server-setup boundary, implemented when the host serves its final contract.
abstract interface class ServerPreparation {
  /// Prepares this existing SSH host and pins the proven admin after up.
  ///
  /// The adapter runs root's `porelo-host-person registry pin <login> <key>`
  /// with [adminLogin] and [adminKey]. It accepts no root needs. The person's
  /// bootstrap of root's authorized keys happens in a separate terminal.
  Future<PreparedHost> prepare({
    required Remote remote,
    required String name,
    required String address,
    required List<String> adminSigners,
    required String adminLogin,
    required String adminKey,
    Map<String, Object> inventory = const {},
    HostPreparationSettings settings = const HostPreparationSettings(),
  });
}

/// Public choices retained for server preparation and local SSH forwards.
class HostPreparationSettings {
  /// Uses role defaults for omitted runner limits and standard local forwards.
  const HostPreparationSettings({
    this.forgeRunnerCapacity,
    this.forgeJobCpus,
    this.forgeJobMemory,
    this.forgeWebPort = 3000,
    this.forgeGitPort = 3001,
    this.matrixPort = 8448,
  });

  /// The runner's concurrent jobs, absent for the role default.
  final int? forgeRunnerCapacity;

  /// The CPUs per job, absent for the role default.
  final int? forgeJobCpus;

  /// The Podman memory limit per job, absent for the role default.
  final String? forgeJobMemory;

  /// The person's local forge web forward.
  final int forgeWebPort;

  /// The person's local forge Git forward.
  final int forgeGitPort;

  /// The person's local Matrix forward.
  final int matrixPort;

  /// Refuses invalid limits or colliding local service ports before setup.
  void check() {
    if ([forgeRunnerCapacity, forgeJobCpus].any((n) => n != null && n <= 0)) {
      throw const FormatException('Runner capacity and job CPUs must be positive integers.');
    }
    if (forgeJobMemory != null && !RegExp(r'^[1-9][0-9]*[bkmgBKMG]?$').hasMatch(forgeJobMemory!)) {
      throw const FormatException('Use a Podman memory limit such as 768m.');
    }
    final ports = [forgeWebPort, forgeGitPort, matrixPort];
    if (ports.any((p) => p < 1 || p > 65535) || ports.toSet().length != 3) {
      throw const FormatException('Choose three distinct local ports between 1 and 65535.');
    }
  }

  /// The chosen local ends, never read from the host's service ports.
  Map<String, Map<String, int>> get localServices => {
    'forge': {'web_port': forgeWebPort, 'git_port': forgeGitPort},
    'matrix': {'port': matrixPort},
  };

  /// The role's exact optional inventory variables, omitted for its defaults.
  Map<String, Object> get roleSettings => {
    'forge_runner_capacity': ?forgeRunnerCapacity,
    'forge_job_cpus': ?forgeJobCpus,
    'forge_job_memory': ?forgeJobMemory,
  };

  /// The public preparation choices saved for retries.
  Map<String, Object> get stored => {
    ...roleSettings,
    'forge_web_port': forgeWebPort,
    'forge_git_port': forgeGitPort,
    'matrix_port': matrixPort,
  };

  /// The public setup arguments, using the same field names as saved choices.
  List<String> get arguments => [
    for (final entry in stored.entries) ...['--${entry.key.replaceAll('_', '-')}', '${entry.value}'],
  ];

  /// Reads the public preparation options from a host command's arguments.
  factory HostPreparationSettings.fromArguments(List<String> arguments) {
    final values = <String, Object>{};
    for (final key in [
      'forge_runner_capacity',
      'forge_job_cpus',
      'forge_job_memory',
      'forge_web_port',
      'forge_git_port',
      'matrix_port',
    ]) {
      final option = '--${key.replaceAll('_', '-')}';
      final index = arguments.indexOf(option);
      if (index < 0) continue;
      if (index + 1 >= arguments.length) throw FormatException('Missing $option.');
      final value = arguments[index + 1];
      values[key] = key == 'forge_job_memory' ? value : int.tryParse(value) ?? value;
    }
    return HostPreparationSettings.read(values);
  }

  /// Reads optional limits without accepting coercions or shell syntax.
  factory HostPreparationSettings.read(Object? value) {
    if (value is! Map) throw const FormatException('Invalid server preparation settings.');
    int? number(String key) {
      final item = value[key];
      if (item != null && item is! int) throw FormatException('Invalid $key.');
      return item as int?;
    }

    final memory = value['forge_job_memory'];
    if (memory != null && memory is! String) throw const FormatException('Invalid job memory.');
    final result = HostPreparationSettings(
      forgeRunnerCapacity: number('forge_runner_capacity'),
      forgeJobCpus: number('forge_job_cpus'),
      forgeJobMemory: memory as String?,
      forgeWebPort: number('forge_web_port') ?? 3000,
      forgeGitPort: number('forge_git_port') ?? 3001,
      matrixPort: number('matrix_port') ?? 8448,
    );
    result.check();
    return result;
  }
}

/// The separate-terminal bootstrap instruction; the interface never runs it.
String hostRootBootstrapCommand(String publicKey) {
  checkedEd25519(publicKey);
  return "sudo install -d -m 700 /root/.ssh && printf '%s\\n' '$publicKey' | "
      'sudo tee /root/.ssh/authorized_keys >/dev/null && sudo chmod 600 /root/.ssh/authorized_keys';
}
