import 'package:file_selector/file_selector.dart';

/// Asks the desktop for a file of this computer, starting in [initialDirectory]; null when the
/// person put the dialog away. **A path, never the content**: what is in the file is read only at
/// the moment it is sent, and only by whoever sends it.
typedef PickAFile = Future<String?> Function({String? initialDirectory, String? title});

/// The desktop's own file dialog.
Future<String?> pickWithTheDesktop({String? initialDirectory, String? title}) async =>
    (await openFile(initialDirectory: initialDirectory, confirmButtonText: title))?.path;

/// Asks the desktop for a folder; null when the person puts the dialog away.
typedef PickAFolder = Future<String?> Function({String? initialDirectory, String? title});

/// The desktop's own folder dialog.
Future<String?> pickFolderWithTheDesktop({String? initialDirectory, String? title}) =>
    getDirectoryPath(initialDirectory: initialDirectory, confirmButtonText: title);

/// Asks the desktop where a new file goes; null when the person put the dialog away. A path, never content.
typedef ChooseNewFile = Future<String?> Function({String? title});

/// The desktop's own save dialog.
Future<String?> chooseWithTheDesktop({String? title}) async => (await getSaveLocation(confirmButtonText: title))?.path;
