// The second app of the Windows trial: packed and installed by the same scripts as the window, to
// prove they serve another app. It writes one file where an app writes its own, says so, and stays up
// long enough to be found running, then ends by itself.
import 'dart:io';

Future<void> main() async {
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null) {
    stderr.writeln('no LOCALAPPDATA to write into');
    exitCode = 1;
    return;
  }
  final folder = Directory('$local\\porelo-windows-trial')..createSync(recursive: true);
  File('${folder.path}\\started.txt').writeAsStringSync('$pid\n');
  stdout.writeln('started as $pid');
  await Future<void>.delayed(const Duration(minutes: 2));
}
