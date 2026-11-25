import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A task's reports, as its row in `List` and `Watch` counts them and `Reports` answers them.
void main() {
  Task taskWith(Map<String, dynamic> fields) =>
      Task.from(<String, dynamic>{'name': 'porelo-checkout-migrate', 'project': 'checkout', ...fields});

  // Harm: a row's count of reports is read wrong, so new reports show where there are none, or none where there are.
  test('a row gives the number of its last report, and none where it does not say one', () {
    expect(taskWith({'reports': 3}).reports, 3);
    expect(taskWith({'reports': 0}).reports, 0);
    expect(taskWith({}).reports, isNull, reason: 'a machine that does not say made not none');
    expect(taskWith({'reports': -1}).reports, isNull);
    expect(taskWith({'reports': '3'}).reports, isNull);
  });

  // Harm: the window reads the daemon's own answers otherwise than the daemon wrote them.
  test('the daemon\'s recorded answers are read as it gave them: a moved row and an empty page', () {
    Map<String, dynamic> recorded(String name) =>
        jsonDecode(File('test/fixtures/reports/$name.json').readAsStringSync()) as Map<String, dynamic>;

    expect(Task.from(recorded('watch-row-reports-moved')).reports, 1);
    final empty = TaskReports.from(recorded('task-reports-empty'));
    expect(empty.reports, isEmpty);
    expect((empty.last, empty.more), (0, false));
  });

  // Harm: a report at Porelo's bound, all of it characters drawn as nothing, is refused or changed on its way.
  test('a page holding one report at the bound, of characters drawn as nothing, is read whole', () {
    // The shape of the daemon's recorded answer: one report of 65,536 tag characters, with more to come.
    final text = String.fromCharCodes(List.filled(65536, 0xE0041));
    final page = TaskReports.from(
      jsonDecode(
        jsonEncode({
          'reports': [
            {'seq': 1, 'kind': 'status', 'text': text, 'at': '2026-11-25T07:10:36.583604725Z'},
          ],
          'last': 3,
          'more': true,
        }),
      ) as Map<String, dynamic>,
    );

    expect(page.reports.single.text.runes.length, 65536);
    expect((page.last, page.more), (3, true));
  });

  // Harm: a report's text is changed on its way, or an answer without its shape reads as a task that made no reports.
  test('an answer gives each report as the machine kept it, and one without its shape is refused, never empty', () {
    final page = TaskReports.from(<String, dynamic>{
      'reports': [
        {'seq': 1, 'kind': 'idea', 'text': 'Cache the mirror\nso a second build fetches nothing.', 'at': 'T1'},
        {'seq': 2, 'kind': 'note', 'text': '', 'new': true},
      ],
      'last': 2,
      'more': true,
    });

    expect(page.reports.map((report) => (report.seq, report.kind, report.text, report.at)), [
      (1, 'idea', 'Cache the mirror\nso a second build fetches nothing.', 'T1'),
      (2, 'note', '', ''),
    ]);
    expect((page.last, page.more), (2, true));
    for (final bad in <Map<String, dynamic>>[
      {'last': 0, 'more': false},
      {'reports': <Object>[], 'more': false},
      {'reports': <Object>[], 'last': 0},
      {'reports': <Object>[], 'last': -1, 'more': false},
      {
        'reports': ['not a report'],
        'last': 1,
        'more': false,
      },
      {
        'reports': [
          {'seq': 0, 'kind': 'idea', 'text': 'x'},
        ],
        'last': 1,
        'more': false,
      },
      {
        'reports': [
          {'seq': 1, 'text': 'x'},
        ],
        'last': 1,
        'more': false,
      },
      {'reports': <Object>[], 'last': 3, 'more': true},
      {
        'reports': [
          {'seq': 2, 'kind': 'k', 'text': 'x'},
          {'seq': 1, 'kind': 'k', 'text': 'x'},
        ],
        'last': 2,
        'more': false,
      },
      {
        'reports': [
          {'seq': 1, 'kind': 'k', 'text': 'x'},
          {'seq': 1, 'kind': 'k', 'text': 'x'},
        ],
        'last': 1,
        'more': false,
      },
      {
        'reports': [
          {'seq': 2, 'kind': 'k', 'text': 'x'},
        ],
        'last': 1,
        'more': false,
      },
      {
        'reports': [
          for (var seq = 1; seq <= 101; seq++) {'seq': seq, 'kind': 'k', 'text': 'x'},
        ],
        'last': 101,
        'more': false,
      },
    ]) {
      expect(() => TaskReports.from(bad), throwsFormatException, reason: '$bad');
    }
  });

  // Harm: a page that starts at or before the number asked after is read as new, and its reports shown twice.
  test('a page holding a report at or before the number asked after is the machine\'s fault', () async {
    final daemon = MockDaemon();
    await daemon.start();
    addTearDown(daemon.stop);
    daemon.method(
      'Reports',
      (parameters) => <String, dynamic>{
        'reports': [
          {'seq': 2, 'kind': 'k', 'text': 'x'},
        ],
        'last': 2,
        'more': false,
      },
    );
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    expect((await backend.taskReports('t', after: 1)).reports.single.seq, 2);
    await expectLater(backend.taskReports('t', after: 2), throwsFormatException);
  });
}
