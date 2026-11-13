import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// The ideas a task proposed, as its row in `List` and `Watch` gives them.
void main() {
  Task taskWith(Map<String, dynamic> fields) =>
      Task.from(<String, dynamic>{'name': 'porelo-checkout-migrate', 'project': 'checkout', ...fields});

  // Harm: an idea a task proposed is lost or changed on its way to the planner, or a machine that does not list ideas
  // reads as one whose task proposed none.
  test('a row gives each proposed idea as the machine kept it, in order, and none from a machine without them', () {
    final task = taskWith({
      'ideas': [
        {'id': 'idea-1', 'title': 'Cache the mirror', 'whatMustBeTrue': 'A second build\nfetches nothing.', 'at': 'T1'},
        {'id': 'idea-2', 'title': 'Name the run', 'whatMustBeTrue': 'The log names its run.', 'at': 'T2', 'new': 1},
        'not an idea',
      ],
    });

    expect(task.ideas!.map((idea) => (idea.id, idea.title, idea.mustBeTrue, idea.at)), [
      ('idea-1', 'Cache the mirror', 'A second build\nfetches nothing.', 'T1'),
      ('idea-2', 'Name the run', 'The log names its run.', 'T2'),
      ('', '', '', ''),
    ]);
    expect(taskWith({'ideas': <Object>[]}).ideas, isEmpty);
    expect(taskWith({}).ideas, isNull);
    expect(taskWith({'ideas': 'idea-1'}).ideas, isNull);
  });

  // Harm: an entry missing a field, or no entry at all, is dropped without a word, so its idea is lost unseen.
  test('an entry missing a field is kept with that field empty, for the window to refuse in words', () {
    final idea = taskWith({
      'ideas': [
        {'id': 'idea-1', 'title': 7},
      ],
    }).ideas!.single;

    expect((idea.id, idea.title, idea.mustBeTrue, idea.at), ('idea-1', '', '', ''));
  });
}
