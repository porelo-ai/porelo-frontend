import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';

/// Usage: I drop the held save of {'cart-move'}
Future<void> iDropTheHeldSaveOf(WidgetTester tester, String story) => tapHeldSave(tester, 'drop', story);
