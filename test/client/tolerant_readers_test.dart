import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// Readers of a daemon's answer that keep reading past a field of another type.
///
/// The harm: one field of an unexpected type threw out of the whole call, so `default`'s
/// repositories, or what a refresh did, could not be shown at all.
void main() {
  test("a repository of default whose source or remote is not a string is read without them", () {
    final read = DefaultRepository.from(<String, dynamic>{'name': 'app', 'upstream': 'u', 'source': 1, 'remote': true});
    expect(read.name, 'app');
    expect(read.source, isNull);
    expect(read.remote, isNull);
  });

  test('a refresh whose moved branches are not a map is read as having moved none', () {
    final read = TaskRefreshed.from(<String, dynamic>{'outcome': 'MOVED', 'moved': <Object>[]});
    expect(read.outcome, 'MOVED');
    expect(read.moved, isEmpty);
  });
}
