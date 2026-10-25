import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  // Harm: different state paths let commands bypass the same project's lock.
  test('project locks share the host state directory and ignore relative XDG paths', () {
    for (final state in [null, '', 'relative', '/state']) {
      final environment = {'HOME': '/home/person', 'XDG_STATE_HOME': ?state};
      final directory = state == '/state' ? '/state/porelo-host' : '/home/person/.local/state/porelo-host';
      expect(
        poreloHostProjectLock('demo', environment: environment, windows: false),
        '$directory/demo.lock',
        reason: 'a lock must have one authoritative absolute location for XDG_STATE_HOME=$state',
      );
      expect(
        poreloHostKnownHosts(environment: environment, windows: false),
        '$directory/known_hosts',
        reason: 'host keys and project locks must share the state directory',
      );
    }
  });

  // Harm: Windows commands bypass one another by locking outside their shared state directory.
  test('Windows project locks use the local application state directory', () {
    const environment = {'LOCALAPPDATA': r'C:\Users\person\AppData\Local', 'XDG_STATE_HOME': '/ignored'};
    expect(
      poreloHostProjectLock('demo', environment: environment, windows: true),
      r'C:\Users\person\AppData\Local\porelo-host\demo.lock',
      reason: 'Windows lock identity follows LOCALAPPDATA',
    );
  });
}
