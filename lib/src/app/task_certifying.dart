import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:porelo_frontend/client.dart';

import 'machines.dart';
import 'run_here.dart';
import 'run_porelo.dart';

/// Why this computer does not certify what a host asked, in words a person can act on.
class CertifyRefused implements Exception {
  /// Constructor taking the words.
  const CertifyRefused(this.words);

  /// What is said beside the start, and answered to the host.
  final String words;

  @override
  String toString() => words;
}

/// How long past the seven days a host may ask, for the clocks of two computers.
const Duration _longest = Duration(days: 7, minutes: 5);

final RegExp _ed25519 = RegExp(r'^ssh-ed25519 ([A-Za-z0-9+/]+={0,2})( [^\r\n]*)?$');
final RegExp _principal = RegExp(r'^task:([a-z0-9][a-z0-9-]{0,62}):([a-zA-Z0-9][a-zA-Z0-9_.-]*)$');

/// [text] with whatever could forge a line or hide a character shown as a question mark.
String _printable(String text) => String.fromCharCodes(text.runes.map((rune) => _hides(rune) ? 0x3f : rune));

bool _hides(int rune) =>
    rune < 0x20 ||
    (rune >= 0x7f && rune <= 0x9f) ||
    rune == 0xad ||
    (rune >= 0x200b && rune <= 0x200f) ||
    (rune >= 0x2028 && rune <= 0x202e) ||
    (rune >= 0x2060 && rune <= 0x206f) ||
    rune == 0xfeff;

/// Has this computer's agent certify the one key a host asked for, and answers the certificate.
///
/// Everything asked is checked here first, as the command line checks it: a host is not trusted to
/// ask only for its own task. The agent itself never leaves this computer, and nothing here holds
/// a secret; the private key stays in the agent, which is what signs.
///
/// [project] and [task] are what the person asked to start; where they named one, the host must
/// have asked for that one. [now] and [run] stand in for the clock and the programs in tests.
Future<String> certifyHere(
  StartCertify asked, {
  String? project,
  String? task,
  RunHere run = runHere,
  Map<String, String> environment = const <String, String>{},
  DateTime? now,
}) async {
  final at = (now ?? DateTime.now()).toUtc();
  _check(asked, project: project, task: task, now: at);
  final Ran listed;
  try {
    listed = await run(openSsh('ssh-add'), const <String>['-L'], environment: environment);
  } on ProcessException {
    throw const CertifyRefused('This computer has no ssh-add, so no key here can certify this task.');
  }
  if (listed.code != 0 && listed.code != 1) {
    throw CertifyRefused(
      'No SSH agent answers on this computer, so '
      '${asked.certifiers.isEmpty ? 'no key of yours' : _named(asked.certifiers)} can certify this task. '
      'Open your agent, or KeePassXC, and start it again.',
    );
  }
  final held = _keysOf(listed.out);
  final String? certifier = asked.certifiers.isEmpty ? held.values.firstOrNull : _firstHeld(asked.certifiers, held);
  if (certifier == null && asked.certifiers.isEmpty) {
    throw const CertifyRefused(
      'Your SSH agent holds no Ed25519 key to certify this task with. '
      'Add one (ssh-add), or unlock KeePassXC, and start it again.',
    );
  }
  if (certifier == null) {
    throw CertifyRefused(
      'Your SSH agent does not hold ${_named(asked.certifiers)}, which this project lets certify. '
      'Add it (ssh-add), or unlock KeePassXC, and start it again.',
    );
  }
  final directory = await Directory.systemTemp.createTemp('porelo-certify-');
  try {
    final person = p.join(directory.path, 'person.pub');
    final key = p.join(directory.path, 'task.pub');
    await File(person).writeAsString('$certifier\n');
    await File(key).writeAsString('${asked.key}\n');
    final signed = await run(
      openSsh('ssh-keygen'),
      <String>[
        '-q',
        '-s',
        person,
        '-U',
        '-I',
        _printable(asked.keyId),
        '-n',
        asked.principal,
        '-V',
        // No Z, which an older ssh-keygen refuses; it reads local time, so local time is UTC here.
        '${_stamp(at.subtract(const Duration(seconds: 60)))}:${_stamp(asked.validBefore.toUtc())}',
        key,
      ],
      environment: <String, String>{...environment, 'TZ': 'UTC'},
    );
    final written = File(p.join(directory.path, 'task-cert.pub'));
    if (signed.code != 0 || !await written.exists()) {
      final why = signed.err.trim();
      throw CertifyRefused(
        'Your SSH agent did not certify this task with ${_named(<String>[certifier])}'
        '${why.isEmpty ? '' : ': ${_printable(why)}'}.',
      );
    }
    return (await written.readAsString()).trim();
  } finally {
    await directory.delete(recursive: true);
  }
}

void _check(StartCertify asked, {String? project, String? task, required DateTime now}) {
  if (!_isEd25519(asked.key)) {
    throw const CertifyRefused('The host asked to certify a key that is not Ed25519, so it was not certified.');
  }
  final principal = _principal.firstMatch(asked.principal);
  final clean = _printable(asked.principal);
  if (principal == null) {
    throw CertifyRefused('The host asked to certify "$clean", which is no task, so it was not certified.');
  }
  if ((project != null && principal.group(1) != project) || (task != null && principal.group(2) != task)) {
    throw CertifyRefused(
      'The host asked to certify "$clean", which is not the task you started, so it was not certified.',
    );
  }
  if (!asked.validBefore.isAfter(now)) {
    throw const CertifyRefused('The host asked for a certificate that has already ended, so it was not certified.');
  }
  if (asked.validBefore.isAfter(now.add(_longest))) {
    throw const CertifyRefused('The host asked for a certificate longer than seven days, so it was not certified.');
  }
  if (_printable(asked.keyId).trim().isEmpty) {
    throw const CertifyRefused('The host asked for a certificate with no identity, so it was not certified.');
  }
  // The one task with no members to name: its starter's key certifies it, as the contract says.
  if (asked.certifiers.isEmpty && principal.group(1) != defaultProject) {
    throw const CertifyRefused('The host named no key of the project\'s members to certify with.');
  }
  for (final certifier in asked.certifiers) {
    if (!_isEd25519(certifier)) {
      throw const CertifyRefused('The host named a certifier that is not an Ed25519 key, so nothing was certified.');
    }
  }
}

/// Whether [key] is a whole Ed25519 public key: its type, and exactly the bytes such a key has.
bool _isEd25519(String key) {
  if (!_ed25519.hasMatch(key)) return false;
  try {
    final blob = base64.decode(_blob(key));
    return blob.length == 51 && utf8.decode(blob.sublist(4, 15), allowMalformed: true) == 'ssh-ed25519';
  } on FormatException {
    return false;
  }
}

/// The first of [certifiers] that [held] holds, compared without comments, as the agent's own line.
String? _firstHeld(List<String> certifiers, Map<String, String> held) {
  for (final certifier in certifiers) {
    final line = held[_blob(certifier)];
    if (line != null) return line;
  }
  return null;
}

Map<String, String> _keysOf(String listed) => <String, String>{
  for (final line in const LineSplitter().convert(listed))
    if (_ed25519.hasMatch(line.trim())) _blob(line.trim()): line.trim(),
};

String _blob(String key) => key.split(' ')[1];

/// What a person finds these keys by: the fingerprint `ssh-add -l` shows.
String _named(List<String> keys) {
  final named = keys.map(_fingerprint).toList();
  if (named.isEmpty) return 'no key';
  if (named.length == 1) return 'the key ${named.single}';
  return 'any of the keys ${named.join(', ')}';
}

String _fingerprint(String key) {
  final digest = sha256.convert(base64.decode(_blob(key)));
  return 'SHA256:${base64.encode(digest.bytes).replaceAll('=', '')}';
}

String _stamp(DateTime utc) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
}

/// What a person is told once [task]'s certificate is within a day of ending, or has ended, for a
/// task that still runs on it; null at all other times, and where the machine does not say.
String? certificateEnding(Task task, {DateTime? now}) {
  final until = task.certifiedUntil;
  if (!task.running || !task.certified || until == null) return null;
  final left = until.difference((now ?? DateTime.now()).toUtc());
  if (left <= Duration.zero) {
    return 'Its certificate has ended, so its commits and pushes are refused. Certify it for another week.';
  }
  if (left > const Duration(days: 1)) return null;
  final words = left.inHours >= 1
      ? 'in ${left.inHours} hours'
      : left.inMinutes >= 1
      ? 'in ${left.inMinutes} minutes'
      : 'within a minute';
  return 'Its certificate ends $words. Certify it for another week.';
}

/// Why [task] cannot be certified anew from here, or null. Its names came from a machine: one that
/// could read as an option of the command is not passed to it.
String? whyNoCertifyAgain(Task task) {
  if (!task.certified) return 'its commits are not signed by a certified key';
  if (!task.running) return 'it is not running';
  if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]*$').hasMatch(task.task)) return 'the machine does not name it plainly';
  if (task.project.isNotEmpty && !RegExp(r'^[a-z0-9][a-z0-9-]{0,62}$').hasMatch(task.project)) {
    return 'the machine does not name its project plainly';
  }
  return null;
}

/// What runs that command line; a test stands in for it, as it asks a real agent.
RunHere certifyAgainRunner = runPorelo;

/// The command line that certifies [task] anew, by this computer's agent: on [host] when it runs
/// on another machine. Only the command line asks the agent for this, and it asks here.
List<String> certifyAgainArguments(Task task, {String host = '', String project = ''}) => <String>[
  'task',
  'certify',
  task.task,
  if (host.isNotEmpty) ...<String>['--host', host],
  if (project.isNotEmpty) ...<String>['--project', project],
];

/// [text] with whatever could forge a line or hide a character shown as a question mark.
String printableForAPerson(String text) => _printable(text);
