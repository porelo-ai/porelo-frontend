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
  final board = planningFixture();
  planningMaps(board, 'stories').singleWhere((story) => story['id'] == 'ST291')['title'] =
      'Story supplied by another machine';
  World.elsewhere.planning['checkout'] = board;
  await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/tmp/world-elsewhere.sock'));
  await World.settle(tester);
}
