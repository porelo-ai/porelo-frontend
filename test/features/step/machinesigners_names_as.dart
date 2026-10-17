import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: machine-signers names {'old-box'} as {'porelo@old-box ssh-ed25519 AAAAold'}
Future<void> machinesignersNamesAs(WidgetTester tester, String name, String line) async {
  World.workspace.files['machine-signers'] = '# $name\n$line\n';
}
