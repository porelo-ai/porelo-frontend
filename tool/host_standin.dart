// Build for a walk with: dart compile exe tool/host_standin.dart -o <walk>/porelo-host
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await _run(arguments);
  } on FileSystemException {
    exitCode = _wrong('Cannot read or update host-standin.json in PORELO_WALK.');
  } on FormatException {
    exitCode = _wrong('host-standin.json must contain a valid situation and state.');
  }
}

int _wrong(String words) {
  stderr.writeln(words);
  return Exit.usage;
}

Future<int> _run(List<String> arguments) async {
  final folder = Platform.environment['PORELO_WALK'];
  if (folder == null || folder.isEmpty) return _wrong('Set PORELO_WALK to the walk folder.');
  final file = File('$folder/host-standin.json');
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) throw const FormatException();
  final situation = decoded['situation'];
  final state = decoded['state'] ?? 'new';
  final pace = decoded['paceMilliseconds'] ?? 60000;
  if (!const {'clean', 'stop', 'refused', 'slow', 'down'}.contains(situation) ||
      !const {'new', 'waiting', 'done', 'down'}.contains(state) ||
      pace is! int ||
      pace < 0) {
    throw const FormatException();
  }
  if (arguments.isEmpty || !const {'up', 'down'}.contains(arguments.first)) {
    return _wrong('The host stand-in accepts up or down with host options.');
  }
  final verb = arguments.first;
  final options = <String, String>{};
  var answers = false;
  const valued = {
    '--project',
    '--account',
    '--public-key',
    '--identity',
    '--collection',
    '--scaleway-project',
    '--tresor',
    '--vpn-peer-public-key',
    '--vpn-peer-address',
    '--zone',
    '--given',
    '--host-key',
    '--login-user',
    '--distribution',
  };
  for (var i = 1; i < arguments.length; i++) {
    final option = arguments[i];
    if (option == '--answers-on-stdin' && verb == 'up') {
      answers = true;
    } else if (option == '--give-back-anyway' && verb == 'down') {
      continue;
    } else if (valued.contains(option) && i + 1 < arguments.length && !arguments[i + 1].startsWith('--')) {
      options[option] = arguments[++i];
    } else {
      return _wrong('Unsupported or incomplete host stand-in option.');
    }
  }
  if (const [
        '--project',
        '--account',
        '--public-key',
        '--identity',
        '--collection',
      ].any((key) => options[key]?.isNotEmpty != true) ||
      options.containsKey('--given') == options.containsKey('--scaleway-project') ||
      (options.containsKey('--given') && !options.containsKey('--host-key'))) {
    return _wrong('Give the project, account, key paths, collection and one host provider.');
  }
  if (answers) await stdin.drain<void>();

  Future<void> remember(String next) => file.writeAsString(
    jsonEncode({
      'situation': situation,
      'state': next,
      if (decoded.containsKey('paceMilliseconds')) 'paceMilliseconds': pace,
    }),
  );

  if (verb == 'down') {
    _emit(const Step('give-back', StepState.started));
    _emit(const Step('give-back', StepState.done, address: '192.0.2.10'));
    await remember('down');
    return Exit.done;
  }
  if (situation == 'down') return _wrong('The down situation needs the down command.');
  if (situation == 'refused') {
    _emit(const Step('rent', StepState.started));
    _emit(const Step('rent', StepState.refused, fix: 'Choose a host the provider can supply.'));
    return Exit.refused;
  }
  if (situation == 'slow') {
    _emit(const Step('play', StepState.started), seconds: pace / 1000);
    await Future<void>.delayed(Duration(milliseconds: pace));
    _emit(const Step('play', StepState.done));
  } else {
    for (final name in ['rent', 'ssh', 'copy', 'ansible', 'play']) {
      _emit(Step(name, StepState.started));
      _emit(Step(name, StepState.done));
    }
    if (situation == 'stop' && !(state == 'waiting' && answers)) {
      _emit(const Step('person', StepState.waiting, needs: ['drive', 'vault-new']));
      await remember('waiting');
      return Exit.waiting;
    }
    for (final name in ['drive', 'vault']) {
      _emit(Step(name, StepState.started));
      _emit(Step(name, StepState.done));
    }
  }
  _emit(
    const Step(
      'up',
      StepState.done,
      address: '192.0.2.10',
      account: 'porelo',
      socket: '/run/user/1000/porelo/porelod.sock',
    ),
  );
  await remember('done');
  return Exit.done;
}

void _emit(Step step, {num seconds = 0}) {
  final line = jsonDecode(step.toLine()) as Map<String, dynamic>;
  if (step.state == StepState.started) {
    line['text'] = 'The host stand-in is running ${step.step}.';
    line['seconds'] = seconds;
  }
  stdout.writeln(jsonEncode(line));
  stderr.writeln(step.fix ?? step.words ?? '${step.step}: ${step.state.name}');
}
