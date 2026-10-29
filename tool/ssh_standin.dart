// Build for a walk with: dart compile exe tool/ssh_standin.dart -o <walk>/bin/ssh
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

Future<void> main(List<String> arguments) async {
  final parsed = _parse(arguments);
  if (parsed == null) {
    stderr.writeln('The ssh stand-in does not support this form.');
    exitCode = 255;
    return;
  }
  if (parsed.helper != null) {
    exitCode = await _helper(parsed.helper!);
    return;
  }
  if (parsed.config) {
    stdout.writeln('identityfile ${parsed.identity ?? '~/.ssh/id_ed25519'}');
    return;
  }
  if (parsed.terminal != null) {
    exitCode = await _terminal(parsed.terminal!);
    return;
  }
  final target = Platform.environment['PORELO_WALK_HOST_SOCKET'];
  if (target == null || target.isEmpty) {
    stderr.writeln('Set PORELO_WALK_HOST_SOCKET to the host mock daemon socket.');
    exitCode = 255;
    return;
  }
  final local = parsed.local!;
  if (FileSystemEntity.typeSync(local, followLinks: false) != FileSystemEntityType.notFound) {
    stderr.writeln('The ssh stand-in will not replace an existing endpoint: $local');
    exitCode = 255;
    return;
  }
  ServerSocket? server;
  FileStat? made;
  final sockets = <Socket>{};
  final stopped = Completer<void>();
  final signals = <StreamSubscription<ProcessSignal>>[];
  void stop() {
    if (!stopped.isCompleted) stopped.complete();
  }

  try {
    for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
      signals.add(signal.watch().listen((_) => stop()));
    }
    server = await ServerSocket.bind(InternetAddress(local, type: InternetAddressType.unix), 0);
    made = FileStat.statSync(local);
    server.listen(
      (incoming) async {
        sockets.add(incoming);
        try {
          final outgoing = await Socket.connect(InternetAddress(target, type: InternetAddressType.unix), 0);
          sockets.add(outgoing);
          if (stopped.isCompleted) {
            outgoing.destroy();
            incoming.destroy();
            return;
          }
          try {
            await Future.wait([incoming.cast<List<int>>().pipe(outgoing), outgoing.cast<List<int>>().pipe(incoming)]);
          } finally {
            outgoing.destroy();
            sockets.remove(outgoing);
          }
        } on IOException {
          if (!stopped.isCompleted) {
            stderr.writeln('The ssh stand-in could not carry the connection to the host mock daemon.');
            exitCode = 255;
            stop();
          }
        } finally {
          incoming.destroy();
          sockets.remove(incoming);
        }
      },
      onError: (Object error) {
        stderr.writeln('The ssh stand-in could not accept a connection.');
        exitCode = 255;
        stop();
      },
    );
    stderr.writeln('Forwarding the walk socket at $local.');
    await stopped.future;
  } on IOException {
    stderr.writeln('The ssh stand-in could not bind the walk socket at $local.');
    exitCode = 255;
  } finally {
    await server?.close();
    for (final socket in sockets.toList()) {
      socket.destroy();
    }
    for (final signal in signals) {
      await signal.cancel();
    }
    // A failed bind or a replaced endpoint must never remove somebody else's file.
    if (made != null &&
        FileSystemEntity.typeSync(local, followLinks: false) == FileSystemEntityType.unixDomainSock &&
        FileStat.statSync(local).modified == made.modified) {
      File(local).deleteSync();
    }
  }
}

({bool config, String? local, String? identity, List<String>? terminal, String? helper})? _parse(
  List<String> arguments,
) {
  var config = false;
  var forward = false;
  var terminal = false;
  String? command;
  String? mapping;
  String? identity;
  String? host;
  var optionsEnded = false;
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    if (optionsEnded && host == null) {
      if (argument.isEmpty || argument.startsWith('-')) return null;
      host = argument;
      continue;
    }
    switch (argument) {
      case '--':
        if (optionsEnded || host != null) return null;
        optionsEnded = true;
      case '-T':
        if (terminal) return null;
      case '-G':
        config = true;
      case '-N':
        forward = true;
      case '-t':
        if (terminal) return null;
        terminal = true;
      case '-L' || '-o' || '-i':
        if (++i == arguments.length) return null;
        final value = arguments[i];
        if (value.isEmpty || value.startsWith('-')) return null;
        if (argument == '-L') {
          if (mapping != null) return null;
          mapping = value;
        }
        if (argument == '-i') identity = value;
      default:
        if (argument.startsWith('-') || argument.isEmpty) return null;
        if (host == null) {
          host = argument;
        } else {
          command = arguments.sublist(i).join(' ');
          i = arguments.length;
        }
    }
  }
  if (host == null) return null;
  if (!terminal && command != null) {
    if (config ||
        forward ||
        mapping != null ||
        !RegExp(r'^root@[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(host) ||
        !RegExp(r'^/usr/local/sbin/porelo-host-(person|project)( |$)').hasMatch(command)) {
      return null;
    }
    return (config: false, local: null, identity: identity, terminal: null, helper: command);
  }
  if (terminal) {
    if (config ||
        forward ||
        mapping != null ||
        command == null ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(host)) {
      return null;
    }
    final needs = _terminalNeeds(command);
    return needs == null ? null : (config: false, local: null, identity: identity, terminal: needs, helper: null);
  }
  if (config && !forward && mapping == null) {
    return (config: true, local: null, identity: identity, terminal: null, helper: null);
  }
  if (!config && forward && mapping != null) {
    final paths = mapping.split(':');
    if (paths.length == 2 && paths.every((path) => path.startsWith('/') && path.length > 1)) {
      return (config: false, local: paths.first, identity: identity, terminal: null, helper: null);
    }
  }
  return null;
}

List<String>? _terminalNeeds(String command) {
  final address =
      RegExp(r'[A-Za-z0-9][A-Za-z0-9._+-]*@[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*\.[A-Za-z]{2,}')
          .firstMatch(command)
          ?.group(0) ??
      '';
  for (final needs in const <List<String>>[
    ['drive'],
    ['vault-new'],
    ['vault'],
    ['drive', 'vault-new'],
    ['drive', 'vault'],
  ]) {
    if (needs.contains('drive') && address.isEmpty) continue;
    if (command == inTheLoginShell(hostStopCommand(needs, email: address))) return needs;
  }
  return null;
}

Future<int> _terminal(List<String> needs) async {
  Future<bool> prompt(String words, {bool secret = true}) async {
    final echo = stdin.hasTerminal ? stdin.echoMode : null;
    try {
      if (echo != null) stdin.echoMode = !secret;
      stdout.write(words);
      await stdout.flush();
      // The answer is dropped without being written, including on a piped walk test.
      return stdin.readLineSync() != null;
    } finally {
      if (echo != null) stdin.echoMode = echo;
      stdout.writeln();
    }
  }

  if (needs.contains('drive')) {
    stdout.writeln('The one-time code will show as you type it.');
    if (!await prompt('Password: ') || !await prompt('Enter your one-time password: ', secret: false)) return 1;
    stdout.writeln(
      needs.length > 1
          ? 'Logged in to Tresorit; the vault comes next.'
          : 'Logged in to Tresorit; close this terminal to continue host setup.',
    );
  }
  if (needs.contains('vault-new')) {
    if (!await prompt('New vault passphrase: ') || !await prompt('New vault passphrase again: ')) return 1;
    stdout.writeln('Vault initialized; close this terminal to continue host setup.');
  } else if (needs.contains('vault')) {
    if (!await prompt('Vault passphrase: ')) return 1;
    stdout.writeln('Vault unlocked; close this terminal to continue host setup.');
  }
  return 0;
}

class _Refusal implements Exception {
  const _Refusal(this.words, [this.code = 64]);
  final String words;
  final int code;
}

Never _refuse(String words, [int code = 64]) => throw _Refusal(words, code);

typedef _Laptop = ({String name, String ssh, String wg, String? address});

List<_Laptop> _keyBlock(String block, int network) {
  if (utf8.encode(block).length > 262144 || block.isEmpty) {
    _refuse('the laptop block is empty or too large');
  }
  final List<AdminLaptop> checked;
  try {
    checked = checkAdminKeyBlock(block, network);
  } on FormatException {
    _refuse('a laptop line must hold its name, ssh-ed25519 key, VPN key and optional address');
  }
  final lines = const LineSplitter().convert(block);
  final sshKeys = <String>{};
  final vpnKeys = <String>{};
  final laptops = <_Laptop>[];
  for (var i = 0; i < checked.length; i++) {
    final fields = lines[i].split(' ');
    final ssh = '${fields[1]} ${fields[2]}';
    if (!sshKeys.add(ssh) || !vpnKeys.add(fields[3])) {
      _refuse('a laptop name or public key is repeated in the block');
    }
    laptops.add((name: checked[i].name, ssh: ssh, wg: fields[3], address: checked[i].address));
  }
  return laptops;
}

String _block(List<_Laptop> laptops) =>
    [for (final laptop in laptops) '${laptop.name} ${laptop.ssh} ${laptop.wg} ${laptop.address}'].join('\n');

Future<String> _readKeyBlock() async {
  final bytes = <int>[];
  await for (final chunk in stdin) {
    if (bytes.length + chunk.length > 262144) _refuse('the laptop block is empty or too large');
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}

Future<int> _helper(String command) async {
  final family = command.startsWith('/usr/local/sbin/porelo-host-person') ? 'person' : 'project';
  try {
    final prefix = '/usr/local/sbin/porelo-host-$family ';
    final words = command.startsWith(prefix) ? command.substring(prefix.length) : '';
    final addPerson = family == 'person' ? RegExp(r'^add ([^ ]+) --role project-admin$').firstMatch(words) : null;
    final removePerson = family == 'person' ? RegExp(r'^(lock|purge) ([^ ]+)$').firstMatch(words) : null;
    final addProject = family == 'project'
        ? RegExp(r"^add ([^ ]+) ([^ ]+) --signed-by '(ssh-ed25519 [^']+)'$").firstMatch(words)
        : null;
    final removeProject = family == 'project' ? RegExp(r'^remove ([^ ]+)$').firstMatch(words) : null;
    if (addPerson == null && removePerson == null && addProject == null && removeProject == null) {
      _refuse(
        family == 'person'
            ? 'use add <user> --role project-admin, lock <user> or purge <user>'
            : 'usage: add <project> <admin> --signed-by "ssh-ed25519 <base64>" | remove <project>',
      );
    }
    final name = addPerson?.group(1) ?? removePerson?.group(2) ?? addProject?.group(1) ?? removeProject!.group(1)!;
    if (family == 'person' && !RegExp(r'^[a-z][a-z0-9-]{0,30}$').hasMatch(name)) {
      _refuse('the person name must match [a-z][a-z0-9-]{0,30}');
    }
    if (family == 'project' && !RegExp(r'^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$').hasMatch(name)) {
      _refuse('project must be 1 to 40 lowercase letters, digits or internal hyphens');
    }
    if (addProject != null) {
      if (!RegExp(r'^[a-z][a-z0-9-]{0,30}$').hasMatch(addProject.group(2)!)) {
        _refuse("admin must be a registered person's user name");
      }
      checkedEd25519(addProject.group(3)!);
    }
    final folder = Platform.environment['PORELO_WALK'];
    if (folder == null || folder.isEmpty) _refuse('Set PORELO_WALK to the walk folder.');
    final config = jsonDecode(await File('$folder/host-standin.json').readAsString());
    if (config is! Map<String, dynamic> || config['state'] != 'done') {
      _refuse('Prepare the walk server first.', 65);
    }
    final host = PreparedHost.read(config['host']);
    final state = File('$folder/ssh-standin.json');
    final Object? decoded = await state.exists()
        ? jsonDecode(await state.readAsString())
        : {'people': <String, dynamic>{}, 'projects': <String, dynamic>{}};
    if (decoded is! Map<String, dynamic> ||
        decoded['people'] is! Map<String, dynamic> ||
        decoded['projects'] is! Map<String, dynamic>) {
      throw const FormatException();
    }
    final people = decoded['people'] as Map<String, dynamic>;
    final projects = decoded['projects'] as Map<String, dynamic>;
    final laptops = <String, List<_Laptop>>{};
    for (final entry in people.entries) {
      if (entry.value case {'locked': bool _, 'block': final String block}) {
        final checked = _keyBlock(block, host.network);
        if (checked.any((laptop) => laptop.address == null)) throw const FormatException();
        laptops[entry.key] = checked;
      } else {
        throw const FormatException();
      }
    }
    for (final entry in projects.entries) {
      if (entry.value case {'admin': final String admin, 'signed_by': final String key}) {
        checkAdminName(admin);
        checkedEd25519(key);
      } else {
        throw const FormatException();
      }
    }
    Map<String, Object?> answer;
    if (addPerson != null) {
      if (name == 'root') {
        _refuse('the name belongs to root, a system account or an account outside the people records', 65);
      }
      final requested = _keyBlock(await _readKeyBlock(), host.network);
      final known = laptops[name];
      if (known != null) {
        if (known.length != requested.length) {
          _refuse('the recorded person has no account or has different laptops', 65);
        }
        for (final laptop in requested) {
          final old = known.where((each) => each.name == laptop.name).firstOrNull;
          if (old == null ||
              old.ssh != laptop.ssh ||
              old.wg != laptop.wg ||
              laptop.address != null && old.address != laptop.address) {
            _refuse('keys or addresses differ from the recorded laptop', 65);
          }
        }
      } else {
        final occupied = laptops.values.expand((each) => each).toList();
        if (requested.any((laptop) => occupied.any((old) => old.ssh == laptop.ssh || old.wg == laptop.wg))) {
          _refuse('a public key belongs to a recorded laptop', 65);
        }
        // .2 is the host admin's own laptop, made a peer when the server was prepared.
        final addresses = {'10.73.${host.network}.2', ...occupied.map((each) => each.address!)};
        for (final laptop in requested) {
          if (laptop.address != null && !addresses.add(laptop.address!)) {
            _refuse('a requested VPN address is outside the network or already reserved', 65);
          }
        }
        final allocated = <_Laptop>[];
        for (final laptop in requested) {
          final address =
              laptop.address ??
              [for (var n = 3; n <= 254; n++) '10.73.${host.network}.$n']
                  .where((each) => !addresses.contains(each))
                  .firstOrNull;
          if (address == null) _refuse('the host VPN network has no free laptop address', 65);
          addresses.add(address);
          allocated.add((name: laptop.name, ssh: laptop.ssh, wg: laptop.wg, address: address));
        }
        laptops[name] = allocated;
        people[name] = {'locked': false, 'block': _block(allocated)};
      }
      answer = {
        'person': name,
        'role': 'project-admin',
        'laptops': [
          for (final laptop in laptops[name]!) {'laptop': laptop.name, 'vpn_address': laptop.address},
        ],
      };
    } else if (removePerson != null) {
      if (!people.containsKey(name)) _refuse('the person is unknown to the people records', 65);
      final lock = removePerson.group(1) == 'lock';
      if (lock) {
        people[name] = {'locked': true, 'block': _block(laptops[name]!)};
      } else {
        people.remove(name);
      }
      answer = {'person': name, lock ? 'locked' : 'purged': true};
    } else if (addProject != null) {
      if (projects.containsKey(name)) _refuse('/etc/porelo-host/projects/$name.conf exists', 65);
      final admin = addProject.group(2)!;
      if (!people.containsKey(admin)) {
        _refuse('/etc/porelo-host/people/$admin.conf is missing; no registered record or forge settings', 69);
      }
      projects[name] = {'admin': admin, 'signed_by': addProject.group(3)!};
      answer = {'project': name, 'admin': admin, 'organization': name, 'publisher': 'porelo-publisher-$name'};
    } else {
      if (!projects.containsKey(name)) _refuse('unknown project $name', 65);
      // Read at most one line and discard it before recording any public state.
      stdin.readLineSync();
      projects.remove(name);
      answer = {'project': name, 'removed': true};
    }
    await state.writeAsString(jsonEncode({'people': people, 'projects': projects}));
    stdout.writeln(jsonEncode(answer));
    return 0;
  } on _Refusal catch (error) {
    stderr.writeln('porelo-host-$family: ${error.words}');
    return error.code;
  } on FormatException {
    stderr.writeln('porelo-host-$family: invalid public keys or walk state');
    return 64;
  } on FileSystemException {
    stderr.writeln('porelo-host-$family: cannot read or update the walk state in PORELO_WALK');
    return 64;
  }
}
