import 'dart:io';

import 'host_file_name.dart';
import 'ssh_public_key.dart';

export 'host_file_name.dart' show HostFilesRefused;

/// Checks of what names a host's files and what signs for it.
class HostFiles {
  /// Rejects traversal and option-like names on both supported desktops.
  static void checkName(String name) => checkHostFileName(name);

  /// Matches ssh-keygen's SHA-256 fingerprint after parsing the complete supported key.
  static String signingFingerprint(String publicKey) {
    try {
      return sshSigningFingerprint(publicKey);
    } on FormatException catch (error) {
      throw HostFilesRefused(error.message);
    }
  }

  /// Refuses Windows devices, alternate streams and ambiguous trailing characters.
  static void checkBasename(String name, {bool? windows}) {
    checkName(name);
    if (!(windows ?? Platform.isWindows)) return;
    final stem = name.split('.').first.trimRight().toUpperCase();
    if (name.contains(':') ||
        name.endsWith('.') ||
        name.endsWith(' ') ||
        RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(stem)) {
      throw const HostFilesRefused(
        'A key file name must not name a Windows device or stream, or end with a dot or space.',
      );
    }
  }

  /// The project bundle's fixed name in an own-account setup directory.
  static const projectBundleFileName = 'project.bundle';

  /// The access repository bundle's fixed name beside an own-account machine file.
  static const accessBundleFileName = 'access.bundle';

  /// Validates central migration URLs and derives their unique Forgejo names.
  ///
  /// Refusals name the field rather than repeating a URL that may contain a credential.
  static List<({String name, String url})> migrationRepositories(List<String> urls) {
    if (urls.isEmpty) throw const HostFilesRefused('forge.repositories must not be empty for a bring.');
    final names = <String>{};
    final repositories = <({String name, String url})>[];
    for (var index = 0; index < urls.length; index++) {
      final url = urls[index];
      final uri = Uri.tryParse(url);
      final segment = uri == null || uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final name = segment.endsWith('.git') ? segment.substring(0, segment.length - 4) : segment;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.authority.contains('@') ||
          RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(url) ||
          !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name) ||
          name == '.' ||
          name == '..' ||
          uri.path.split('/').last != segment) {
        throw HostFilesRefused(
          'forge.repositories[$index].url must be a central HTTPS URL with a plain repository name, no user, query or fragment.',
        );
      }
      if (!names.add(name)) throw HostFilesRefused('forge.repositories[$index].name duplicates another repository.');
      repositories.add((name: name, url: url));
    }
    return repositories;
  }
}
