import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';

void main() {
  // Harm: malformed person identifiers must not reach a project mutation or host command.
  test('a person entry rejects unsafe logins and missing key fingerprints', () {
    for (final login in ['root; command', '-option', 'a/b']) {
      expect(
        () => AccessDeveloper(login: login, role: 'developer', fingerprint: 'SHA256:${'A' * 43}'),
        throwsFormatException,
      );
    }
    expect(() => AccessDeveloper(login: 'worker', role: 'developer', fingerprint: ''), throwsFormatException);
  });
}
