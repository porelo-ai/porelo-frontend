import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: starting it again will fail with exit code {70} saying {'Several agents are installed'}
Future<void> startingItAgainWillFailWithExitCodeSaying(WidgetTester tester, int code, String words) async {
  World.backend.nextStart = StartProgress(
    exitCode: code,
    output: <String>['task           porelo-checkout-shell', 'porelo: $words'],
  );
}
