import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

const _usage = '''
porelo-host up|down --project NAME --account NAME --public-key FILE --identity FILE
            (--scaleway-project ID [--zone fr-par-1] | --given ADDRESS --host-key "TYPE BASE64")
            [--login-user NAME] [--distribution snapshots|releases]
            [--tresor NAME] [--vpn-peer-public-key KEY --vpn-peer-address ADDRESS]
            [--give-back-anyway]
            [--collection FILE --collection-sha256 HEX]
porelo-host key set|forget PROVIDER
porelo-host --version
porelo-host --collection-info

  up      rents the project's host, or finds it again by its tag, and runs the playbook there; it
          stops with 75 for the person; run up again after completing the stop on the host
  down    runs the down play, then gives the host back; a host whose down play did not finish is
          kept, since a failed copy may have left the only copy there, and down says so
  key     keeps a provider's key in the system's own store, read from standard input, or forgets it;
          the key is never an argument, and nothing is said of it but that it was kept

One JSON line per step on standard output; the words for a person on standard error.
Exit: 0 done, 64 usage, 65 refused, 69 unreachable, 70 an unforeseen fault, 75 waiting for the person.

--scaleway-project rents from Scaleway Elastic Metal, with the key `key set scaleway` kept.
--given names a machine that exists already, with its host key; nothing is rented or given back.
--give-back-anyway gives the host back after a down play that did not finish; what it held is gone.''';

// Ends with the run's code at once: an HTTPS connection to the provider, kept for reuse, would hold
// the program open for its idle time otherwise.
Future<void> main(List<String> arguments) async {
  try {
    exit(await _run(arguments));
  } catch (e) {
    // Whatever was not foreseen still ends in one plain line, never a stack trace.
    stderr.writeln('porelo-host: $e');
    exit(70);
  }
}

/// The version this command was built as, given by `dart compile exe -Dporelo_host.version=…`.
const _version = String.fromEnvironment('porelo_host.version', defaultValue: 'unreleased');

Future<int> _run(List<String> arguments) async {
  if (arguments.length == 1 && arguments.first == '--collection-info') {
    stdout.writeln('${hostCollection.version} ${hostCollection.sha256} ${hostCollection.fileName}');
    return Exit.done;
  }
  if (arguments.length == 1 && arguments.first == '--version') {
    stdout.writeln(_version);
    return Exit.done;
  }
  if (arguments.isNotEmpty && arguments.first == 'key') return _key(arguments.sublist(1));
  if (arguments.isEmpty || !<String>{'up', 'down'}.contains(arguments.first)) return _wrong('up or down first');
  final verb = arguments.first;
  final options = <String, String>{};
  var giveBackAnyway = false;
  for (var i = 1; i < arguments.length; i++) {
    final name = arguments[i];
    if (name == '--give-back-anyway' && verb == 'down') {
      giveBackAnyway = true;
    } else if (const <String>{
          '--project',
          '--account',
          '--public-key',
          '--identity',
          '--collection',
          '--collection-sha256',
          '--scaleway-project',
          '--zone',
          '--given',
          '--host-key',
          '--login-user',
          '--distribution',
          '--tresor',
          '--vpn-peer-public-key',
          '--vpn-peer-address',
        }.contains(name) &&
        i + 1 < arguments.length) {
      options[name.substring(2)] = arguments[++i];
    } else {
      return _wrong('$name is not an option');
    }
  }
  if (options.containsKey('collection') != options.containsKey('collection-sha256')) {
    stderr.writeln('porelo-host: --collection needs --collection-sha256 and vice versa');
    return Exit.refused;
  }
  if (options['collection-sha256'] case final String digest when !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)) {
    stderr.writeln('porelo-host: --collection-sha256 must contain 64 hexadecimal digits');
    return Exit.refused;
  }
  const needed = <String>['project', 'account', 'public-key', 'identity'];
  final missing = needed.where((n) => !options.containsKey(n)).toList();
  if (missing.isNotEmpty) return _wrong('missing ${missing.map((n) => '--$n').join(', ')}');
  final given = options.containsKey('given');
  if (given == options.containsKey('scaleway-project')) return _wrong('either --scaleway-project or --given');
  if (given && !options.containsKey('host-key')) return _wrong('--given needs --host-key');
  final HostProvider provider;
  if (given) {
    provider = GivenMachine(address: options['given']!, hostKey: options['host-key']!);
  } else {
    final store = SecretStore.forThisSystem();
    final String? key;
    try {
      key = await store.read(providerKeyName('scaleway'));
    } on SecretStoreFailed catch (e) {
      stderr.writeln('porelo-host: $e');
      return Exit.refused;
    } finally {
      await store.close();
    }
    if (key == null) return _wrong('no key for scaleway is kept: run `porelo-host key set scaleway` first');
    provider = ScalewayElasticMetal(
      api: scalewayOverHttps(key),
      projectId: options['scaleway-project']!,
      zone: options['zone'] ?? 'fr-par-1',
    );
  }

  final ssh = OpenSsh(knownHosts: File(poreloHostKnownHosts()), identity: options['identity']!);
  final run = HostRun(
    provider: provider,
    remote: ssh,
    trust: ssh.trust,
    emit: (step) => writeHostStep(step, output: stdout, errors: stderr),
  );
  final plan = HostPlan(
    project: options['project']!,
    account: options['account']!,
    publicKey: (await File(options['public-key']!).readAsString()).trim(),
    collection: options['collection'],
    collectionSha256: options['collection-sha256'],
    loginUser: options['login-user'] ?? 'ubuntu',
    distribution: options['distribution'] ?? 'snapshots',
    tresor: options['tresor'],
    vpnPeerPublicKey: options['vpn-peer-public-key'],
    vpnPeerAddress: options['vpn-peer-address'],
  );
  return verb == 'up' ? run.up(plan) : run.down(plan, giveBackAnyway: giveBackAnyway);
}

/// `key set PROVIDER` and `key forget PROVIDER`.
Future<int> _key(List<String> arguments) async {
  if (arguments.length != 2 || !<String>{'set', 'forget'}.contains(arguments.first)) {
    return _wrong('key set PROVIDER or key forget PROVIDER');
  }
  final name = providerKeyName(arguments[1]);
  final store = SecretStore.forThisSystem();
  try {
    if (arguments.first == 'forget') {
      await store.remove(name);
      stderr.writeln('porelo-host: the key for ${arguments[1]} is forgotten');
      return Exit.done;
    }
    // One line; a key typed at a terminal is not echoed.
    if (stdin.hasTerminal) stdin.echoMode = false;
    final line = stdin.readLineSync(encoding: utf8);
    if (stdin.hasTerminal) stdin.echoMode = true;
    final key = line?.trim() ?? '';
    if (key.isEmpty) return _wrong('no key on standard input');
    await store.write(name, key);
    stderr.writeln('porelo-host: the key for ${arguments[1]} is kept in the system\'s store');
    return Exit.done;
  } on SecretStoreFailed catch (e) {
    stderr.writeln('porelo-host: $e');
    return Exit.refused;
  } finally {
    await store.close();
  }
}

int _wrong(String why) {
  stderr.writeln('porelo-host: $why\n\n$_usage');
  return Exit.usage;
}
