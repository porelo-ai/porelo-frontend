import 'dart:convert';

import 'package:porelo_frontend/client.dart';

/// Validates a complete save on a copy, publishing nothing on a refusal.
Map<String, dynamic> applyPlanningMove(Map<String, dynamic> source, Map<String, dynamic> parameters) {
  Never refuse(String name, Map<String, dynamic> fields) =>
      throw VarlinkException('org.fuin.porelo.Tasks1.$name', fields);
  if (parameters['revision'] != source['revision']) refuse('StaleRevision', {'revision': source['revision']});
  final board = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  final states = (board['states'] as List).cast<Map<String, dynamic>>();
  final stories = (board['stories'] as List).cast<Map<String, dynamic>>();
  final batch = parameters['moves'];
  if (batch is! List) {
    refuse('MoveNotAllowed', {'item': '', 'from': '', 'to': '', 'reason': 'Moves must be a list.'});
  }
  final seen = <String>{};
  final moved = <String>[];
  for (final value in batch) {
    final move = value is Map<String, dynamic> ? value : <String, dynamic>{};
    final isStory = move['story'] is String;
    final id = (isStory ? move['story'] : move['issue']) as String? ?? '';
    final to = move['to'] as String? ?? '';
    void invalid(String reason) => refuse('MoveNotAllowed', {'item': id, 'from': '', 'to': to, 'reason': reason});
    if (id.isEmpty ||
        (move['story'] != null) == (move['issue'] != null) ||
        !seen.add('${isStory ? 'story' : 'issue'} $id')) {
      invalid('Each move must name exactly one item, once.');
    }
    final story = stories.where((story) => story['id'] == id).firstOrNull;
    final issue = stories
        .expand((story) => (story['issues'] as List? ?? []).cast<Map<String, dynamic>>())
        .where((issue) => issue['id'] == id)
        .firstOrNull;
    if (isStory && story == null) refuse('NoSuchStory', {'story': id});
    if (!isStory && issue == null) refuse('NoSuchIssue', {'issue': id});
    final from = (isStory ? story! : issue!)['state'];
    final target = states.where((state) => state['name'] == to).firstOrNull;
    if (target?['kind'] == 'WORKING') refuse('EnteredOnlyByWork', {'item': id, 'to': to});
    if (target == null || !{'WAITING', 'CLOSED'}.contains(target['kind'])) {
      refuse('StateNotAllowed', {
        'item': id,
        'from': from,
        'to': to,
        'reason': 'The destination must be a configured waiting or closed state.',
      });
    }
    if (isStory) {
      for (final item in (story!['issues'] as List? ?? []).cast<Map<String, dynamic>>()) {
        if (item['state'] == from) {
          item['state'] = to;
          moved.add(item['id'] as String);
        }
      }
      story['state'] = to;
    } else {
      issue!['state'] = to;
      moved.add(id);
    }
  }
  for (final story in stories) {
    final issues = (story['issues'] as List? ?? []).cast<Map<String, dynamic>>();
    if (issues.isEmpty) continue;
    final open = issues
        .where((issue) => states.any((state) => state['name'] == issue['state'] && state['kind'] != 'CLOSED'))
        .toList();
    final candidates = open.isEmpty ? issues : open;
    candidates.sort(
      (a, b) => states
          .indexWhere((state) => state['name'] == a['state'])
          .compareTo(states.indexWhere((state) => state['name'] == b['state'])),
    );
    story['state'] = candidates.first['state'];
  }
  board['revision'] = '${source['revision']}:moved';
  board['moved'] = moved;
  return board;
}
