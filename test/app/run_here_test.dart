// Harm guarded: a local command that never ends (git behind a dead network, Core's CLI waiting on a host, a KeePassXC
// read) left the interface waiting without end, with nothing said and nothing to do.
@TestOn('linux')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

void main() {
  late Duration before;
  setUp(() {
    before = runHereLimit;
    runHereLimit = const Duration(milliseconds: 600);
  });
  tearDown(() => runHereLimit = before);

  test('a command that never ends is ended at the limit and says what to do', () async {
    final started = DateTime.now();
    final refused = await runHere('sleep', ['30']).then<Object?>((ran) => ran, onError: (Object error) => error);
    expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 10)), reason: 'it must not wait 30 s');
    expect(refused, isA<WorkspaceRefused>(), reason: 'every caller shows a refusal, not a bare exit code');
    expect('$refused', contains('sleep'), reason: 'the sentence names the command that hung');
    expect('$refused', contains('was ended'), reason: 'the sentence says it was stopped');
  });

  test('a command whose child keeps its output open is answered all the same', () async {
    final started = DateTime.now();
    final ran = await runHere('sh', ['-c', 'sleep 30 & echo started']);
    expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 10)), reason: 'it must not wait 30 s');
    expect(ran.code, 0, reason: 'the command itself ended at once');
    expect(ran.out, contains('started'), reason: 'what it wrote before its end is kept');
  });

  // Harm: a command that never read its input held the interface at the write, before its limit even began.
  test('a command that never reads text fed to it is ended at the limit too', () async {
    final started = DateTime.now();
    final big = List<int>.filled(4 << 20, 65);
    final refused = await runHere('sh', [
      '-c',
      'sleep 30',
    ], input: String.fromCharCodes(big)).then<Object?>((ran) => ran, onError: (Object error) => error);
    expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 10)), reason: 'it must not wait 30 s');
    expect(refused, isA<WorkspaceRefused>());
  });

  test('a quick command answers as before', () async {
    final ran = await runHere('sh', ['-c', 'echo out; echo err >&2; exit 3']);
    expect(ran, (code: 3, out: 'out\n', err: 'err\n'), reason: 'nothing changes for a command within its limit');
  });
}
