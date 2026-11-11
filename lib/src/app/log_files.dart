import 'dart:io';

import 'package:path/path.dart' as p;

import 'desk.dart';
import 'window_log.dart';

/// What the planner's link says where the planner names no log yet.
const plannerNamesNoLog = 'The planner names no log yet.';

/// Opens [what], the log at [path], with the desktop's opener, and answers what to tell the person: a log not there
/// yet, or none named, is said instead of calling the opener, and an opener that fails is said in its own words. Only a
/// file of its own directly in the shared logs folder is opened, never a link: the planner's path is read from its
/// address file, and the opener runs or opens whatever lies at a path it is given.
Future<String> openTheLog(String what, String? path) async {
  if (path == null) return plannerNamesNoLog;
  final folder = windowLogFolder(desk);
  final paths = desk.isWindows ? p.windows : p.posix;
  if (paths.split(path).contains('..') || !paths.equals(paths.dirname(path), folder)) {
    return '${_capitalized(what)} is refused: $path is not a file in $folder.';
  }
  // Asked synchronously: a log is one file on this computer, and the answer is wanted before anything is started.
  switch (FileSystemEntity.typeSync(path, followLinks: false)) {
    case FileSystemEntityType.notFound:
      return '${_capitalized(what)} is not there yet: $path';
    case FileSystemEntityType.file:
      break;
    default:
      return '${_capitalized(what)} is refused: $path is not a file of its own in $folder.';
  }
  final failure = await desk.openFile(path);
  if (failure != null) return '$path could not be opened: $failure';
  return 'Opened $path.';
}

String _capitalized(String words) => words.isEmpty ? words : '${words[0].toUpperCase()}${words.substring(1)}';
