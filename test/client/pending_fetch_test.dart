import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/client.dart';

/// The fetch a waiting push carries, and the host this computer reaches the machine by put in it.
void main() {
  const named = 'git fetch ssh://sokar@build-01/srv/repo.git refs/sokar/incoming/x:refs/remotes/sokar/x';

  test('the fetch is read from the reply, and empty from a machine that names none', () {
    expect(PendingPush.from(<String, dynamic>{'name': 'x', 'fetch': named}).fetch, named);
    expect(PendingPush.from(<String, dynamic>{'name': 'x'}).fetch, '');
  });

  test('the host is the one this computer reaches the machine by', () {
    const push = PendingPush(name: 'x', commit: '', subject: '', waiting: '', at: '', fetch: named);
    expect(push.fetchFrom('me@192.0.2.10'),
        'git fetch ssh://me@192.0.2.10/srv/repo.git refs/sokar/incoming/x:refs/remotes/sokar/x');
    expect(push.fetchFrom(null), named, reason: 'reached otherwise, it is as the machine named it');
    expect(push.inRepository('repo').fetch, named, reason: 'kept when the repository is added');
  });
}
