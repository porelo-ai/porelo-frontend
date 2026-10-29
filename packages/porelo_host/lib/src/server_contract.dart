import 'dart:convert';

import 'host_record.dart';
import 'remote.dart';
import 'ssh.dart';

/// One public laptop identity in a project admin's key block.
class AdminLaptop {
  AdminLaptop._(this.name, this.address);

  /// The person's laptop label.
  final String name;

  /// Its optional requested VPN address.
  final String? address;
}

/// Checks every line before any public key block is sent to a host.
List<AdminLaptop> checkAdminKeyBlock(String block, int network) {
  checkHostNetwork(network);
  final lines = const LineSplitter().convert(block);
  if (lines.isEmpty) throw const FormatException('Line 1: paste at least one laptop and its public keys.');
  final laptops = <AdminLaptop>[];
  final addresses = <String>{};
  for (var index = 0; index < lines.length; index++) {
    try {
      final parts = lines[index].split(' ');
      if (parts.length != 4 && parts.length != 5) {
        throw const FormatException(
          'Use one space between the laptop name, ssh key and WireGuard key, with an optional VPN address.',
        );
      }
      if (!RegExp(r'^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$').hasMatch(parts[0])) {
        throw const FormatException('Give a laptop name of at most 32 lower-case letters, digits and internal dashes.');
      }
      if (laptops.any((laptop) => laptop.name == parts[0])) throw const FormatException('The laptop name is repeated.');
      checkedEd25519('${parts[1]} ${parts[2]}');
      checkWireGuardPublicKey(parts[3]);
      final address = parts.length == 5 ? parts[4] : null;
      if (address != null) {
        if (!isIpv4Address(address) ||
            !address.startsWith('10.73.$network.') ||
            int.parse(address.split('.').last) < 2 ||
            int.parse(address.split('.').last) > 254) {
          throw FormatException('The VPN address must be in 10.73.$network.0/24, from .2 to .254.');
        }
        if (!addresses.add(address)) throw const FormatException('The VPN address is repeated.');
      }
      laptops.add(AdminLaptop._(parts[0], address));
    } on FormatException catch (error) {
      throw FormatException('Line ${index + 1}: ${error.message}');
    }
  }
  return List.unmodifiable(laptops);
}

/// Checks an account or project name before it becomes a remote helper argument.
void checkAdminName(String value) {
  if (!RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(value)) {
    throw const FormatException(
      'Use a name starting with a lower-case letter, then lower-case letters, digits, underscores or dashes, at most 32 characters.',
    );
  }
}

/// A validated helper call whose key block is sent only on standard input.
class HostAdminRequest {
  HostAdminRequest._(this.helper, List<String> arguments, [this.input]) : arguments = List.unmodifiable(arguments);

  /// Admits a project admin after checking the entire key block.
  factory HostAdminRequest.admit(String person, String block, int network) {
    checkAdminName(person);
    checkAdminKeyBlock(block, network);
    return HostAdminRequest._('person', [
      'add',
      person,
      '--role',
      'project-admin',
    ], '${const LineSplitter().convert(block).join('\n')}\n');
  }

  /// Registers a project with its signing public key.
  factory HostAdminRequest.register(String project, String admin, String key) {
    checkAdminName(project);
    checkAdminName(admin);
    final signingKey = checkedEd25519(key.trim());
    return HostAdminRequest._('project', ['add', project, admin, '--signed-by', signingKey]);
  }

  /// Locks or purges a person, or removes a project, after an explicit decision.
  factory HostAdminRequest.remove(String helper, String action, String name) {
    if (!(helper == 'person' && const ['lock', 'purge'].contains(action) ||
        helper == 'project' && action == 'remove')) {
      throw const FormatException('Unknown host helper action.');
    }
    checkAdminName(name);
    return HostAdminRequest._(helper, [action, name]);
  }

  /// The installed helper family.
  final String helper;

  /// Checked words passed to the remote shell.
  final List<String> arguments;

  /// The public laptop block, never part of the command line.
  final String? input;

  /// Quotes every argument for the remote shell.
  String get command => ['/usr/local/sbin/porelo-host-$helper', ...arguments].map(quoteForAShell).join(' ');

  /// Runs as root over the host's VPN with the caller's pinned rental key; refusals remain verbatim.
  Future<String> run(Remote remote, PreparedHost host) async {
    final lines = <String>[];
    final result = await remote.run(host.vpnAddress, 'root', command, input: input, onLine: lines.add);
    return answer(result, lines, host);
  }

  /// Checks a helper's public reply, including replies from a terminal whose stdin held a secret.
  String answer(RemoteResult result, List<String> lines, PreparedHost host) {
    if (result.exitCode != 0) throw HostAdminRefused(result.stderr);
    if (lines.length != 1) throw const FormatException('The host helper must answer with one JSON line.');
    final json = jsonDecode(lines.single);
    if (json is! Map<String, Object?>) throw const FormatException('The host helper answer must be a JSON object.');
    String field(String name) {
      final value = json[name];
      if (value is! String || value.isEmpty || RegExp(r'[\x00-\x1f]').hasMatch(value)) {
        throw FormatException('The host helper answer has no valid $name.');
      }
      return value;
    }

    final name = field(helper);
    if (name != arguments[1]) throw FormatException('The host helper answered for a different $helper.');
    if (arguments.first != 'add') {
      final flag = switch (arguments.first) {
        'lock' => 'locked',
        'purge' => 'purged',
        _ => 'removed',
      };
      if (json[flag] != true) throw FormatException('The host helper did not confirm $flag.');
      return helper == 'person'
          ? '$name is ${flag == 'locked' ? 'locked' : 'purged'}.'
          : 'The project $name was taken off the server.';
    }
    if (helper == 'project') {
      if (field('admin') != arguments[2] || field('publisher') != 'porelo-publisher-$name') {
        throw const FormatException('The host helper did not confirm the project admin and publisher.');
      }
      return 'Project $name is registered for ${field('admin')}. Organization: ${field('organization')}. Publisher: ${field('publisher')}.';
    }
    if (json['role'] != 'project-admin' || json['laptops'] is! List) {
      throw const FormatException('The host helper did not confirm the project admin and laptops.');
    }
    final requested = checkAdminKeyBlock(input!, host.network);
    final laptops = json['laptops'] as List;
    final seen = <String>{};
    final addresses = <String>{};
    final words = <String>['$name is admitted as a project admin.'];
    for (final laptop in laptops) {
      if (laptop is! Map || laptop['laptop'] is! String || laptop['vpn_address'] is! String) {
        throw const FormatException('The host helper gave a malformed laptop.');
      }
      final label = laptop['laptop'] as String;
      final address = laptop['vpn_address'] as String;
      final matching = requested.where((each) => each.name == label).firstOrNull;
      if (matching == null ||
          !seen.add(label) ||
          !addresses.add(address) ||
          !isIpv4Address(address) ||
          !address.startsWith('10.73.${host.network}.') ||
          int.parse(address.split('.').last) < 2 ||
          int.parse(address.split('.').last) > 254 ||
          matching.address != null && matching.address != address) {
        throw const FormatException('The host helper gave an unexpected laptop or VPN address.');
      }
      words.add('$label: $address.');
    }
    if (seen.length != requested.length) {
      throw const FormatException('The host helper did not answer for every laptop.');
    }
    return words.join('\n');
  }
}

/// A helper's refusal, displayed without changing its sentence.
class HostAdminRefused implements Exception {
  /// Keeps the helper's stderr exactly as received.
  const HostAdminRefused(this.words);

  /// The verbatim refusal.
  final String words;
}
