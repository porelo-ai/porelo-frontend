import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'collection.dart';
import 'remote.dart';
import 'server_contract.dart';
import 'ssh.dart';

/// What `check --available` ends with when the carried collection holds no check.
const hostCheckNotCarried = 4;

/// How long one check may hold its ssh before it reads as not having answered.
const hostCheckLimit = Duration(minutes: 3);

/// More than any check says; a machine answering without end is not read to its end.
const _mostAnswer = 1024 * 1024;

const _scriptPath = 'roles/check/files/porelo-host-check';
const _limitsPath = 'roles/check/files/limits.json';

/// What a finding says of one thing about the machine.
enum HostCheckState {
  /// Measured, and it is what was asked.
  pass,

  /// Measured, and it stands in the way.
  fail,

  /// Measured, and it stands in nobody's way yet.
  warn,

  /// Cannot be known beforehand, which is no pass.
  unknown,
}

/// One thing the check looked at. An id this window does not know is shown the same as any other.
class HostCheckFinding {
  /// Constructor taking what the check said of it.
  /// What the window and a stopped run say of this finding where the check's own words are not enough.
  String? get plainWords => id == 'virtualization' && state.name == 'fail'
      ? "This machine's CPU offers no virtualization, so it cannot run VMs in its jobs. Nothing was installed. "
            'Choose a machine with hardware virtualization, or turn off This host runs VMs in its jobs.'
      : null;

  const HostCheckFinding({required this.id, required this.state, this.found, this.unit, this.asked, this.todo});

  /// The finding's stable name.
  final String id;

  /// What it came to.
  final HostCheckState state;

  /// What was measured: any JSON value.
  final Object? found;

  /// The unit of what was measured.
  final String? unit;

  /// What was asked for: any JSON value.
  final Object? asked;

  /// What to do about it.
  final String? todo;

  factory HostCheckFinding._read(Object? value) {
    if (value is! Map) throw const FormatException('A finding is no object.');
    final id = value['id'];
    if (id is! String || id.isEmpty) throw const FormatException('A finding has no id.');
    final state = HostCheckState.values.asNameMap()[value['state']];
    if (state == null) throw const FormatException('A finding has no state of the contract.');
    String? words(String key) => switch (value[key]) {
      null => null,
      final String text => text,
      _ => throw FormatException('A finding\'s $key is no text.'),
    };
    return HostCheckFinding(
      id: id,
      state: state,
      found: value['found'],
      unit: words('unit'),
      asked: value['asked'],
      todo: words('do'),
    );
  }

  /// The finding as the check's contract spells it.
  Map<String, Object?> toJson() => {
    'id': id,
    'state': state.name,
    'found': found,
    'unit': unit,
    'asked': asked,
    'do': todo,
  };
}

/// What the check answered, or that it did not.
class HostCheckAnswer {
  const HostCheckAnswer._({required this.ok, required this.complete, required this.findings})
    : answered = true,
      said = null;

  /// The check gave no answer, for the reason in [said]: never a passed machine.
  const HostCheckAnswer.notAnswered(String this.said)
    : ok = false,
      complete = false,
      findings = const [],
      answered = false;

  /// Reads what came on standard output with the exit it ended by: anything out of the contract, or at odds with itself,
  /// is the check not having answered.
  factory HostCheckAnswer.read(String text, {required int exitCode}) {
    if (!const {0, 1, 2}.contains(exitCode)) {
      return const HostCheckAnswer.notAnswered('The check ended without an answer.');
    }
    try {
      final json = jsonDecode(text);
      if (json is! Map || json['v'] != 1) throw const FormatException();
      if (exitCode == 2) return HostCheckAnswer.notAnswered(_saidBy(json));
      final ok = json['ok'];
      final complete = json['complete'];
      final listed = json['findings'];
      if (ok is! bool || complete is! bool || listed is! List) throw const FormatException();
      final findings = [for (final each in listed) HostCheckFinding._read(each)];
      final fails = findings.any((each) => each.state == HostCheckState.fail);
      final consistent =
          findings.isNotEmpty &&
          (ok ? !fails : fails || !complete) &&
          (exitCode == 0 ? ok && complete : !(ok && complete));
      if (!consistent) throw const FormatException();
      return HostCheckAnswer._(ok: ok, complete: complete, findings: findings);
    } on FormatException {
      return HostCheckAnswer.notAnswered(
        exitCode == 2 ? _couldNotRun : 'The check gave an answer that cannot be read.',
      );
    }
  }

  static const _couldNotRun = 'The check could not run on the machine.';

  static String _saidBy(Map<dynamic, dynamic> json) {
    final said = json['said'];
    if (said is String && said.isNotEmpty) return said;
    // The script's own answer at exit 2 names the fault's kind alone.
    final why = json['why'];
    return why is String && why.isNotEmpty ? '$_couldNotRun It said: $why.' : _couldNotRun;
  }

  /// What a run that stops on this answer says: every fault at once, or why nothing is known.
  String get refusalWords {
    if (!answered) return said ?? 'The check gave no answer, so nothing was installed.';
    final faults = [
      for (final finding in findings)
        if (finding.state.name == 'fail') '${finding.id}: ${finding.plainWords ?? finding.todo ?? 'it failed'}',
    ];
    return 'The machine\'s check found: ${faults.join('; ')}. Nothing was installed.';
  }

  /// Whether nothing fails, as the check says it.
  final bool ok;

  /// Whether the check ran to its end.
  final bool complete;

  /// Every finding, in the check's order.
  final List<HostCheckFinding> findings;

  /// Whether the check answered at all.
  final bool answered;

  /// Why the check did not answer.
  final String? said;

  /// Whether the installation may be offered.
  bool get passed => answered && ok && complete;

  /// The exit `check` ends with: 0 passed, 1 has findings, 2 no answer.
  int get exitCode => passed
      ? 0
      : answered
      ? 1
      : 2;

  /// The one JSON object `check` prints.
  Map<String, Object?> toJson() => {
    'v': 1,
    'ok': ok,
    'complete': complete,
    'findings': [for (final each in findings) each.toJson()],
    'said': ?said,
  };
}

/// The check's script and limits, as a collection carries them.
class HostCheckFiles {
  /// Constructor taking both as text.
  const HostCheckFiles({required this.script, required this.limits});

  /// The script sent on standard input.
  final String script;

  /// The limits, as one line of JSON.
  final String limits;
}

/// The check inside the gzipped collection [tarGz], or null when it holds none or cannot be read.
HostCheckFiles? readHostCheckFiles(List<int> tarGz) {
  try {
    final files = _tarFiles(Uint8List.fromList(gzip.decode(tarGz)), const {_scriptPath, _limitsPath});
    final script = files[_scriptPath];
    final limits = files[_limitsPath];
    if (script == null || limits == null) return null;
    final decoded = jsonDecode(utf8.decode(limits));
    if (decoded is! Map) return null;
    return HostCheckFiles(script: utf8.decode(script), limits: jsonEncode(decoded));
  } on FormatException {
    return null;
  }
}

/// The [wanted] regular files of a tar, by the path they were wanted by, under at most one leading directory.
///
/// A tar's newest entry of a name is what extracting it would leave, so the last one stands.
Map<String, Uint8List> _tarFiles(Uint8List tar, Set<String> wanted) {
  const block = 512;
  final found = <String, Uint8List>{};
  for (var at = 0; at + block <= tar.length;) {
    final header = Uint8List.sublistView(tar, at, at + block);
    if (header.every((byte) => byte == 0)) break;
    _checkTarSum(header);
    final size = _tarNumber(Uint8List.sublistView(header, 124, 136));
    if (size < 0) throw const FormatException('A tar entry says it has less than nothing.');
    final start = at + block;
    if (start + size > tar.length) throw const FormatException('A tar entry runs past its end.');
    final type = header[156];
    if (type == 0 || type == 0x30) {
      final name = _tarName(header);
      for (final each in wanted) {
        if (_names(name, each)) found[each] = Uint8List.sublistView(tar, start, start + size);
      }
    }
    at = start + (size + block - 1) ~/ block * block;
  }
  return found;
}

bool _names(String name, String wanted) {
  final parts = path.posix.split(path.posix.normalize(name));
  return parts.join('/') == wanted || (parts.length > 1 && parts.skip(1).join('/') == wanted);
}

void _checkTarSum(Uint8List header) {
  final said = _tarNumber(Uint8List.sublistView(header, 148, 156));
  var sum = 0;
  for (var i = 0; i < header.length; i++) {
    sum += i >= 148 && i < 156 ? 0x20 : header[i];
  }
  if (sum != said) throw const FormatException('A tar header does not add up.');
}

int _tarNumber(Uint8List field) {
  final text = latin1.decode(field).replaceAll('\u0000', ' ').trim();
  if (text.isEmpty) return 0;
  return int.tryParse(text, radix: 8) ?? (throw const FormatException('A tar number is not octal.'));
}

String _tarName(Uint8List header) {
  String text(int from, int to) {
    final field = Uint8List.sublistView(header, from, to);
    final end = field.indexOf(0);
    return latin1.decode(end < 0 ? field : Uint8List.sublistView(field, 0, end));
  }

  final prefix = text(257, 262) == 'ustar' ? text(345, 500) : '';
  return prefix.isEmpty ? text(0, 100) : '$prefix/${text(0, 100)}';
}

/// The check in the collection carried beside this command or named by [collection], taken only by its digest; null
/// when there is none, the digest differs, or it holds no check.
Future<HostCheckFiles?> readCarriedHostCheck({
  String? collection,
  String? collectionSha256,
  String? resolvedExecutable,
  ({String version, String fileName, String sha256}) release = hostCollection,
}) async {
  final source =
      collection ?? path.join(File(resolvedExecutable ?? Platform.resolvedExecutable).parent.path, release.fileName);
  final expected = collection == null ? release.sha256 : collectionSha256 ?? '';
  try {
    if (FileSystemEntity.typeSync(source, followLinks: false) != FileSystemEntityType.file) return null;
    final bytes = await File(source).readAsBytes();
    if (sha256.convert(bytes).toString() != expected.toLowerCase()) return null;
    return readHostCheckFiles(bytes);
  } on FileSystemException {
    return null;
  }
}

/// The check's choices out of what the window and `up` hold.
///
/// The ports are left out: those in [settings] are this computer's forwards, which the machine is never told.
/// [forge] goes always, as `up` turns an absent choice into a forge too; [kvm] goes only when it was chosen.
Map<String, Object> hostCheckChoices(HostPreparationSettings settings, {required bool forge, String? kvm}) => {
  'forge': forge,
  if (kvm != null) 'kvm': kvm == 'true',
  'jobs': ?settings.forgeRunnerCapacity,
  'job_cpus': ?settings.forgeJobCpus,
  // Podman also takes `b`, as bytes, and the check reads bytes with no letter.
  'job_memory': ?settings.forgeJobMemory?.replaceFirst(RegExp('[bB]\$'), ''),
};

/// Sends a public script on [remote]: whole answers where [remote] can give them.
HostCheckSend hostCheckSender(Remote remote, String host) =>
    (command, script, onLine) => switch (remote) {
      final OpenSsh ssh => ssh.runWithPublicInput(
        host,
        'root',
        command,
        script: script,
        onLine: onLine,
        limit: _mostAnswer,
      ),
      _ => remote.run(host, 'root', command, input: script, onLine: onLine),
    };

/// Sends [script] to the machine on standard input and runs [command] on it.
typedef HostCheckSend = Future<RemoteResult> Function(String command, String script, void Function(String line) onLine);

/// Runs the check [files] on a machine by [send], once, and copies nothing there.
Future<HostCheckAnswer> askHostCheck(
  HostCheckFiles files, {
  required Map<String, Object> choices,
  required HostCheckSend send,
}) async {
  final lines = <String>[];
  var size = 0;
  final RemoteResult result;
  try {
    result = await send(
      'python3 - --limits ${quoteForAShell(files.limits)} --choices ${quoteForAShell(jsonEncode(choices))}',
      files.script,
      (line) {
        size += line.length + 1;
        if (size <= _mostAnswer) lines.add(line);
      },
    );
  } on Exception {
    return const HostCheckAnswer.notAnswered('ssh could not be started on this computer.');
  }
  if (size > _mostAnswer || result.exitCode == OpenSsh.answeredTooMuch) {
    return const HostCheckAnswer.notAnswered('The machine answered far more than a check says.');
  }
  if (_sshOrShellFault(result) case final why?) return HostCheckAnswer.notAnswered(why);
  final answer = HostCheckAnswer.read(lines.join('\n'), exitCode: result.exitCode);
  final tail = _lastLine(result.stderr);
  return answer.answered || tail.isEmpty ? answer : HostCheckAnswer.notAnswered('${answer.said} It said: $tail');
}

/// Why the script never ran, told from ssh's own exit and words or the shell's; null when it ran.
String? _sshOrShellFault(RemoteResult result) {
  final said = result.stderr;
  if (result.exitCode == 255) {
    if (said.contains('Permission denied')) {
      return 'The machine refused the login as root with your key. Run the command above on the machine, then check '
          'again.';
    }
    if (said.contains('Host key verification failed') || said.contains('HOST IDENTIFICATION HAS CHANGED')) {
      return 'The machine answered with another SSH host key than the one given here. Compare the key, then check '
          'again.';
    }
    if (said.contains('timed out')) return 'The machine gave no answer in time. Check its address, then check again.';
    if (RegExp('Could not resolve|Connection refused|No route to host|Connection closed|Network is').hasMatch(said)) {
      return 'This computer does not reach the machine: ${_lastLine(said)}';
    }
    final tail = _lastLine(said);
    return tail.isEmpty ? 'ssh could not log in to the machine.' : 'ssh could not log in to the machine: $tail';
  }
  if (result.exitCode == 127 || RegExp(r'python3\S*: (.*)?(not found|No such file)').hasMatch(said)) {
    return 'The machine has no python3, which the check runs on. Install it there, then check again.';
  }
  return null;
}

/// A machine's last word, one short line with nothing that could move a terminal.
String _lastLine(String words) {
  final lines = const LineSplitter().convert(words).map((line) => line.trim()).where((line) => line.isNotEmpty);
  if (lines.isEmpty) return '';
  final last = lines.last.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
  return last.length <= 200 ? last : '${last.substring(0, 200)}…';
}
