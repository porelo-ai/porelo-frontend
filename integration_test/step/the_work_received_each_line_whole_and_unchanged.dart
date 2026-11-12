import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/story_play.dart';
import 'i_type_and_erase_it_with_ctrlu_before_in_the_terminal_of_the_work.dart';

/// Usage: the work received each line whole and unchanged
///
/// Read on the machine, never in the window: the stub keeps the first line it reads in its session's file, byte for
/// byte, and says every line back; the terminal echoes it too, so each line stands whole at least twice in the session.
Future<void> theWorkReceivedEachLineWholeAndUnchanged(WidgetTester tester) => played(
  tester,
  '9 the work received each line whole and unchanged',
  () async {
    if (Played.typed.isEmpty) fail('nothing was typed into the work');
    final kept = base64.decode((await inTheWork(r'cat "$HOME"/.porelo-stub-sessions/*.session | base64 -w0')).trim());
    final first = utf8.encode('${Played.typed.first}\n');
    if (!_same(kept, first)) {
      fail(
        'asked for the first line kept as typed, ${_bytes(first)}; the stub kept ${_bytes(kept)} '
        '("${utf8.decode(kept, allowMalformed: true).trim()}")',
      );
    }
    var session = <String>[];
    List<String> missing() => [
      for (final line in Played.typed)
        if (session.where((each) => each == line).length < 2) line,
    ];
    final joined = erased == null ? null : '$erased${Played.typed.last}';
    final by = DateTime.now().add(const Duration(seconds: 20));
    while (true) {
      session = await theSessionOfTheWork();
      if (missing().isEmpty) break;
      if (DateTime.now().isAfter(by)) {
        fail(
          'asked for each line whole twice in the session, as echoed and as said back; missing '
          '${missing().map((each) => '"$each"').join(', ')}; the session showed: '
          '${session.where((each) => each.isNotEmpty).join(' / ')}',
        );
      }
      await pumpFor(tester, const Duration(seconds: 2));
    }
    if (joined != null && session.any((line) => line.contains(joined))) {
      fail('asked for "$erased" erased by Ctrl-U; the work received "$joined"');
    }
  },
  leansOn: 'terminal',
  goesOn: true,
);

bool _same(List<int> a, List<int> b) =>
    a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

String _bytes(List<int> bytes) => bytes.map((each) => each.toRadixString(16).padLeft(2, '0')).join(' ');
