import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/earlier_output.dart';

import '../features/support/world.dart';
import '../support/session_recording.dart';

/// What an earlier output holds and where it stops, read from the model against the stand-in machine.
void main() {
  const task = 'porelo-billing-shell';
  late FakeBackend backend;

  setUp(() => backend = FakeBackend(<Task>[]));

  EarlierOutput earlier(int held) {
    final output = EarlierOutput(backend: backend, task: task, heldLines: held);
    addTearDown(output.dispose);
    return output;
  }

  // Harm: a new session whose recording grew past the old position is mixed with the previous session or refused.
  test('NoSuchLog starts again from Screen and keeps only the new recording', () async {
    final old = SessionRecording(<String>[for (var i = 0; i < 3000; i++) 'old output $i']);
    backend.recordings[task] = old;
    final output = earlier(1);
    await output.more();
    expect(output.lines, isNotEmpty);
    final newest = SessionRecording(<String>[for (var i = 0; i < 6000; i++) 'new output $i']);
    backend.recordings[task] = newest;

    await output.more();

    expect(backend.screensAsked[task], 2);
    expect(
      output.lines,
      newest.lines.sublist(5000, 5999),
      reason: 'the old session is replaced, newest screen line matched',
    );
    expect(output.end, EarlierEnd.more);
    expect(output.problem, isNull);
    final asked = backend.screenBeforeAsked[task]!;
    expect(asked.last, (of: newest.of, before: newest.end));
    expect(asked[asked.length - 2].of, old.of, reason: 'the old position retains its old name until refused');
  });

  // Harm: a failed Screen during replacement leaves old output to be prepended to the new session on retry.
  test('retrying a failed replacement Screen still discards the previous recording', () async {
    backend.recordings[task] = SessionRecording(<String>[for (var i = 0; i < 3000; i++) 'old output $i']);
    final output = earlier(1);
    await output.more();
    final held = output.lines;
    final newest = SessionRecording(<String>[for (var i = 0; i < 6000; i++) 'new output $i']);
    backend.recordings[task] = newest;
    backend.screenRefusals[task] = const VarlinkDisconnected('the recording could not be read');
    await output.more();
    expect(output.end, EarlierEnd.failed);
    expect(output.lines, held, reason: 'what was read stays until a new Screen answers');
    backend.screenRefusals.remove(task);

    await output.retry();

    expect(output.lines, newest.lines.sublist(5000, 5999));
    expect(output.end, EarlierEnd.more);
    expect(output.problem, isNull);
    expect(backend.screenBeforeAsked[task]!.last, (of: newest.of, before: newest.end));
  });

  // Harm: a repeatedly replaced recording loops on Screen forever instead of saying why it could not be read.
  test('a recording that changes again during recovery stops with the daemon refusal', () async {
    backend.recordings[task] = SessionRecording(<String>['a', 'b']);
    backend.screenBeforeRefusals[task] = const VarlinkException('org.fuin.porelo.Tasks1.NoSuchLog');
    final output = earlier(1);

    await output.more();

    expect(output.end, EarlierEnd.failed);
    expect(output.problem, contains('NoSuchLog'));
    expect(backend.screensAsked[task], 2);
    expect(backend.screenBeforeSizes[task], hasLength(2));
  });

  // Harm: a recording of a million lines is held whole, and the window's memory grows without bound.
  test('it stops at its limit, says it is full and asks for no more', () async {
    backend.recordings[task] = SessionRecording(<String>[for (var i = 0; i < 60000; i++) 'output $i']);
    final output = earlier(10);
    for (var i = 0; i < 80 && output.end == EarlierEnd.more; i++) {
      await output.more();
    }
    expect(output.end, EarlierEnd.full);
    expect(output.lines.length, inInclusiveRange(EarlierOutput.mostLines, EarlierOutput.mostLines + 1000));
    final asked = backend.screenBeforeSizes[task]!.length;
    await output.more();
    expect(backend.screenBeforeSizes[task]!.length, asked, reason: 'nothing is asked for once it is full');
  });

  // Harm: an empty page that is not the start is asked for again for ever, or is shown as the start.
  test('an empty page that is not the start is a failure, asked for once', () async {
    backend.recordings[task] = SessionRecording(<String>['a', 'b']);
    backend.screenBeforeEmptyNotAtStart.add(task);
    final output = earlier(1);
    await output.more();
    expect(output.end, EarlierEnd.failed);
    expect(output.problem, contains('empty page'));
    expect(backend.screenBeforeSizes[task], hasLength(1));
  });

  // Harm: a first page that the terminal's lines cover entirely leaves the pane with nothing and no way on, though
  // older pages exist.
  test('a first page that matches the screen entirely is dropped and the next page is taken whole', () async {
    final recorded = <String>[for (var i = 0; i < 3000; i++) 'output $i'];
    backend.recordings[task] = SessionRecording(recorded);
    final output = earlier(1000);
    await output.more();
    expect(output.lines, recorded.sublist(1000, 2000), reason: 'the page before the dropped one, whole');
    expect(output.mayOverlap, isFalse);
    expect(output.end, EarlierEnd.more);
  });

  // Harm: lines of a recording that the screen covers are shown again when the whole recording is the screen.
  test('a recording the screen covers entirely leaves nothing but the start', () async {
    backend.recordings[task] = SessionRecording(<String>[for (var i = 0; i < 30; i++) 'output $i']);
    final output = earlier(30);
    await output.more();
    expect(output.lines, isEmpty);
    expect(output.end, EarlierEnd.start);
  });

  // Harm: one huge recorded line is held whole, and memory is bounded by lines only in name.
  test('a huge recorded line is held cut', () async {
    backend.recordings[task] = SessionRecording(<String>['x' * 100000, 'y']);
    final output = earlier(1);
    await output.more();
    expect(output.lines.first.length, lessThan(mostLineCharacters + 100));
  });

  // Harm: a terminal holding more than one page of the recording's newest lines shows them again above itself, because
  // the match was only looked for in the first page.
  test('a terminal holding 2,500 lines whose recording ends with them shows none of them and no divider', () async {
    final recorded = <String>[for (var i = 0; i < 6000; i++) 'output $i'];
    backend.recordings[task] = SessionRecording(recorded);
    final output = earlier(2500);
    await output.more();
    expect(output.lines.last, 'output 3499', reason: 'the line before the terminal’s 2,500');
    expect(output.lines, recorded.sublist(3000, 3500), reason: 'nothing of the 2,500 shows, the rest is whole');
    expect(output.matched, 2500);
    expect(output.mayOverlap, isFalse);
  });

  // Harm: one line that differs in the middle drops everything older than it, or shows everything after it again.
  test(
    'a line that differs ends the match: later lines are dropped, the line and those before it show whole',
    () async {
      final recorded = <String>[for (var i = 0; i < 6000; i++) 'output $i'];
      backend.recordings[task] = SessionRecording(recorded);
      final held = <String>[...recorded.sublist(3500)];
      held[1000] = 'redrawn differently';
      backend.screens[task] = Screen(of: '', lines: held, live: true);
      final output = earlier(2500);
      await output.more();
      expect(output.lines.last, 'output 4500', reason: 'the differing line is shown, the lines after it are not');
      expect(output.lines.first, 'output 4000');
      expect(output.matched, 1499);
      expect(output.mayOverlap, isTrue);
    },
  );
}
