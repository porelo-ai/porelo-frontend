import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/developer_settings.dart';

Future<void> iPublishTheReviewedDeveloper(WidgetTester tester) =>
    developerTap(tester, find.byKey(const Key('wizard-start')));
