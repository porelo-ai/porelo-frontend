import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'host_run_test.dart' show ScriptedRemote;

const sshKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
final wireGuardKey = base64Encode(List.filled(32, 1));
Map<String, Object?> hostValues() => {
  'address': '203.0.113.7',
  'endpoint': '203.0.113.7:51820',
  'wireguard_public_key': wireGuardKey,
  'network': '10.73.7.0/24',
  'ssh_host_key': sshKey,
  'ca_sha256': 'a' * 64,
  'homeserver': 'matrix.orchard.porelo.internal',
};

/// Reuses the remote recorder with responses driven by each test.
class HelperRemote extends ScriptedRemote {
  HelperRemote({this.response = '', this.code = 0, this.errors = ''}) : super([]);
  final String response;
  final int code;
  final String errors;
  final hosts = <String>[];
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    hosts.add(host);
    await super.run(host, user, command, input: input, onLine: onLine);
    if (response.isNotEmpty) onLine?.call(response);
    return RemoteResult(code, errors);
  }
}

void main() {
  // Harm: a malformed service endpoint or host key redirects trust before publication.
  test('SSH completion round trips its checked public fields and rejects malformed endpoints', () {
    final json = <String, Object?>{
      'name': 'orchard',
      'address': '203.0.113.7',
      'ssh_port': 22,
      'host_key': sshKey,
      'services': {
        'forge': {'web_port': 3000, 'git_port': 3001},
        'matrix': {'port': 8448},
      },
    };
    final host = PreparedHost.read(json);
    expect(host.sshOnly, isTrue);
    expect(host.stored, json);
    expect(Step.fromLine(Step('host', StepState.host, host: host).toLine())!.host!.stored, json);
    for (final patch in <Map<String, Object?>>[
      {'ssh_port': '22'},
      {'ssh_port': 0},
      {'host_key': '$sshKey comment'},
      {'name': '../elsewhere'},
      {
        'services': {
          'forge': {'web_port': 3000, 'git_port': 3000},
          'matrix': {'port': 8448},
        },
      },
      {
        'services': {
          'forge': {'web_port': 3000},
          'matrix': {'port': 8448},
        },
      },
    ]) {
      expect(() => PreparedHost.read({...json, ...patch}), throwsFormatException);
    }
  });

  // Harm: malformed metadata can redirect admin access or trust.
  group('host completion', () {
    // Harm: pasted spacing blocks a valid host, while malformed trust metadata must still be refused.
    for (final (field, pasted) in [
      ('ssh_host_key', '  ${sshKey.replaceFirst(' ', '  \t ')}  '),
      ('wireguard_public_key', ' \t$wireGuardKey  '),
    ]) {
      test('normalizes pasted $field blanks without changing other public values', () {
        final host = PreparedHost.read({...hostValues(), field: pasted});
        expect(host.values, hostValues());
      });
    }
    test('a malformed CA digest names its required form', () {
      expect(
        () => PreparedHost.read({...hostValues(), 'ca_sha256': 'wrong'}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'required digest form',
            allOf(contains('ca_sha256'), contains('64'), contains('lowercase hexadecimal')),
          ),
        ),
      );
    });
    for (final field in hostValues().keys) {
      for (final value in [null, 42, '', 'malformed']) {
        test('refuses $field when it is $value by name', () {
          final json = hostValues();
          if (value == null) {
            json.remove(field);
          } else {
            json[field] = value;
          }
          expect(
            () => PreparedHost.read(json),
            throwsA(isA<FormatException>().having((e) => e.message, 'field', contains(field))),
          );
        });
      }
    }
    test('ignores unknown fields and computes the SSH fingerprint', () {
      final host = PreparedHost.read({...hostValues(), 'future': true});
      expect(host.values, hostValues());
      expect(host.fingerprint, 'SHA256:kmYcvdi2GkPeWxB6XLjrZB8JHsy2Hm8luHMFp9GMvqk');
    });
    for (final (field, bad) in [
      ('address', '127.0.0.1'),
      ('address', '10.0.0.1'),
      ('address', '300.0.0.1'),
      ('endpoint', '203.0.113.8:51820'),
      ('endpoint', '203.0.113.7:22'),
      ('network', '10.73.256.0/24'),
      ('network', '10.73.7.1/24'),
      ('ssh_host_key', '$sshKey\ncomment'),
      ('ssh_host_key', 'ssh-ed25519 AAAA'),
      ('ssh_host_key', '$sshKey comment'),
      ('wireguard_public_key', '${'A' * 42}B='),
      ('ca_sha256', 'A' * 64),
      ('homeserver', 'matrix.-bad.porelo.internal'),
    ]) {
      test(
        'refuses malformed $field: $bad',
        () => expect(
          () => PreparedHost.read({...hostValues(), field: bad}),
          throwsA(isA<FormatException>().having((e) => e.message, 'field', contains(field))),
        ),
      );
    }
  });

  // Harm: remote shell injection or keys disclosed through process arguments.
  group('host helper calls', () {
    test('quotes the project signing key as one remote word', () async {
      final request = HostAdminRequest.register('orchard', 'alice', sshKey);
      expect(request.command, "/usr/local/sbin/porelo-host-project add orchard alice --signed-by '$sshKey'");
      expect(request.input, isNull);
      final remote = HelperRemote(
        response:
            '{"project":"orchard","admin":"alice","organization":"orchard","publisher":"porelo-publisher-orchard"}',
      );
      expect(
        await request.run(remote, PreparedHost.read(hostValues())),
        contains('Publisher: porelo-publisher-orchard.'),
      );
    });
    for (final bad in ['--help', 'alice;id', 'alice\nroot', "alice'", 'a/b', r'$(id)']) {
      test('rejects unsafe helper arguments before running: ${jsonEncode(bad)}', () {
        expect(() => HostAdminRequest.register(bad, 'alice', sshKey), throwsFormatException);
        expect(() => HostAdminRequest.register('orchard', bad, sshKey), throwsFormatException);
        expect(() => HostAdminRequest.remove('person', 'purge', bad), throwsFormatException);
      });
    }
    for (final (helper, action, flag) in [
      ('person', 'lock', 'locked'),
      ('person', 'purge', 'purged'),
      ('project', 'remove', 'removed'),
    ]) {
      test('checks $action confirmation rather than assuming success', () async {
        final request = HostAdminRequest.remove(helper, action, 'orchard');
        expect(request.command, '/usr/local/sbin/porelo-host-$helper $action orchard');
        await expectLater(
          request.run(HelperRemote(response: '{"$helper":"orchard","$flag":false}'), PreparedHost.read(hostValues())),
          throwsFormatException,
        );
        expect(
          await request.run(
            HelperRemote(response: '{"$helper":"orchard","$flag":true}'),
            PreparedHost.read(hostValues()),
          ),
          contains('orchard'),
        );
      });
    }
    for (final code in [64, 65, 69, 73]) {
      test('keeps the refusal stderr verbatim for exit $code', () async {
        const refusal = 'porelo-host-project: unpushed work remains.\n';
        await expectLater(
          HostAdminRequest.remove(
            'project',
            'remove',
            'orchard',
          ).run(HelperRemote(code: code, errors: refusal), PreparedHost.read(hostValues())),
          throwsA(isA<HostAdminRefused>().having((e) => e.words, 'verbatim stderr', refusal)),
        );
      });
    }
    for (final response in [
      '',
      '{}',
      '[]',
      '{"person":"other","locked":true}',
      '{"person":"orchard","locked":"true"}',
    ]) {
      test('refuses an unconfirmed helper success: $response', () async {
        await expectLater(
          HostAdminRequest.remove(
            'person',
            'lock',
            'orchard',
          ).run(HelperRemote(response: response), PreparedHost.read(hostValues())),
          throwsFormatException,
        );
      });
    }
  });
}
