import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/planning_board.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/mock/planning_data.dart';
import 'package:porelo_frontend/src/mock/planning_moves.dart';

Map<String, dynamic> _fixture() => {
  'states': [
    {'name': 'Ready', 'kind': 'WAITING'},
    {'name': 'Done', 'kind': 'CLOSED'},
    {'name': 'Elsewhere', 'kind': 'WAITING'},
    {'name': 'Building', 'kind': 'WORKING'},
    {'name': 'Future', 'kind': 'UNKNOWN'},
  ],
  'phases': [
    {
      'name': 'Work',
      'states': ['Ready', 'Done', 'Elsewhere', 'Building', 'Future'],
    },
  ],
  'stories': [
    {
      'id': 'StoryOne',
      'state': 'Ready',
      'issues': [
        {'id': 'IssueOne', 'state': 'Ready'},
        {'id': 'IssueTwo', 'state': 'Elsewhere'},
      ],
    },
    {'id': 'StoryTwo', 'state': 'Ready', 'issues': <Map<String, dynamic>>[]},
  ],
  'revision': 'initial',
};

class _Backend extends Fake implements FleetBackend {
  Map<String, dynamic> data = _fixture();
  final changes = StreamController<PlanningSnapshot>.broadcast(sync: true);
  final calls = <Map<String, dynamic>>[];
  String? refusedStory;
  Object? failure;
  Object? readFailure;
  bool confirmed = true;
  Completer<void>? gate;
  Completer<PlanningSnapshot>? listing;
  Completer<void>? listingStarted;
  Map<String, dynamic> Function(Map<String, dynamic>)? reply;
  int workflowReads = 0, storyReads = 0, watches = 0;
  @override
  Stream<PlanningSnapshot> watchStories(String project) {
    watches++;
    return changes.stream;
  }

  @override
  Future<PlanningSnapshot> planningWorkflow(String project) async {
    workflowReads++;
    return PlanningSnapshot.from(data);
  }

  @override
  Future<PlanningSnapshot> stories(String project) async {
    storyReads++;
    if (listing case final waiting?) {
      listingStarted?.complete();
      return waiting.future;
    }
    if (readFailure case final error?) throw error;
    return PlanningSnapshot.from(data);
  }

  @override
  Future<PlanningMoveResult> saveMoves(String project, List<PlanningMove> moves, String revision) async {
    final parameters = {'project': project, 'moves': moves.map((move) => move.toMap()).toList(), 'revision': revision};
    calls.add(parameters);
    if (gate case final waiting?) await waiting.future;
    if (failure case final error?) throw error;
    if (moves.any((move) => move is PlanningStoryMove && move.story == refusedStory)) {
      throw VarlinkException('org.fuin.porelo.Tasks1.WorkNotAllowed', {
        'story': refusedStory,
        'detail': 'Work is still running',
      });
    }
    if (!confirmed) return PlanningMoveResult.from({'revision': data['revision'], 'moved': <String>[]});
    data = applyPlanningMove(data, parameters);
    final answer = {'revision': data['revision'], 'moved': data['moved']};
    return PlanningMoveResult.from(reply?.call(answer) ?? answer);
  }
}

void main() {
  // Harm: a navigation entry point bypasses the unsaved-work question and changes the current page.
  test('all navigation entry points can be refused and explicitly resumed', () {
    final machine = Machine(name: 'demo', socketPath: '');
    final actions = <(void Function(ShellModel), Section)>[
      ((shell) => shell.goTo(Section.work), Section.work),
      ((shell) => shell.choosePlace(const ShellPlace(Section.work)), Section.work),
      ((shell) => shell.openMachine(machine), Section.machine),
      ((shell) => shell.openProject(machine, 'demo'), Section.project),
      ((shell) => shell.show('test', section: Section.work), Section.work),
    ];
    for (final action in actions) {
      final shell = ShellModel()..goTo(Section.planning);
      void Function()? resume;
      shell.beforeNavigation = (destination, next) {
        expect(destination, action.$2);
        resume = next;
        return false;
      };
      action.$1(shell);
      expect(shell.section, Section.planning);
      expect(shell.place.section, Section.planning);
      expect(shell.itemMachine, isNull);
      expect(resume, isNotNull);
      shell.beforeNavigation = null;
      resume!();
      expect(shell.section, action.$2);
      shell.dispose();
    }
  });

  late _Backend backend;
  late PlanningBoard board;
  var disposed = false;
  setUp(() async {
    disposed = false;
    backend = _Backend();
    board = PlanningBoard(backend, 'demo');
    backend.changes.add(PlanningSnapshot.from(backend.data));
    await Future<void>.delayed(Duration.zero);
    backend.workflowReads = 0;
  });
  tearDown(() async {
    if (!disposed) board.dispose();
    await backend.changes.close();
  });

  // Harm: staging or undo writes unreviewed changes or loses unrelated pending moves.
  test('staging and individual or complete undo never write', () {
    board.move('StoryOne', 'Done');
    board.move('StoryTwo', 'Done');
    expect(board.pending.keys, ['StoryOne', 'StoryTwo']);
    expect(board.stories.map((story) => story.state), ['Ready', 'Ready']);
    expect(board.cards('Done').map((story) => story.id), ['StoryOne', 'StoryTwo']);
    board.undo('StoryOne');
    expect(board.pending.keys, ['StoryTwo']);
    expect(board.cards('Ready').single.id, 'StoryOne');
    board.undoAll();
    expect(board.pending, isEmpty);
    expect(board.cards('Ready').map((story) => story.id), ['StoryOne', 'StoryTwo']);
    expect(backend.calls, isEmpty);
  });

  // Harm: several pending moves commit partly, or issue states stay stale until a watch arrives.
  test('one atomic save applies confirmed issues and rereads computed story states', () async {
    board.move('StoryOne', 'Done');
    board.move('StoryTwo', 'Done');
    await board.save();
    expect(backend.calls, [
      {
        'project': 'demo',
        'moves': [
          {'story': 'StoryOne', 'to': 'Done'},
          {'story': 'StoryTwo', 'to': 'Done'},
        ],
        'revision': 'initial',
      },
    ]);
    expect(board.pending, isEmpty);
    expect(board.cards('Done').map((story) => story.id), ['StoryTwo']);
    expect(board.stories.first.state, 'Elsewhere');
    expect(board.stories.first.issues.map((issue) => issue.state), ['Done', 'Elsewhere']);
    expect(board.snapshot!.revision, 'initial:moved');
    expect(backend.workflowReads, 0);
    expect(backend.storyReads, 1);
  });

  // Harm: issue drafts are lost on detail navigation or saved separately from story moves.
  test('story and explicit issue moves share one pending batch and one atomic save', () async {
    board.moveIssue('IssueTwo', 'Ready');
    board.move('StoryOne', 'Done');
    expect(board.pending, hasLength(2));
    expect(board.pendingIssues.keys, ['IssueTwo']);
    expect(backend.calls, isEmpty);
    await board.save();
    expect(backend.calls, [
      {
        'project': 'demo',
        'moves': [
          {'story': 'StoryOne', 'to': 'Done'},
          {'issue': 'IssueTwo', 'to': 'Ready'},
        ],
        'revision': 'initial',
      },
    ]);
    expect(board.pending, isEmpty);
    expect(board.stories.first.state, 'Ready');
    expect(board.stories.first.issues.map((issue) => issue.state), ['Done', 'Ready']);
    expect(backend.workflowReads, 0);
    expect(backend.storyReads, 1);
  });

  // Harm: refusal of an explicit issue publishes part of a story-and-issue batch.
  test('a refused explicit issue leaves the entire mixed batch pending and the store unchanged', () async {
    board.move('StoryOne', 'Done');
    board.moveIssue('IssueTwo', 'Ready');
    backend.failure = const VarlinkException('StateNotAllowed', {'item': 'IssueTwo', 'reason': 'Policy refuses'});
    await board.save();
    expect(backend.calls, hasLength(1));
    expect(board.pending, hasLength(2));
    expect(board.pending['StoryOne']!.problem, isNull);
    expect(board.pendingIssues['IssueTwo']!.problem, 'Policy refuses');
    expect(board.stories.first.state, 'Ready');
    expect(board.stories.first.issues.map((issue) => issue.state), ['Ready', 'Elsewhere']);
    expect(backend.data['revision'], 'initial');
    board.undoAll();
    expect(board.pending, isEmpty);
    expect(board.pendingIssues, isEmpty);
    expect(backend.calls, hasLength(1));
  });

  // Harm: an unreported embedded issue list silently discards a reviewed standalone issue draft.
  test('issue drafts survive unreported board lists and accept confirmed standalone rows', () {
    board.moveIssue('IssueTwo', 'Done');
    backend.changes.add(
      PlanningSnapshot.from({
        ...backend.data,
        'stories': [
          {'id': 'StoryOne', 'state': 'Ready'},
          {'id': 'StoryTwo', 'state': 'Ready', 'issues': <Map<String, dynamic>>[]},
        ],
        'revision': 'partial-issues',
      }),
    );
    expect(board.pendingIssues['IssueTwo']!.to, 'Done');
    board.moveIssue('Standalone', 'Done', reported: PlanIssue.from({'id': 'Standalone', 'state': 'Ready'}));
    expect(board.pendingIssues.keys, ['IssueTwo', 'Standalone']);
    expect(backend.calls, isEmpty);
    board.undoAll();
    expect(board.pending, isEmpty);
  });

  // Harm: a refused second story leaves an earlier story committed by an atomic save.
  test('the stand-in publishes none of a refused story batch', () {
    final source = _fixture();
    expect(
      () => applyPlanningMove(source, {
        'revision': 'initial',
        'moves': [
          {'story': 'StoryOne', 'to': 'Done'},
          {'story': 'StoryTwo', 'to': 'Building'},
        ],
      }),
      throwsA(isA<VarlinkException>().having((error) => error.parameters['item'], 'refused story', 'StoryTwo')),
    );
    expect((source['stories'] as List<dynamic>).map((story) => story['state']), ['Ready', 'Ready']);
    expect((source['stories'] as List<dynamic>).first['issues'][0]['state'], 'Ready');
    expect(source['revision'], 'initial');
  });

  // Harm: a refused issue batch leaves earlier issue changes published.
  test('issue batches remain atomic and reject stale or working destinations', () {
    final source = _fixture();
    expect(
      () => applyPlanningMove(source, {
        'revision': 'initial',
        'moves': [
          {'issue': 'IssueOne', 'to': 'Done'},
          {'issue': 'missing', 'to': 'Done'},
        ],
      }),
      throwsA(isA<VarlinkException>()),
    );
    expect((source['stories'] as List<dynamic>).first['issues'][0]['state'], 'Ready');
    for (final parameters in [
      {
        'revision': 'initial',
        'moves': [
          {'issue': 'IssueOne', 'to': 'Building'},
        ],
      },
      {
        'revision': 'old',
        'moves': [
          {'issue': 'IssueOne', 'to': 'Done'},
        ],
      },
    ]) {
      expect(() => applyPlanningMove(source, parameters), throwsA(isA<VarlinkException>()));
    }
    final result = applyPlanningMove(source, {
      'revision': 'initial',
      'moves': [
        {'issue': 'IssueOne', 'to': 'Done'},
      ],
    });
    final story = (result['stories'] as List<dynamic>).first;
    // The story's state is computed: its earliest open issue state in workflow order.
    expect(story['state'], 'Elsewhere');
    expect(story['issues'][0]['state'], 'Done');
    expect(story['issues'][1]['state'], 'Elsewhere');
    expect(result['revision'], allOf(isA<String>(), isNotEmpty, isNot(source['revision'])));
  });

  // Harm: a stale save overwrites others or loses the remaining operator intent.
  test('stale saves reread automatically and keep Save usable with reconciled intent', () async {
    board.move('StoryOne', 'Done');
    board.move('StoryTwo', 'Done');
    (backend.data['stories'] as List<dynamic>).first['state'] = 'Done';
    for (final issue
        in ((backend.data['stories'] as List<dynamic>).first['issues'] as List).cast<Map<String, dynamic>>()) {
      issue['state'] = 'Done';
    }
    (backend.data['stories'] as List<dynamic>)[1]['state'] = 'Elsewhere';
    backend.data['revision'] = 'changed';
    await board.save();
    expect(backend.calls.single['revision'], 'initial');
    expect(backend.workflowReads, 1);
    expect(backend.storyReads, 1);
    expect(board.pending.keys, ['StoryTwo']);
    expect(board.pending['StoryTwo']!.from, 'Elsewhere');
    expect(board.pending['StoryTwo']!.problem, isNull);
    expect(board.displayedState(board.stories.last), 'Done');
    expect(board.moveProblem, contains('StoryOne was moved to Done elsewhere'));
    await board.save();
    expect(backend.calls.last['revision'], 'changed');
    expect(board.pending, isEmpty);
    expect(board.stories.map((story) => story.state), ['Done', 'Done']);
  });

  // Harm: a newer watch answer leaves stale source states and revisions on pending moves.
  test('watch answers reconcile sources and use the displayed board revision', () async {
    board.move('StoryOne', 'Done');
    (backend.data['stories'] as List<dynamic>).first['state'] = 'Elsewhere';
    backend.data['revision'] = 'changed';
    backend.changes.add(PlanningSnapshot.from(backend.data));
    expect(board.pending['StoryOne']!.from, 'Elsewhere');
    board.move('StoryOne', 'Ready');
    expect(board.pending['StoryOne']!.from, 'Elsewhere');
    expect(board.pending['StoryOne']!.to, 'Ready');
    await board.save();
    expect(backend.calls.single['revision'], 'changed');
    expect(board.stories.first.state, 'Ready');
  });

  // Harm: one refused move blocks unrelated saves or erases another card's refusal.
  test('refusals belong only to their move and undo allows the remaining atomic save', () async {
    backend.refusedStory = 'StoryOne';
    board.move('StoryOne', 'Done');
    board.move('StoryTwo', 'Done');
    await board.save();
    expect(board.pending.keys, ['StoryOne', 'StoryTwo']);
    expect(board.pending['StoryOne']!.problem, 'Work is still running');
    expect(board.pending['StoryTwo']!.problem, isNull);
    expect(board.moveProblem, isNull);
    expect(board.cards('Ready').single.id, 'StoryOne');
    board.move('StoryTwo', 'Elsewhere');
    expect(board.pending['StoryOne']!.problem, 'Work is still running');
    await board.reload();
    expect(board.pending['StoryOne']!.problem, 'Work is still running');
    expect(board.cards('Ready').single.id, 'StoryOne');
    board.undo('StoryOne');
    await board.save();
    expect(board.pending, isEmpty);
    expect(board.stories.map((story) => story.state), ['Ready', 'Elsewhere']);
  });

  // Harm: correcting one refused destination leaves Save blocked or clears another refusal.
  test('a new drag clears exactly its own refusal', () async {
    backend.failure = const VarlinkException('org.fuin.porelo.Tasks1.WorkNotAllowed', {
      'detail': 'Work is still running',
    });
    board.move('StoryOne', 'Done');
    board.move('StoryTwo', 'Done');
    await board.save();
    expect(board.pending.values.map((move) => move.problem), ['Work is still running', 'Work is still running']);
    board.move('StoryOne', 'Elsewhere');
    expect(board.pending['StoryOne']!.problem, isNull);
    expect(board.pending['StoryTwo']!.problem, 'Work is still running');
    board.undo('StoryTwo');
    backend.failure = null;
    await board.save();
    expect(board.stories.first.state, 'Elsewhere');
    expect(board.pending, isEmpty);
  });

  // Harm: unrecognized or unnamed daemon refusals leave rejected cards marked as moved.
  test('all named and unnamed refusal kinds return the affected cards to their reported columns', () async {
    for (final name in ['WorkNotAllowed', 'NoSuchStory', 'AnotherRefusal']) {
      for (final named in [true, false]) {
        board.move('StoryOne', 'Done');
        board.move('StoryTwo', 'Done');
        backend.failure = VarlinkException('org.fuin.porelo.Tasks1.$name', {
          'detail': 'The daemon refused this save',
          if (named) 'story': 'StoryOne',
        });
        await board.save();
        expect(board.pending['StoryOne']!.problem, 'The daemon refused this save');
        expect(board.pending['StoryTwo']!.problem, named ? null : 'The daemon refused this save');
        expect(board.cards('Ready').map((story) => story.id), named ? ['StoryOne'] : ['StoryOne', 'StoryTwo']);
        expect(board.moveProblem, isNull);
        board.undoAll();
      }
    }
  });

  // Harm: retrying leaves an earlier save's reason on a card the new refusal did not name.
  test('retry clears every old problem before waiting and attaches only the new refusal', () async {
    board.move('StoryOne', 'Done');
    board.move('StoryTwo', 'Done');
    backend.refusedStory = 'StoryOne';
    await board.save();
    backend.refusedStory = 'StoryTwo';
    backend.gate = Completer<void>();
    final saved = board.save();
    expect(board.pending.values.map((move) => move.problem), [null, null]);
    backend.gate!.complete();
    await saved;
    expect(board.pending['StoryOne']!.problem, isNull);
    expect(board.pending['StoryTwo']!.problem, 'Work is still running');
  });

  // Harm: an earlier buffered watch replaces a later read with obsolete planning.
  for (final staleSave in [false, true]) {
    test('a later read wins over a buffered watch during ${staleSave ? 'stale save' : 'reload'}', () async {
      backend.listing = Completer<PlanningSnapshot>();
      backend.listingStarted = Completer<void>();
      if (staleSave) {
        board.move('StoryOne', 'Done');
        backend.failure = const VarlinkException('org.fuin.porelo.Tasks1.StaleRevision', {'detail': 'Board changed'});
      }
      final operation = staleSave ? board.save() : board.reload();
      await backend.listingStarted!.future;
      final intermediate = _fixture()..['revision'] = 'zz-earlier';
      (intermediate['stories'] as List<dynamic>).first['state'] = 'Elsewhere';
      backend.changes.add(PlanningSnapshot.from(intermediate));
      final latest = _fixture()..['revision'] = 'aa-later';
      backend.listing!.complete(PlanningSnapshot.from(latest));
      await operation;
      expect(board.snapshot!.revision, 'aa-later');
      expect(board.stories.first.state, 'Ready');
    });
  }

  // Harm: missing watch fields erase the complete board returned by a successful save.
  test('incomplete and unversioned buffered watches cannot replace a saved reply', () async {
    for (final broken in [
      <String, dynamic>{'revision': 'broken'},
      {..._fixture(), 'revision': ''},
    ]) {
      backend.data = _fixture();
      backend.changes.add(PlanningSnapshot.from(backend.data));
      backend.gate = Completer<void>();
      board.move('StoryOne', 'Done');
      final saved = board.save();
      backend.changes.add(PlanningSnapshot.from(broken));
      backend.gate!.complete();
      await saved;
      expect(board.snapshot!.complete, isTrue);
      expect(board.snapshot!.revision, 'initial:moved');
      expect(board.stories.first.issues.first.state, 'Done');
      expect(board.stories.first.state, 'Elsewhere');
    }
  });

  // Harm: discarding every deferred watch loses a real later board after an RPC refusal.
  test('a complete deferred watch newer than the held board is applied', () async {
    backend.gate = Completer<void>();
    backend.failure = const VarlinkException('org.fuin.porelo.Tasks1.NoSuchStory', {
      'story': 'StoryOne',
      'detail': 'Story unavailable',
    });
    board.move('StoryOne', 'Done');
    final saved = board.save();
    final changed = _fixture()..['revision'] = 'changed';
    (changed['stories'] as List<dynamic>).first['state'] = 'Elsewhere';
    backend.changes.add(PlanningSnapshot.from(changed));
    backend.gate!.complete();
    await saved;
    expect(board.snapshot!.revision, 'changed');
    expect(board.stories.first.state, 'Elsewhere');
    expect(board.pending['StoryOne']!.from, 'Elsewhere');
    expect(board.pending['StoryOne']!.problem, 'Story unavailable');
  });

  // Harm: dropping all pending moves leaves a stale error on a board with nothing to save.
  test('undoing the last move or all moves clears the board error', () async {
    for (final all in [false, true]) {
      board.move('StoryOne', 'Done');
      backend.failure = const VarlinkDisconnected('Connection lost');
      await board.save();
      expect(board.moveProblem, contains('Connection lost'));
      if (all) {
        board.undoAll();
      } else {
        board.undo('StoryOne');
      }
      expect(board.pending, isEmpty);
      expect(board.moveProblem, isNull);
    }
  });

  // Harm: malformed save answers erase intent or replace a complete board with missing data.
  test('save retains the board and pending intent on incomplete or unversioned replies', () async {
    for (final broken in <Map<String, dynamic> Function(Map<String, dynamic>)>[
      (reply) => {...reply}..remove('moved'),
      (reply) => {...reply, 'revision': ''},
    ]) {
      backend.data = _fixture();
      backend.changes.add(PlanningSnapshot.from(backend.data));
      backend.reply = broken;
      board.move('StoryOne', 'Done');
      await board.save();
      expect(board.snapshot!.complete, isTrue);
      expect(board.snapshot!.revision, 'initial');
      expect(board.stories.first.state, 'Ready');
      expect(board.pending.keys, ['StoryOne']);
      expect(board.pending['StoryOne']!.problem, isNotNull);
      expect(board.moveProblem, isNotNull);
      board.undoAll();
    }
  });

  // Harm: a negative confirmation is accepted as a saved board and loses pending work.
  test('a negative move confirmation retains intent and its original reported state', () async {
    backend.confirmed = false;
    board.move('StoryOne', 'Done');
    await board.save();
    expect(board.pending.keys, ['StoryOne']);
    expect(board.stories.first.state, 'Ready');
    expect(board.pending['StoryOne']!.problem, isNotNull);
    expect(board.cards('Ready').map((story) => story.id), contains('StoryOne'));
  });

  // Harm: reconnects during writes lose the only request to restart the watch.
  test('a reconnect during save restarts its watch after the save finishes', () async {
    backend.gate = Completer<void>();
    board.move('StoryOne', 'Done');
    final saved = board.save();
    await board.changeProject(backend, 'demo');
    expect(backend.watches, 1);
    backend.gate!.complete();
    await saved;
    await Future<void>.delayed(Duration.zero);
    expect(backend.watches, 2);
    backend.changes.add(PlanningSnapshot.from(backend.data));
    expect(board.live, isTrue);
    expect(board.stories.first.issues.first.state, 'Done');
    expect(board.stories.first.state, 'Elsewhere');
  });

  // Harm: repeated presses duplicate writes and edits during a write lose pending intent.
  test('an in-flight save rejects overlapping saves and edits', () async {
    backend.gate = Completer<void>();
    board.move('StoryOne', 'Done');
    final saved = board.save();
    await board.save();
    board.move('StoryTwo', 'Done');
    board.undoAll();
    expect(backend.calls, hasLength(1));
    expect(board.pending.keys, ['StoryOne']);
    backend.gate!.complete();
    await saved;
    expect(board.pending, isEmpty);
  });

  // Harm: completing a write after a closed window notifies a disposed model.
  test('late save replies do not notify after disposal', () async {
    backend.gate = Completer<void>();
    board.move('StoryOne', 'Done');
    var notifications = 0;
    board.addListener(() {
      notifications++;
    });
    final saved = board.save();
    final before = notifications;
    board.dispose();
    disposed = true;
    backend.gate!.complete();
    await saved;
    expect(notifications, before);
    expect(backend.changes.hasListener, isFalse);
  });

  // Harm: an unfamiliar state kind authorizes an unsupported move.
  test('unknown state kinds and working states never become pending', () async {
    board.move('StoryOne', 'Building');
    expect(board.pending, isEmpty);
    expect(board.moveProblem, isNull);
    board.move('StoryOne', 'Future');
    expect(board.pending, isEmpty);
    await board.save();
    expect(backend.calls, isEmpty);
    expect(board.stories.first.state, 'Ready');
  });

  // Harm: a deleted or unplaced story silently loses its pending intent or reconciliation notice.
  test('reconciliation names removed stories and retains notices across other drags', () async {
    board.move('StoryOne', 'Done');
    (backend.data['stories'] as List<dynamic>).removeAt(0);
    await board.reload();
    expect(board.pending, isEmpty);
    expect(board.moveProblem, contains('StoryOne is no longer reported'));
    (backend.data['stories'] as List<dynamic>).first['state'] = '';
    backend.changes.add(PlanningSnapshot.from(backend.data));
    // An unfamiliar state rereads the workflow before the watch answer is accepted.
    await Future<void>.delayed(Duration.zero);
    board.move('StoryTwo', 'Done');
    expect(board.pending['StoryTwo']!.from, '');
    expect(board.moveProblem, contains('StoryOne is no longer reported'));
  });

  // Harm: the mock shows a story where the daemon never puts it, so a saved move lands elsewhere than expected.
  test('every story of the mock board stands in the earliest open state of its issues', () {
    final board = mockPlanningBoard();
    final states = (board['states'] as List<dynamic>).cast<Map<String, dynamic>>();
    final order = [for (final state in states) state['name'] as String];
    final closed = {
      for (final state in states)
        if (state['kind'] == 'CLOSED') state['name'] as String,
    };
    final checked = <String>[];
    final breaking = <String>[];
    for (final story in (board['stories'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final issues = [
        for (final issue in (story['issues'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>())
          issue['state'] as String,
      ];
      if (issues.isEmpty) continue;
      expect(issues.every(order.contains), isTrue, reason: '${story['id']} has an issue outside the workflow');
      final open = issues.where((state) => !closed.contains(state)).toList();
      final earliest = (open.isEmpty ? issues : open).reduce((a, b) => order.indexOf(a) <= order.indexOf(b) ? a : b);
      checked.add(story['id'] as String);
      if (story['state'] != earliest) breaking.add('${story['id']} in ${story['state']}, rule says $earliest');
    }
    expect(checked, isNotEmpty);
    expect(breaking, isEmpty);
  });

  // Harm: the stand-in moves issues the daemon leaves, so a scenario saves a board the daemon never produces.
  test('the stand-in moves a story by its least advanced issues, whatever state the story reports', () {
    final source = _fixture();
    final story = (source['stories'] as List<dynamic>).first as Map<String, dynamic>;
    story['state'] = 'Elsewhere';
    final result = applyPlanningMove(source, {
      'revision': 'initial',
      'moves': [
        {'story': 'StoryOne', 'to': 'Done'},
      ],
    });
    final moved = (result['stories'] as List<dynamic>).first as Map<String, dynamic>;
    expect(result['moved'], ['IssueOne']);
    expect((moved['issues'] as List<dynamic>).map((issue) => issue['state']), ['Done', 'Elsewhere']);
  });

  // Harm: the board calls a story move the machine made unconfirmed, keeping a saved move pending.
  test('a story move expects its least advanced issues to move, not those in its shown state', () async {
    board.move('StoryOne', 'Done');
    backend.readFailure = const VarlinkException('org.fuin.porelo.Tasks1.PlanningAdapterRefused', {
      'adapter': 'board',
      'detail': 'The store is not reachable',
    });
    await board.save();
    // The reread failed, so the card shows its destination while its issues stand in Done and Elsewhere.
    expect(board.stories.first.state, 'Done');
    expect(board.stories.first.issues.map((issue) => issue.state), ['Done', 'Elsewhere']);
    backend.readFailure = null;
    backend.listing = Completer<PlanningSnapshot>();
    backend.listingStarted = Completer<void>();
    board.move('StoryOne', 'Ready');
    final saving = board.save();
    await backend.listingStarted!.future;
    expect(backend.calls.last['moves'], [
      {'story': 'StoryOne', 'to': 'Ready'},
    ]);
    // The machine moved IssueTwo, the least advanced; the board must take that as its confirmation.
    expect(backend.data['moved'], ['IssueTwo']);
    expect(board.pending['StoryOne']?.problem, isNull);
    expect(board.pending, isEmpty);
    expect(board.stories.first.issues.map((issue) => issue.state), ['Done', 'Ready']);
    backend.listing!.complete(PlanningSnapshot.from(backend.data));
    await saving;
  });
}
