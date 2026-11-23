import 'package:flutter_test/flutter_test.dart';

import 'idea_walk.dart';

/// The issues of the story whose reading stopped on blocking findings, as the planner named them once its readings
/// ended: kept in the walk's state from then on, since the planner names them no more once the person chose. Fails
/// where none was kept, as a later step that expects them would otherwise pass over nothing.
Future<List<({String id, String repository})>> theStoppedIssues() async {
  if (Walk.stopped.isEmpty) {
    fail('no issue whose reading stopped on blocking findings was kept by the step that reads the stopped reading');
  }
  return Walk.stopped;
}
