import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';

/// Usage: I open the held save of {'cart-move'}
Future<void> iOpenTheHeldSaveOf(WidgetTester tester, String story) => openHeldSave(tester, story);
