import 'dart:async';
import 'dart:io';

import 'host_file_writer.dart';

/// Runs [action] with an empty ssh configuration in a private temporary folder of its own, both removed after.
///
/// Passed to `-F`, it keeps the person's own configuration out on every system: Windows has no `/dev/null`. The
/// action may put other files of its call beside it, in [File.parent].
Future<T> withEmptySshConfig<T>(Future<T> Function(File config) action, {required String prefix}) async {
  final folder = await HostFileWriter().createPrivateTemporary(Directory.systemTemp, prefix: prefix);
  try {
    final config = File('${folder.path}${Platform.pathSeparator}config');
    await config.writeAsString('');
    return await action(config);
  } finally {
    await folder.delete(recursive: true).catchError((Object _) => folder);
  }
}
