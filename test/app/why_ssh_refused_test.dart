import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

/// A refused login says what to change, from ssh's own words.
void main() {
  test('an agent cut off before its right key is told to name the key for the host', () {
    expect(whySshRefused('Received disconnect from 192.0.2.10 port 22:2: Too many authentication failures', 'somebody@vm'),
        allOf(contains('IdentitiesOnly yes'), contains('somebody@vm')));
  });

  test('no key accepted is said as the account lacking the key, or the account', () {
    expect(whySshRefused('somebody@vm: Permission denied (publickey).', 'somebody@vm'), contains('authorized_keys'));
  });

  test('words that tell nothing say nothing', () {
    expect(whySshRefused('', 'somebody@vm'), isNull);
  });
}
