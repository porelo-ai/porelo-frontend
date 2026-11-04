import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-billing-shell'} has used {184000} tokens
Future<void> theWorkHasUsedTokens(WidgetTester tester, String work, int tokens) async {
  World.backend.usages[work] = Usage.from(<String, dynamic>{
    'state': 'available',
    'totals': <String, dynamic>{
      'input': <String, dynamic>{'tokens': tokens, 'missing': 0},
    },
  });
}
