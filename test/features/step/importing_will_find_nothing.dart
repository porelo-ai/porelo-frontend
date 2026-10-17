import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: importing will find nothing
Future<void> importingWillFindNothing(WidgetTester tester) async {
  World.backend.theImportAnswers = const Imported(
    outcome: 'NOTHING_TO_IMPORT',
    name: '',
    type: '',
    length: 0,
    source: '',
    detail: '',
  );
}
