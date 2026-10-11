import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/src/app/machine_binding.dart';

/// A machine's line is found in machine-signers by its key, and goes with the comment naming it.
void main() {
  const line = 'sokar@vm ssh-ed25519 AAAAmachine';
  const file = 'alice ssh-ed25519 AAAAperson\n# vm\nsokar@vm namespaces="git" ssh-ed25519 AAAAmachine\n';

  test('the line goes by its key, with options a person added, and the comment above it', () {
    expect(withoutSigner(file, line, 'vm'), 'alice ssh-ed25519 AAAAperson\n');
  });

  test('a file without the key is left alone', () {
    expect(withoutSigner('alice ssh-ed25519 AAAAperson\n', line, 'vm'), isNull);
  });
}
