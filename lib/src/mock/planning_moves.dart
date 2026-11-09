import 'dart:convert';

import 'package:porelo_frontend/client.dart';

import 'planning_data.dart';

/// Applies stand-in daemon moves to a copy, publishing nothing on a refusal.
Map<String, dynamic> applyPlanningMove(Map<String, dynamic> source, Map<String, dynamic> parameters) {
  Never refuse(String name, String detail) =>
      throw VarlinkException('org.fuin.porelo.Tasks1.$name', {'detail': detail});
  if (parameters['revision'] != source['revision']) {
    refuse('PlanningChanged', 'Planning changed since this board was read. Reload planning before saving.');
  }
  final board = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  final states = (board['states'] as List<dynamic>).cast<Map<String, dynamic>>();
  final stories = (board['stories'] as List<dynamic>).cast<Map<String, dynamic>>();
  void destination(Object? to) {
    final state = states.where((state) => state['name'] == to).firstOrNull;
    if (state == null || !{'WAITING', 'CLOSED'}.contains(state['kind'])) {
      refuse('PlanningRefused', 'A move must go to a waiting or closed state.');
    }
  }

  final batch = parameters['moves'];
  if (batch is List && batch.any((move) => move is Map && move.containsKey('story'))) {
    var result = board;
    final seen = <String>{};
    for (final move in batch) {
      if (move is! Map<String, dynamic> || (move.containsKey('story') == move.containsKey('issue'))) {
        refuse('PlanningRefused', 'Each move must name exactly one story or issue.');
      }
      final kind = move.containsKey('story') ? 'story' : 'issue';
      final id = move[kind];
      if (id is! String || id.isEmpty || !seen.add('$kind $id')) {
        refuse('PlanningRefused', 'Each story or issue must be named exactly once.');
      }
      try {
        result = kind == 'story'
            ? applyPlanningMove(result, {'story': id, 'to': move['to'], 'revision': result['revision']})
            : mockMoveIssues(result, [move], result['revision']);
      } on VarlinkException catch (error) {
        throw VarlinkException(error.name, {...error.parameters, kind: id});
      }
    }
    result['revision'] = '${source['revision']}-move';
    return result;
  }
  if (parameters.containsKey('story')) {
    final story = stories.where((story) => story['id'] == parameters['story']).firstOrNull;
    if (story == null) refuse('NoSuchStory', 'The story is unknown.');
    destination(parameters['to']);
    for (final issue in (story['issues'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>()) {
      if (issue['state'] == story['state']) issue['state'] = parameters['to'];
    }
    story['state'] = parameters['to'];
  } else {
    return mockMoveIssues(source, parameters['moves'], parameters['revision']);
  }
  board['revision'] = '${source['revision']}-move';
  return board;
}
