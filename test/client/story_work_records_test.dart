import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

void main() {
  // Harm: absent findings look like an explicit clean reading and enable approval.
  test('absent or malformed findings remain unreported', () {
    for (final reply in <Map<String, dynamic>>[
      {},
      {'findings': null},
      {'findings': 'none'},
      {
        'findings': [false],
      },
      {
        'findings': [
          {'severity': 'BLOCKING'},
        ],
      },
      {
        'findings': [
          {'text': 'An unclassified finding.'},
        ],
      },
    ]) {
      expect(PlanningIssueDetail.from(reply).findingsReported, isFalse, reason: '$reply');
    }
    final clean = PlanningIssueDetail.from({'findings': <Map<String, dynamic>>[]});
    expect(clean.findingsReported, isTrue);
    expect(clean.findings, isEmpty);
  });

  // Harm: a blocking finding is hidden behind less urgent or future severity values.
  test('blocking findings lead without losing unknown severities or source order', () {
    final detail = PlanningIssueDetail.from({
      'findings': [
        {'severity': 'FUTURE', 'text': 'a'},
        {'severity': 'BLOCKING', 'text': 'b'},
        {'severity': 'NOTE', 'text': 'c'},
        {'severity': 'BLOCKING', 'text': 'd'},
      ],
    });
    expect(detail.findingsReported, isTrue);
    expect(detail.blockingFirst.map((each) => each.text), ['b', 'd', 'a', 'c']);
    expect(detail.blockingFirst.last.severity, 'NOTE');
  });

  // Harm: a missing start flag is taken as work having started.
  test('a start requires explicit confirmation and preserves its revision', () {
    expect(StoryWorkStarted.from({}).started, isFalse);
    expect(StoryWorkStarted.from({'started': 'true'}).started, isFalse);
    final started = StoryWorkStarted.from({'started': true, 'revision': 'opaque'});
    expect(started.started, isTrue);
    expect(started.revision, 'opaque');
  });

  // Harm: optional overrides erase daemon defaults or changed choices never reach the wire.
  test('start serializes changed choices and omits unspecified overrides', () {
    const request = StoryWorkRequest(
      project: 'demo',
      story: 'S1',
      to: 'Building',
      mode: 'AGENT',
      revision: 'r1',
      subAgents: [StoryWorkChoice(repository: 'repo', name: 'reader', choice: 'CHANGE', agent: 'agent', model: '')],
    );
    expect(request.toMap(), {
      'project': 'demo',
      'story': 'S1',
      'to': 'Building',
      'mode': 'AGENT',
      'revision': 'r1',
      'repositories': <Map<String, dynamic>>[],
      'subAgents': [
        {'repository': 'repo', 'name': 'reader', 'choice': 'CHANGE', 'agent': 'agent', 'model': ''},
      ],
    });
  });
  // Harm: With you opens a blank or stopped task from a malformed start answer.
  test('terminal selection rejects missing names and stopped tasks', () {
    for (final task in <Map<String, dynamic>>[
      {},
      {'name': 'stopped', 'running': false},
      {'name': '', 'running': true},
    ]) {
      expect(
        StoryWorkStarted.from({
          'started': true,
          'tasks': [task],
        }).terminalTask,
        isNull,
      );
      expect(
        StoryWorkStarted.from({
          'started': true,
          'tasks': [
            {'name': 'valid', 'running': true},
          ],
          'coordinator': task,
        }).terminalTask,
        isNull,
      );
    }
    expect(
      StoryWorkStarted.from({
        'started': true,
        'tasks': [
          {'name': 'valid', 'running': true},
        ],
      }).terminalTask!.name,
      'valid',
    );
  });
}
