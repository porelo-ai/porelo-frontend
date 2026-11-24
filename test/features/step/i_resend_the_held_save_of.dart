import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';

/// Usage: I resend the held save of {'cart-move'}
Future<void> iResendTheHeldSaveOf(WidgetTester tester, String story) => tapHeldSave(tester, 'resend', story);
