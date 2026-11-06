import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

/// Repositories refused for one reason are one line, whatever they are called.
///
/// The harm: a repository whose name is a word of git's message, such as `key`, mangles that
/// message and stands apart from the others refused for the same reason.
void main() {
  test('a repository named like a word of the refusal groups with the others', () {
    String refusal(String name) =>
        'git clone git@github.com:example/$name.git failed: Host key verification failed. ($name)';

    expect(unreadReason('key', refusal('key')), unreadReason('library', refusal('library')));
    expect(unreadReason('key', refusal('key')), contains('Host key verification failed.'));
  });
}
