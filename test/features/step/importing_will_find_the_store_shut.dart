import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: importing will find the store shut
Future<void> importingWillFindTheStoreShut(WidgetTester tester) async {
  World.backend.theImportAnswers = const Imported(
    outcome: 'VAULT_LOCKED',
    name: '',
    type: '',
    length: 0,
    source: '',
    detail: '',
  );
}
