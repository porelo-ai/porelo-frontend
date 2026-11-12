import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/story_play.dart';
import 'i_open_planning.dart';

/// Usage: the board appears, read through the planner on this computer
///
/// Read on the machine: the planner the driver installed runs, its address file names a port, and that port answers
/// on this computer. The token beside the port is never read out.
Future<void> theBoardAppearsReadThroughThePlannerOnThisComputer(WidgetTester tester) => played(
  tester,
  '3 the board appears, read through the planner on this computer',
  () async {
    final planner = Platform.environment['PORELO_STORY_PLANNER'] ?? '';
    if (planner.isEmpty) fail('PORELO_STORY_PLANNER names no installed planner: run this through tool/play_story.sh');
    if (theBoard.evaluate().isEmpty) fail('asked for the board or its choice of project; the window shows neither');
    if (!plannerRunsFrom(planner)) fail('asked for a process of this account running $planner; there is none');
    final file = File(plannerAddressFile());
    if (!file.existsSync()) fail('asked for the planner address file ${file.path}; there is none');
    final port = switch (jsonDecode(file.readAsStringSync())) {
      {'port': final int port} => port,
      _ => fail('asked for a port in ${file.path}; it names none'),
    };
    try {
      (await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 5))).destroy();
    } on SocketException catch (refused) {
      fail('asked for the planner answering on port $port, as ${file.path} names it; got $refused');
    }
  },
  leansOn: 'screen-planner',
  goesOn: true,
);
