// Unpacks the licenses of the third-party code built into the window for its .deb and .rpm.
//
// Usage: dart tool/third_party_notices.dart <NOTICES.Z> <LICENSE> <out-dir>
//
// Writes <out-dir>/THIRD-PARTY-NOTICES, the plain text of what the window's *View licenses* shows, and
// <out-dir>/copyright, the deb's copyright: the window's own LICENSE, after a line naming where the notices are.
import 'dart:convert';
import 'dart:io';

/// Where the deb puts the notices, named by its copyright.
const debNotices = '/usr/share/doc/porelo-frontend/THIRD-PARTY-NOTICES';

/// The plain text of Flutter's NOTICES.Z, which `flutter build` writes gzip-compressed into the bundle's assets.
///
/// Refused where it is not gzip, not UTF-8, or empty: a package is never built with notices nobody can read.
String thirdPartyNotices(List<int> compressed) {
  final List<int> unpacked;
  try {
    unpacked = gzip.decode(compressed);
  } on FormatException catch (error) {
    throw FormatException('NOTICES.Z is not gzip: ${error.message}');
  }
  final text = utf8.decode(unpacked);
  if (text.trim().isEmpty) throw const FormatException('NOTICES.Z holds no notices');
  return text;
}

/// The deb's copyright: the window's own [license], after the line that names where the third-party notices are.
String debCopyright(String license) =>
    'porelo-frontend is licensed as below. The licenses of the third-party code built into it are in\n'
    '$debNotices\n\n$license';

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln('usage: dart tool/third_party_notices.dart <NOTICES.Z> <LICENSE> <out-dir>');
    exit(2);
  }
  final String notices;
  try {
    notices = thirdPartyNotices(File(args[0]).readAsBytesSync());
  } on Exception catch (error) {
    stderr.writeln('${args[0]}: $error');
    exit(1);
  }
  final out = Directory(args[2])..createSync(recursive: true);
  File('${out.path}/THIRD-PARTY-NOTICES').writeAsStringSync(notices);
  File('${out.path}/copyright').writeAsStringSync(debCopyright(File(args[1]).readAsStringSync()));
}
