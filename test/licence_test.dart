import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The license is the rest of Porelo's, and the package says the same as the file.
void main() {
  test('the license text is the GPL 3', () {
    final text = File('LICENSE').readAsStringSync();
    expect(text, contains('GNU GENERAL PUBLIC LICENSE'));
    expect(text, contains('Version 3, 29 June 2007'));
  });

  test('the package declares the license the file holds, and carries the text', () {
    final package = File('packaging/nfpm.yaml.in').readAsStringSync();
    expect(package, contains('license: GPL-3.0-only'));
    expect(package, contains('dst: /usr/share/doc/porelo-frontend/copyright'));
    expect(package, contains('dst: /usr/share/licenses/porelo-frontend/LICENSE'));
  });
}
