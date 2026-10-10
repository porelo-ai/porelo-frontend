import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/src/app/operations.dart';
import 'package:sokar_frontend/src/app/settings.dart';

/// Where the interface keeps what it keeps, when the XDG variables are set but empty or end in a slash.
void main() {
  const empty = <String, String>{'HOME': '/home/somebody', 'XDG_CONFIG_HOME': '', 'XDG_STATE_HOME': ''};

  test('an empty XDG directory is unset, as the specification says, never the root', () {
    expect(FileSettingsStore.defaultFile(empty, 'linux').path, '/home/somebody/.config/sokar/frontend.json');
    expect(FileOperationsStore.defaultFile(empty, 'linux').path, '/home/somebody/.local/state/sokar/operations.json');
  });

  test('a directory given with a trailing slash names the same file', () {
    const slashed = <String, String>{'HOME': '/home/somebody/', 'XDG_STATE_HOME': '/state/'};

    expect(FileSettingsStore.defaultFile(slashed, 'linux').path, '/home/somebody/.config/sokar/frontend.json');
    expect(FileOperationsStore.defaultFile(slashed, 'linux').path, '/state/sokar/operations.json');
  });
}
