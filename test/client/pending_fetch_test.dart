import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// The fetch a waiting push carries, and the host this computer reaches the machine by put in it.
void main() {
  const named = 'git fetch ssh://porelo@build-01/srv/repo.git refs/porelo/incoming/x:refs/remotes/porelo/x';

  test('the fetch is read from the reply, and empty from a machine that names none', () {
    expect(PendingPush.from(<String, dynamic>{'name': 'x', 'fetch': named}).fetch, named);
    expect(PendingPush.from(<String, dynamic>{'name': 'x'}).fetch, '');
  });

  test('the host is the one this computer reaches the machine by', () {
    const push = PendingPush(name: 'x', commit: '', subject: '', waiting: '', at: '', fetch: named);
    expect(
      push.fetchFrom('me@192.0.2.10'),
      'git fetch ssh://me@192.0.2.10/srv/repo.git refs/porelo/incoming/x:refs/remotes/porelo/x',
    );
    expect(push.fetchFrom(null), named, reason: 'reached otherwise, it is as the machine named it');
    expect(push.inRepository('repo').fetch, named, reason: 'kept when the repository is added');
  });

  // The harm: the copied command cannot reach a Host alias without this window's config.
  test('a fetch through the window config names that config and its Host alias', () {
    const push = PendingPush(name: 'x', commit: '', subject: '', waiting: '', at: '', fetch: named);
    expect(
      push.fetchFrom('review-host', sshConfig: '/tmp/porelo/config'),
      "GIT_SSH_COMMAND='ssh -F /tmp/porelo/config' "
      'git fetch ssh://review-host/srv/repo.git refs/porelo/incoming/x:refs/remotes/porelo/x',
    );
    expect(
      push.fetchFrom('review-host'),
      'git fetch ssh://review-host/srv/repo.git refs/porelo/incoming/x:refs/remotes/porelo/x',
    );
    expect(push.fetchFrom(null, sshConfig: '/tmp/porelo/config'), named);
  });

  // The harm: a config path becomes shell syntax at either of the two shell parses.
  test('a config path is quoted for both the assignment and the ssh command', () async {
    const push = PendingPush(name: 'x', commit: '', subject: '', waiting: '', at: '', fetch: named);
    const config = r"/tmp/reviewer's configs/$literal;config";
    final line = push.fetchFrom('review-host', sshConfig: config);
    final result = await Process.run('/bin/sh', [
      '-c',
      'git() { eval "set -- \$GIT_SSH_COMMAND"; printf "%s\\n" "\$@"; }; $line',
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout, 'ssh\n-F\n$config\n');
  }, skip: Platform.isWindows ? 'POSIX shell quoting is used only on POSIX desktops' : false);
}
