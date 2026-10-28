import 'dart:convert';
import 'dart:io';

import 'desk.dart';

/// What came of publishing this account's homeserver, or of closing it: said beside the VPN's outcome, never
/// failing it.
class PublishOutcome {
  /// Constructor taking whether it is published now and what to say.
  const PublishOutcome({required this.published, required this.words});

  /// Whether the homeserver is published on the VPN now.
  final bool published;

  /// One sentence for the person.
  final String words;
}

/// Publishes this account's own homeserver on this laptop's VPN address for a rented host's tasks during the move,
/// under the name the signed project file gives it, and closes it again once the host is given back.
///
/// Only where this account's homeserver was set up (`homeserver.conf` exists): otherwise nothing runs and nothing
/// is said. The laptop's own line for the name is written once by hand; this only says whether it is missing.
class HomeserverPublishing {
  /// Constructor taking where Porelo's configuration lies, the hosts file and how the transport is run; each
  /// injectable so the frame is judged without a homeserver.
  HomeserverPublishing({
    String? configuration,
    this.hostsFile = '/etc/hosts',
    Future<ProcessResult> Function(String executable, List<String> arguments)? run,
  }) : _configuration = configuration ?? desk.configuration,
       _run = run ?? ((executable, arguments) => Process.run(executable, arguments));

  /// The matrix transport, by the path its package installs it to.
  static const transport = '/usr/libexec/porelo/transports/porelo-message-transport-matrix';

  /// The name the signed project file gives the homeserver, which the host resolves to this laptop's peer address.
  static const name = 'matrix.porelo.internal';

  /// The laptop's own line, given to the person as it is to be added once by hand.
  static const laptopLine = '127.0.0.1 $name # porelo-matrix';

  final String _configuration;

  /// The hosts file read for [laptopLineMissing].
  final String hostsFile;
  final Future<ProcessResult> Function(String executable, List<String> arguments) _run;

  File get _conf => File('$_configuration/matrix/homeserver.conf');

  /// The settings of `homeserver.conf`, `KEY=VALUE` per line; null where this account has no homeserver.
  Map<String, String>? _settings() {
    try {
      final conf = _conf;
      if (!conf.existsSync()) return null;
      return {
        for (final line in conf.readAsLinesSync())
          if (line.indexOf('=') case final at when at > 0) line.substring(0, at).trim(): line.substring(at + 1).trim(),
      };
    } on FileSystemException {
      return null;
    }
  }

  /// The peer's address without its prefix, where it is one plain IPv4 address.
  static String? _address(String peer) {
    final address = peer.split('/').first;
    final parts = address.split('.');
    final plain =
        parts.length == 4 &&
        parts.every(
          (part) => switch (int.tryParse(part)) {
            final n? => n >= 0 && n <= 255,
            null => false,
          },
        );
    return plain && RegExp(r'^[0-9.]+$').hasMatch(address) ? address : null;
  }

  /// Publishes the homeserver on [peer], this laptop's VPN address, with its own loopback port, as `--name` asks.
  /// Null where this account has no homeserver.
  Future<PublishOutcome?> publish(String peer) async {
    final settings = _settings();
    if (settings == null) return null;
    final port = int.tryParse(settings['PORELO_MATRIX_PORT'] ?? '');
    final address = _address(peer);
    if (port == null || port < 1024 || port > 65535 || address == null) {
      return const PublishOutcome(
        published: false,
        words:
            'Your homeserver was not published for this server: its port or this computer\'s VPN address could '
            'not be read.',
      );
    }
    final ran = await _ran(['publish', '--address', '$address:$port', '--name', name]);
    if (ran.exitCode != 0) return PublishOutcome(published: false, words: _refused('published for this server', ran));
    return PublishOutcome(
      published: true,
      words: 'Your homeserver is published for this server\'s tasks at https://$name:$port, on $address.',
    );
  }

  /// Closes what [publish] opened on [peer], and only that: an address of another host is left as it is. Null
  /// where nothing of this host's is published.
  Future<PublishOutcome?> unpublish(String peer) async {
    final address = _address(peer);
    final published = _settings()?['PORELO_MATRIX_PUBLISH'];
    if (address == null || published == null || !published.startsWith('$address:')) return null;
    final ran = await _ran(['publish', '--off']);
    if (ran.exitCode != 0) return PublishOutcome(published: true, words: _refused('closed', ran));
    return const PublishOutcome(published: false, words: 'Your homeserver is no longer published on the VPN.');
  }

  /// Whether no line of [hostsFile] gives [name] to `127.0.0.1`, so the person is shown [laptopLine].
  bool get laptopLineMissing {
    try {
      for (final line in File(hostsFile).readAsLinesSync()) {
        final fields = line.split('#').first.trim().split(RegExp(r'\s+'));
        if (fields.length > 1 && fields.first == '127.0.0.1' && fields.skip(1).contains(name)) return false;
      }
    } on FileSystemException {
      return true;
    }
    return true;
  }

  Future<ProcessResult> _ran(List<String> arguments) async {
    try {
      return await _run(transport, arguments);
    } on ProcessException catch (error) {
      return ProcessResult(0, 127, '', error.message);
    }
  }

  /// The transport's last nonempty line on standard error, as Porelo shows a transport's cause; it holds no secret.
  static String _refused(String what, ProcessResult ran) {
    final said = const LineSplitter()
        .convert('${ran.stderr}')
        .map((line) => line.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim())
        .where((line) => line.isNotEmpty)
        .lastOrNull;
    final cause = said == null ? 'it ended with ${ran.exitCode}' : (said.length > 300 ? said.substring(0, 300) : said);
    return 'Your homeserver could not be $what: $cause.';
  }
}
