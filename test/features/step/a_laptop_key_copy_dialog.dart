import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/project_join_dialog.dart';

import '../../support/host_admin.dart';
import '../support/world.dart';

final laptopCopiedKeys = <String>[];
late MemorySecrets laptopCopyStore;

Future<void> aLaptopKeyCopyDialog(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  laptopCopyStore = MemorySecrets();
  laptopCopiedKeys.clear();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openCopyJoinKeysDialog(
              context,
              store: laptopCopyStore,
              copy: (value) async => laptopCopiedKeys.add(value),
            ),
            child: const Text('Copy keys'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Copy keys'));
  await World.settle(tester);
}
