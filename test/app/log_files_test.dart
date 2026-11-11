import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/log_files.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/window_log.dart';

/// Where each log is, and what opening it does, with the desktop's opener faked: nothing here runs `xdg-open`.
void main() {
  late Directory scratch;
  late Desk before;
  final opened = <List<String>>[];
  var answer = ProcessResult(0, 0, '', '');

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('log-files-');
    before = desk;
    opened.clear();
    answer = ProcessResult(0, 0, '', '');
    desk = LinuxDesk(
      {'HOME': scratch.path, 'XDG_STATE_HOME': '${scratch.path}/state'},
      openAndWait: (executable, arguments) async {
        opened.add([executable, ...arguments]);
        return answer;
      },
    );
  });

  tearDown(() {
    desk = before;
    scratch.deleteSync(recursive: true);
  });

  // Harm: the link opens a file other than the one the window writes its log into.
  test('the window\'s log is frontend.log in logs under the window\'s state folder', () {
    expect(windowLogFolder(desk), '${scratch.path}/state/porelo/logs');
    expect(windowLogFile(desk), '${scratch.path}/state/porelo/logs/frontend.log');
  });

  group('the planner\'s log as planner.json names it', () {
    // Harm: a path the planner did not name is guessed and opened.
    test('is absent where the file names none', () {
      expect(plannerLogOf('{"port": 9, "token": "t"}'), isNull);
    });

    test('is the string the file names', () {
      expect(
        plannerLogOf('{"port": 9, "token": "t", "log": "/state/porelo/logs/planner.log"}'),
        '/state/porelo/logs/planner.log',
      );
    });

    // Harm: a field of another kind is cast and throws, or a relative one reaches the opener as an option.
    test('is absent where the field is no string, blank or not an absolute path', () {
      for (final log in ['7', 'null', '["/a"]', '{"path": "/a"}', '""', '"  "', '"--help"', '"logs/planner.log"']) {
        expect(plannerLogOf('{"port": 9, "token": "t", "log": $log}'), isNull, reason: log);
      }
    });

    test('is absent where the file is no JSON object', () {
      for (final text in ['', 'not json', '[]', '"/a"']) {
        expect(plannerLogOf(text), isNull, reason: text);
      }
    });
  });

  group('opening a log', () {
    late String folder;
    late String path;

    setUp(() {
      folder = windowLogFolder(desk);
      Directory(folder).createSync(recursive: true);
      path = '$folder/frontend.log';
    });

    // Harm: a path the planner's address file names reaches the desktop's opener, which runs or opens whatever lies
    // there, anywhere on this computer.
    test('a log outside the logs folder is refused, and the opener is not called', () async {
      final elsewhere = File('${scratch.path}/elsewhere.log')..writeAsStringSync('not a log\n');
      for (final outside in [
        elsewhere.path,
        '$folder/../../../elsewhere.log',
        '$folder/../logs/../../../elsewhere.log',
      ]) {
        final words = await openTheLog('the planner’s log', outside);
        expect(words, contains('refused'), reason: outside);
        expect(words, contains(folder), reason: outside);
      }
      expect(opened, isEmpty);
    });

    // Harm: a link in the logs folder takes the opener to a file elsewhere.
    test('a link in the logs folder is refused, and the opener is not called', () async {
      final elsewhere = File('${scratch.path}/elsewhere.log')..writeAsStringSync('not a log\n');
      Link('$folder/planner.log').createSync(elsewhere.path);
      final words = await openTheLog('the planner’s log', '$folder/planner.log');
      expect(words, contains('refused'));
      expect(opened, isEmpty);
    });

    // Harm: the opener is called on nothing and fails silently, or the person is told nothing.
    test('a log not there yet is said with its path, and the opener is not called', () async {
      final words = await openTheLog('the window’s log', path);
      expect(words, contains(path));
      expect(words, contains('not there yet'));
      expect(opened, isEmpty);
    });

    // Harm: a guessed path is opened where the planner names none.
    test('a planner that names no log is said, and the opener is not called', () async {
      final words = await openTheLog('the planner’s log', null);
      expect(words, plannerNamesNoLog);
      expect(opened, isEmpty);
    });

    test('a log that is there is opened with the desktop\'s opener and that path alone', () async {
      File(path).writeAsStringSync('a line\n');
      final words = await openTheLog('the window’s log', path);
      expect(opened, [
        ['xdg-open', path],
      ]);
      expect(words, contains(path));
      expect(words, isNot(contains('could not')));
    });

    // Harm: an opener that failed reads as a log that was opened.
    test('an opener that fails is said with its own words', () async {
      File(path).writeAsStringSync('a line\n');
      answer = ProcessResult(0, 4, '', 'xdg-open: no method available for opening it\n');
      final words = await openTheLog('the window’s log', path);
      expect(words, contains('could not be opened'));
      expect(words, contains('no method available for opening it'));
      expect(words, contains('4'));
    });

    test('an opener that is not there is said with its own words', () async {
      File(path).writeAsStringSync('a line\n');
      desk = LinuxDesk({
        'HOME': scratch.path,
        'XDG_STATE_HOME': '${scratch.path}/state',
      }, openAndWait: (executable, arguments) async => throw ProcessException(executable, arguments, 'No such file'));
      final words = await openTheLog('the window’s log', path);
      expect(words, contains('could not be opened'));
      expect(words, contains('No such file'));
    });
  });

  // Harm: what the opener said cuts a character in two, the decoding throws, and nothing is said at all.
  test('an opener whose output is no valid text is still answered with its exit code', () async {
    final result = await runOpener('sh', ['-c', r"printf 'cut \342\200' >&2; exit 4"]);
    expect(result.exitCode, 4);
    expect('${result.stderr}', startsWith('cut'));
  }, skip: Platform.isWindows);

  // Harm: an opener that runs what it opened in the foreground holds the answer, and the window never says anything.
  test('an opener still running after its patience counts as having taken the file', () async {
    final watch = Stopwatch()..start();
    final result = await runOpener('sh', ['-c', 'sleep 20'], patience: const Duration(milliseconds: 300));
    expect(result.exitCode, 0);
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)), reason: 'the opener is still running');
  }, skip: Platform.isWindows);

  // Harm: the window waits on the opener as long as the program it started runs, and never says what came of it.
  test('the opener is waited for until it ends, not until what it started closes its output', () async {
    final watch = Stopwatch()..start();
    final result = await runOpener('sh', ['-c', 'echo it said this >&2; sleep 20 & exit 3']);
    expect(result.exitCode, 3);
    expect('${result.stderr}'.trim(), 'it said this');
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)), reason: 'the program left running holds the output');
  }, skip: Platform.isWindows);
}
