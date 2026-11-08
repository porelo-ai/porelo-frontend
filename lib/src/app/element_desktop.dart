import 'dart:convert';
import 'dart:io';

import 'desk.dart';

/// Element, the Matrix client, as installed on this computer. Injectable, so a test stands in for it.
abstract interface class ElementDesktop {
  /// Whether Element's desktop app is installed here.
  Future<bool> installed();

  /// Starts Element with [homeserver] set and its SSO sign-in first; with [profile], as an instance of its own
  /// beside any Element already open. Throws a [FileSystemException] or [ProcessException] where it cannot.
  Future<void> open({required String homeserver, String? profile});
}

/// Writes [text] to the file at [path].
typedef WriteText = Future<void> Function(String path, String text);

/// Element's desktop app where its installers put it: on PATH, as a Flatpak or a Snap on Linux, under the user's
/// programs on Windows, in Applications on macOS.
///
/// **The homeserver is set by a config file of its own**, named with `--config`, which Element reads over its
/// bundled one: an `element://` address alone reaches only an Element already running, and a fresh profile
/// would start at its welcome page with its default server. The address is given too, for an Element already
/// open, and carries the homeserver as `hs_url`.
class InstalledElement implements ElementDesktop {
  /// Constructor taking where it looks, and for a test how a file is found, written and Element started.
  InstalledElement({
    required this.operatingSystem,
    required this.environment,
    required this.configFolder,
    bool Function(String path)? exists,
    WriteText? write,
    StartDetached? startDetached,
  }) : _exists = exists ?? ((path) => File(path).existsSync()),
       _write = write ?? writeWhole,
       _start = startDetached ?? desk.startDetached;

  /// The system, as `Platform.operatingSystem` names it.
  final String operatingSystem;

  /// Where PATH and the home folders are read from.
  final Map<String, String> environment;

  /// Where the window keeps the config files it hands Element, one per host.
  final String configFolder;

  final bool Function(String path) _exists;
  final WriteText _write;
  final StartDetached _start;

  bool get _windows => operatingSystem == 'windows';

  /// Where Element's program may be, in the order it is looked for.
  List<String> get candidates {
    final home = environment['HOME'] ?? '';
    return switch (operatingSystem) {
      'windows' => <String>[if (environment['LOCALAPPDATA'] case final local?) '$local\\element-desktop\\Element.exe'],
      'macos' => <String>[
        '/Applications/Element.app/Contents/MacOS/Element',
        if (home.isNotEmpty) '$home/Applications/Element.app/Contents/MacOS/Element',
      ],
      _ => <String>[
        for (final folder in (environment['PATH'] ?? '').split(':'))
          if (folder.isNotEmpty) '$folder/element-desktop',
        '/var/lib/flatpak/exports/bin/im.riot.Riot',
        if (home.isNotEmpty) '$home/.local/share/flatpak/exports/bin/im.riot.Riot',
        '/snap/bin/element-desktop',
      ],
    };
  }

  String? get _program => candidates.where(_exists).firstOrNull;

  @override
  Future<bool> installed() async => _program != null;

  @override
  Future<void> open({required String homeserver, String? profile}) async {
    final program = _program;
    if (program == null) return;
    final config = '$configFolder${_windows ? r'\' : '/'}${profile ?? 'default'}.json';
    await _write(config, elementConfig(homeserver));
    await _start(program, <String>[
      if (profile != null) ...<String>['--profile', profile],
      '--config',
      config,
      elementLoginAddress(homeserver),
    ]);
  }
}

/// The config Element reads over its bundled one: [homeserver] as its server, and its SSO sign-in offered at once.
String elementConfig(String homeserver) => const JsonEncoder.withIndent('  ').convert(<String, Object?>{
  'default_server_config': <String, Object?>{
    'm.homeserver': <String, Object?>{'base_url': homeserver},
  },
  'sso_redirect_options': <String, Object?>{'on_welcome_page': true},
});

/// The address that opens Element's sign-in with [homeserver] named, for an Element already running.
String elementLoginAddress(String homeserver) =>
    'element://vector/webapp/?hs_url=${Uri.encodeQueryComponent(homeserver)}#/login';

/// This computer's Element, looked for where its installers put it.
ElementDesktop elementDesktop = InstalledElement(
  operatingSystem: Platform.operatingSystem,
  environment: Platform.environment,
  configFolder: desk.join(<String>[desk.data, 'element']),
);

/// Writes [text] to [path] whole or not at all: to a file beside it first, then renamed over it, so Element never
/// reads one cut off half written.
Future<void> writeWhole(String path, String text) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final beside = File('$path.${DateTime.now().microsecondsSinceEpoch}.part');
  try {
    await beside.writeAsString(text, flush: true);
    await beside.rename(path);
  } on FileSystemException {
    if (beside.existsSync()) await beside.delete();
    rethrow;
  }
}
