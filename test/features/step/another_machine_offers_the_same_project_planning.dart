import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: another machine offers the same project planning
Future<void> anotherMachineOffersTheSameProjectPlanning(WidgetTester tester) async {
  World.elsewhere.theProjectsItHas = [
    Project.from({'name': 'checkout'}),
  ];
  // The same board as this machine's, so only the story's words tell the two machines apart.
  final board = jsonDecode(jsonEncode(World.planning.boards['checkout'] ?? planningFixture())) as Map<String, dynamic>;
  planningMaps(board, 'stories').singleWhere((story) => story['id'] == 'ST291')['title'] =
      'Story supplied by another machine';
  World.planningOn(World.elsewhere).boards['checkout'] = board;
  await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/tmp/world-elsewhere.sock'));
  await World.settle(tester);
}
