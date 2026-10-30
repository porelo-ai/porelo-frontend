import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

const _usage = '''
porelo-host up|down (--host-name NAME | --project NAME --account NAME)
            [--forge true|false]
            (--scaleway-project ID [--zone fr-par-1] [--offer EM-I220E-NVME] | --given ADDRESS --host-key "TYPE BASE64")
            [--login-user NAME] [--distribution snapshots|releases]
            [--legacy-rental] [--rental-tag TAG]
            [--give-back-anyway]
            [--collection FILE --collection-sha256 HEX]
porelo-host find --project NAME --scaleway-project ID [--zone fr-par-1]
porelo-host key set|forget PROVIDER
porelo-host key set scaleway [--from-file FILE]
porelo-host key check scaleway
porelo-host --version
porelo-host --collection-info

  up      refuses until the verified Core and SSH-only preparation adapters are served
  down    gives back the tagged rental after its down play; a failed play keeps the host
          legacy rentals require explicit loss confirmation and run no retired teardown
  find    names the server rented for the project now, as one JSON line with its id, address and
          whether it is ready, or exits 69 when none is; it changes nothing
  key     checks and keeps Scaleway's secret key or keeps a forge token, or forgets it;
          set reads from a terminal without echo; Scaleway also accepts an owner-only regular file
          check scaleway checks the stored secret without prompting or changing it

One JSON line per step on standard output; the words for a person on standard error.
Exit: 0 done, 64 usage, 65 refused, 69 unreachable, 70 an unforeseen fault, 75 waiting for the person.

--scaleway-project rents from Scaleway Elastic Metal, with the key `key set scaleway` kept; --offer names
            another Elastic Metal offer than EM-I220E-NVME.
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
  } catch (_) {
    // Whatever was not foreseen still ends in one plain line, never a stack trace.
    stderr.writeln('porelo-host: the operation could not be confirmed');
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
  if (arguments.isNotEmpty && arguments.first == 'find') return _find(arguments.sublist(1));
  if (arguments.isEmpty || !<String>{'up', 'down'}.contains(arguments.first)) return _wrong('up or down first');
  final verb = arguments.first;
  final options = <String, String>{};
  var giveBackAnyway = false;
  var legacyRental = false;
  for (var i = 1; i < arguments.length; i++) {
    final name = arguments[i];
    if (name == '--legacy-rental' && verb == 'down') {
      legacyRental = true;
    } else if (name == '--give-back-anyway' && verb == 'down') {
      giveBackAnyway = true;
    } else if (const <String>{
          '--host-name',
          '--rental-tag',
          '--forge',
          '--project',
          '--account',
          '--public-key',
          '--collection',
          '--collection-sha256',
          '--scaleway-project',
          '--zone',
          '--offer',
          '--given',
          '--host-key',
          '--login-user',
          '--distribution',
          '--machine-file',
          '--bundle',
        }.contains(name) &&
        i + 1 < arguments.length) {
      options[name.substring(2)] = arguments[++i];
    } else {
      return _wrong('unknown or incomplete option');
    }
  }
  if (options.containsKey('machine-file') != options.containsKey('bundle')) {
    stderr.writeln('porelo-host: --machine-file needs --bundle and vice versa');
    return Exit.refused;
  }
  if (options.containsKey('collection') != options.containsKey('collection-sha256')) {
    stderr.writeln('porelo-host: --collection needs --collection-sha256 and vice versa');
    return Exit.refused;
  }
  if (options['collection-sha256'] case final String digest when !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)) {
    stderr.writeln('porelo-host: --collection-sha256 must contain 64 hexadecimal digits');
    return Exit.refused;
  }
  final serverOnly = options.containsKey('host-name');
  final needed = <String>[
    if (serverOnly) 'host-name' else ...['project', 'account'],
    if (!legacyRental && verb == 'up') 'public-key',
  ];
  if (serverOnly &&
      (options.containsKey('project') || options.containsKey('account') || options.containsKey('machine-file'))) {
    return _wrong('a server takes no project or account');
  }
  if (options['forge'] != null && !const ['true', 'false'].contains(options['forge'])) {
    return _wrong('--forge needs true or false');
  }
  final missing = needed.where((n) => !options.containsKey(n)).toList();
  if (missing.isNotEmpty) return _wrong('missing ${missing.map((n) => '--$n').join(', ')}');
  final given = options.containsKey('given');
  if (given == options.containsKey('scaleway-project')) return _wrong('either --scaleway-project or --given');
  if (given && !options.containsKey('host-key')) return _wrong('--given needs --host-key');
  if (options['offer'] case final String offer when given || !RegExp(r'^[A-Z0-9][A-Z0-9-]*$').hasMatch(offer)) {
    return _wrong('--offer takes an Elastic Metal offer name such as EM-I220E-NVME, with --scaleway-project');
  }
  if (verb == 'up') {
    stderr.writeln('Verified SSH-only preparation requires the served Core and host setup contracts.');
    return Exit.refused;
  }
  final HostProvider provider;
  if (given) {
    provider = GivenMachine(address: options['given']!, hostKey: options['host-key']!);
  } else {
    final (key, failed) = await _scalewayKey();
    if (key == null) return failed!;
    provider = scalewayFor(options, scalewayOverHttps(key));
  }

  final ssh = OpenSsh(
    knownHosts: File(poreloHostKnownHosts()),
    identity: '',
    config: serverOnly && !legacyRental ? poreloHostSshConfig(options['host-name']!) : null,
    configHost: serverOnly && !legacyRental ? options['host-name']! : null,
  );
  final run = HostRun(
    provider: provider,
    remote: ssh,
    trust: ssh.trust,
    emit: (step) => writeHostStep(step, output: stdout, errors: stderr),
  );
  final plan = HostPlan(
    project: options['project'] ?? '',
    account: options['account'] ?? '',
    hostName: options['host-name'],
    recoveryOnly: legacyRental,
    existingRentalTag: options['rental-tag'],
    forge: options['forge'] != 'false',
    publicKey: '',
    collection: options['collection'],
    collectionSha256: options['collection-sha256'],
    loginUser: options['login-user'] ?? (serverOnly ? 'root' : 'ubuntu'),
    distribution: options['distribution'] ?? 'snapshots',
    machineFile: options['machine-file'],
    bundle: options['bundle'],
  );
  return verb == 'up' ? run.up(plan) : run.down(plan, giveBackAnyway: giveBackAnyway);
}

/// `find`: the server rented for `--project` now, asked of the provider alone.
Future<int> _find(List<String> arguments) async {
  final options = <String, String>{};
  for (var i = 0; i < arguments.length; i++) {
    final name = arguments[i];
    if (!const <String>{'--project', '--scaleway-project', '--zone'}.contains(name) || i + 1 >= arguments.length) {
      return _wrong('$name is not an option of find');
    }
    final value = arguments[++i];
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value)) return _wrong('$name takes a name, not "$value"');
    options[name.substring(2)] = value;
  }
  final missing = const <String>['project', 'scaleway-project'].where((n) => !options.containsKey(n)).toList();
  if (missing.isNotEmpty) return _wrong('missing ${missing.map((n) => '--$n').join(', ')}');
  final (key, failed) = await _scalewayKey();
  if (key == null) return failed!;
  return findRented(scalewayFor(options, scalewayOverHttps(key)), options['project']!, out: stdout, err: stderr);
}

/// Prints the server [provider] lists for [project] as one JSON line to [out] and returns 0, or says to [err] that
/// none is rented and returns 69, or 65 where the provider fails. Asks [provider] for its list once and nothing else.
Future<int> findRented(
  HostProvider provider,
  String project, {
  required StringSink out,
  required StringSink err,
}) async {
  final RentedHost? host;
  try {
    host = await provider.find(HostPlan.tagFor(project));
  } on ProviderFailed catch (e) {
    // As up and down say it: the provider refused or could not be asked, which is no answer about the server.
    err.writeln('porelo-host: $e');
    return Exit.refused;
  }
  if (host == null) {
    err.writeln('porelo-host: no server of $project is rented');
    return Exit.unreachable;
  }
  out.writeln(jsonEncode({'id': host.id, 'address': host.address, 'ready': host.ready}));
  return Exit.done;
}

/// Scaleway's secret key from the secret store, or null and the code to end with.
Future<(String?, int?)> _scalewayKey() async {
  final store = SecretStore.forThisSystem();
  final String? key;
  try {
    key = await store.read(providerKeyName('scaleway'));
  } on SecretStoreFailed {
    stderr.writeln('porelo-host: the operation could not be confirmed');
    return (null, Exit.refused);
  } finally {
    await store.close();
  }
  if (key == null) return (null, _wrong('no key for scaleway is kept: run `porelo-host key set scaleway` first'));
  return (key, null);
}

/// The Elastic Metal host [options] name: their project, zone and offer, each with its default.
ScalewayElasticMetal scalewayFor(Map<String, String> options, ScalewayApi api) => ScalewayElasticMetal(
  api: api,
  projectId: options['scaleway-project']!,
  zone: options['zone'] ?? 'fr-par-1',
  offer: options['offer'] ?? 'EM-I220E-NVME',
);

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
        final value = values.single.substring(values.single.indexOf('=') + 1).trim();
        final quoted =
            value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")));
        line = quoted ? value.substring(1, value.length - 1) : value;
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
