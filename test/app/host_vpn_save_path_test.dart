import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_vpn.dart';

void main() {
  // Harm: refusing every Windows path left the VPN connection unsavable there.
  test('a plain absolute Windows path is accepted for saving the VPN connection on Windows', () {
    expect(
      () => checkVpnSaveFile(r'C:\Users\person\AppData\Local\Temp\vpn/porelo.conf', windows: true),
      returnsNormally,
    );
  });

  for (final path in ['relative.conf', r'C:relative.conf', 'C:\\a\nb.conf', 'C:\\a\x00b.conf', 'C:\\a"b.conf']) {
    // Harm: a relative or broken path saves the private key somewhere the person did not choose.
    test('the Windows save path ${path.codeUnits} is refused', () {
      expect(() => checkVpnSaveFile(path, windows: true), throwsFormatException);
    });
  }

  // Harm: off Windows the saved path later reaches a command run as root, so the strict check still holds.
  test('off Windows a saved path is held to the root command check', () {
    expect(() => checkVpnSaveFile(r'C:\Users\person\porelo.conf', windows: false), throwsFormatException);
    expect(() => checkVpnSaveFile('/home/person/porelo.conf', windows: false), returnsNormally);
  });
}
