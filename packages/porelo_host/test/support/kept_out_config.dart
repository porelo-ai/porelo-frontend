import 'dart:io';

/// The ssh configuration an ssh command line names with `-F`, as read while that ssh runs.
///
/// The person's own configuration is kept out by an empty file of the command's own, never by `/dev/null`, which
/// Windows has no: a test reads it at the start of ssh, where it must be empty, and checks after the run that it is
/// gone. [text] is null where the line names no `-F` file, or the file does not exist.
final class KeptOutConfig {
  KeptOutConfig._(this.path, this.text);

  /// Reads the `-F` file [arguments] name, at the moment ssh would start.
  static Future<KeptOutConfig> read(List<String> arguments) async {
    final at = arguments.indexOf('-F');
    if (at < 0 || at + 1 >= arguments.length) return KeptOutConfig._('', null);
    final file = File(arguments[at + 1]);
    return KeptOutConfig._(file.path, await file.exists() ? await file.readAsString() : null);
  }

  /// The file named after `-F`; empty where none is named.
  final String path;

  /// What the file held while ssh ran.
  final String? text;

  /// Whether the configuration kept the person's own out: an empty file of its own, not `/dev/null`.
  bool get keptOut => text == '' && path != '/dev/null';

  /// Whether the file, and the private folder it lay in, are gone, as they must be once the run ended.
  Future<bool> gone() async => path.isNotEmpty && !await File(path).parent.exists();
}
