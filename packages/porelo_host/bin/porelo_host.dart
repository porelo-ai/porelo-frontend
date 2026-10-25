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
porelo-host key set scaleway [--from-file FILE]
porelo-host key check scaleway
porelo-host --version
porelo-host --collection-info

  up      rents the project's host, or finds it again by its tag, and runs the playbook there; it
          stops with 75 for the person; run up again after completing the stop on the host
  down    runs the down play, then gives the host back; a host whose down play did not finish is
          kept, since a failed copy may have left the only copy there, and down says so
  key     checks and keeps Scaleway's secret key or keeps a forge token, or forgets it;
          set reads from a terminal without echo; Scaleway also accepts an owner-only regular file
          check scaleway checks the stored secret without prompting or changing it

One JSON line per step on standard output; the words for a person on standard error.
Exit: 0 done, 64 usage, 65 refused, 69 unreachable, 70 an unforeseen fault, 75 waiting for the person.

--scaleway-project rents from Scaleway Elastic Metal, with the key `key set scaleway` kept.
--given names a machine that exists already, with its host key; nothing is rented or given back.
--give-back-anyway gives the host back after a down play that did not finish; what it held is gone.''';

// Ends with the run's code at once: an HTTPS connection to the provider, kept for reuse, would hold
// the program open for its idle time otherwise.
Future<void> main(List<String> arguments) async {
  try {
    final code = await _run(arguments);
    await stdout.flush();
    await stderr.flush();
    exit(code);
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
  if (arguments.isNotEmpty && arguments.first == 'key') return runKeyCommand(arguments.sublist(1));
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

/// Runs key commands with replaceable storage, terminal input, and provider requests.
Future<int> runKeyCommand(
  List<String> arguments, {
  SecretStore Function()? openStore,
  ScalewayApi Function(String)? exchange,
  String? Function()? readKey,
  StringSink? output,
  StringSink? errors,
}) async {
  final err = errors ?? stderr;
  int wrong(String reason) {
    err.writeln('porelo-host: $reason\n\n$_usage');
    return Exit.usage;
  }

  int refused(String reason) {
    err.writeln('porelo-host: $reason');
    return Exit.refused;
  }

  if (arguments.length < 2 || !<String>{'set', 'forget', 'check'}.contains(arguments.first)) {
    return wrong('key set PROVIDER, key forget PROVIDER, or key check scaleway');
  }
  final verb = arguments.first;
  final scaleway = arguments[1] == 'scaleway';
  final fromFile = verb == 'set' && scaleway && arguments.length == 4 && arguments[2] == '--from-file';
  if ((!fromFile && arguments.length != 2) || (verb == 'check' && !scaleway)) {
    return wrong('key set scaleway [--from-file FILE], key check scaleway, or key set|forget PROVIDER');
  }
  final String name;
  try {
    name = providerKeyName(arguments[1]);
  } on FormatException catch (error) {
    return wrong(error.message);
  }
  if (verb == 'set' && !fromFile && readKey == null && !stdin.hasTerminal) {
    return wrong('key set needs a terminal for its prompt');
  }
  SecretStore? store;
  Future<int> execute() async {
    if (verb == 'forget') {
      store = (openStore ?? SecretStore.forThisSystem)();
      await store!.remove(name);
      err.writeln('porelo-host: the key for ${arguments[1]} is forgotten');
      return Exit.done;
    }
    final String? line;
    if (verb == 'check') {
      store = (openStore ?? SecretStore.forThisSystem)();
      line = await store!.read(name);
      if (line == null) return refused('no key for scaleway is kept: run `porelo-host key set scaleway` first');
    } else if (fromFile) {
      final file = File(arguments[3]);
      if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) {
        return refused('--from-file needs a regular file, not a symlink');
      }
      if ((Platform.isLinux || Platform.isMacOS) && ((await file.stat()).mode & 0x3f) != 0) {
        return refused('--from-file needs an owner-only file (mode 0600)');
      }
      final content = await file.readAsString();
      if (content.contains('=')) {
        final values = const LineSplitter().convert(content).where((line) {
          final equals = line.indexOf('=');
          return equals >= 0 && line.substring(0, equals).trim() == 'SECRET_KEY';
        }).toList();
        if (values.length != 1) return refused('the file must contain exactly one SECRET_KEY assignment');
        line = values.single.substring(values.single.indexOf('=') + 1);
      } else {
        line = content;
      }
    } else if (readKey != null) {
      line = readKey();
    } else {
      final echo = stdin.echoMode;
      try {
        stdin.echoMode = false;
        err.write('Token for ${arguments[1]}: ');
        line = stdin.readLineSync(encoding: utf8);
      } finally {
        stdin.echoMode = echo;
        err.writeln();
      }
    }
    final key = line?.trim() ?? '';
    if (scaleway) {
      final answer = await checkScalewayKey(key, exchange: exchange ?? scalewayOverHttps);
      if (answer.code != Exit.done) {
        err.writeln(answer.message);
        return answer.code;
      }
    } else if (key.isEmpty) {
      return wrong('no key entered at the terminal prompt');
    }
    if (verb == 'set') {
      store ??= (openStore ?? SecretStore.forThisSystem)();
      await store!.write(name, key);
    }
    if (scaleway) {
      (output ?? stdout).writeln('accepted');
    } else {
      err.writeln('porelo-host: the key for ${arguments[1]} is kept in the system\'s store');
    }
    return Exit.done;
  }

  try {
    try {
      return await execute();
    } finally {
      await store?.close();
    }
  } on Exception {
    return refused('the key could not be read or kept; check the input and the system secret store');
  }
}

int _wrong(String why) {
  stderr.writeln('porelo-host: $why\n\n$_usage');
  return Exit.usage;
}
