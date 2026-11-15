import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-billing-shell'} has used {184000} tokens in and {2000} out
Future<void> theWorkHasUsedTokensInAndOut(WidgetTester tester, String work, int input, int output) async {
  World.backend.usages[work] = Usage.from(<String, dynamic>{
    'state': 'available',
    'totals': <String, dynamic>{
      'requests': 4,
      'input': <String, dynamic>{'tokens': input, 'missing': 0},
      'cacheRead': <String, dynamic>{'missing': 0},
      'cacheWrite': <String, dynamic>{'missing': 0},
      'output': <String, dynamic>{'tokens': output, 'missing': 0},
      'reasoning': <String, dynamic>{'missing': 0},
    },
  });
}
