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
      backend.screens[task] = Screen(lines: held, live: true);
      final output = earlier(2500);
      await output.more();
      expect(output.lines.last, 'output 4500', reason: 'the differing line is shown, the lines after it are not');
      expect(output.lines.first, 'output 4000');
      expect(output.matched, 1499);
      expect(output.mayOverlap, isTrue);
    },
  );
}
