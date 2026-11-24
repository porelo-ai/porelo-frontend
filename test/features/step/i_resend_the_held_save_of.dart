import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';

/// Usage: I resend the held save of {'ST293'}
Future<void> iResendTheHeldSaveOf(WidgetTester tester, String story) => tapHeldSave(tester, 'resend', story);
