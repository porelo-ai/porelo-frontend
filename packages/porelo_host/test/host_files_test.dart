// Linux only: private bundle publication invokes chmod and checks symbolic links.
@Tags(['linux'])
library;


import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

const signingKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture';
const fingerprint = 'SHA256:ZkAslGjFiUHdGf/WUL8rQvkib4PTvQatUV0OUQSncCA';
void main() {
  // Harm: trusting a different signing key lets the host accept the wrong commits.
  test('signing fingerprint matches the fixed ssh-keygen output', () {
    expect(HostFiles.signingFingerprint(signingKey), fingerprint);
    expect(() => HostFiles.signingFingerprint('ssh-ed25519 malformed'), throwsA(isA<HostFilesRefused>()));
  });
  // Harm: a path-like project can escape its private bundle directory.
}
