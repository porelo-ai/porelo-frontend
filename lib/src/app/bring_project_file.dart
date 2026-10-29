import 'package:porelo_host/porelo_host.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'access_checkout.dart';
import 'run_here.dart';

/// The bring inputs read only from the project's verified signed revision.
class BringProjectFile {
  BringProjectFile._(this.access, this.repositories, this.keys);

  /// Checks the followed source before it can become a Git argument.
  static void checkSource(String source) {
    const refused = WorkspaceRefused(
      'The followed project source needs a credential-free HTTPS or git SSH repository, or an absolute local bundle path.',
    );
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(source)) throw refused;
    if (path.isAbsolute(source)) return;
    final uri = Uri.tryParse(source);
    if (uri != null &&
        uri.scheme == 'file' &&
        uri.host.isEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        path.posix.isAbsolute(uri.path)) {
      return;
    }
    try {
      AccessCheckout.checkRepository(source);
    } on WorkspaceRefused {
      throw refused;
    }
  }

  /// Validates every repository and credential name before any access edit or upload.
  factory BringProjectFile.read(String text) {
    Object? document;
    try {
      document = loadYaml(text);
    } on Exception {
      throw const WorkspaceRefused('The verified project.yml is not valid YAML.');
    }
    if (document is! Map) throw const WorkspaceRefused('The verified project.yml needs a mapping.');
    final access = document['access'];
    if (access is! Map || access['repository'] is! String) {
      throw const WorkspaceRefused('access.repository must name the private access checkout.');
    }
    AccessCheckout.checkRepository(access['repository'] as String);
    final repositories = document['repositories'];
    if (repositories is! Map || repositories.isEmpty) {
      throw const WorkspaceRefused('forge.repositories needs the signed project.yml repositories.');
    }
    final urls = <String>[];
    for (final value in repositories.values) {
      if (value is! Map || value['upstream'] is! String) {
        throw WorkspaceRefused('forge.repositories[${urls.length}].url needs a central HTTPS upstream.');
      }
      urls.add(value['upstream'] as String);
    }
    HostFiles.migrationRepositories(urls);
    final entries = <String>{};
    void credentialNames(Object? mapping) {
      if (mapping == null) return;
      if (mapping is! Map) {
        throw const WorkspaceRefused('project.yml credentials must be a mapping of vault entry names.');
      }
      for (final name in mapping.keys) {
        if (name is! String) throw const WorkspaceRefused('project.yml credentials must name vault entries.');
        SecretsFile.checkKeyName(name);
        entries.add(name);
      }
    }

    credentialNames(document['credentials']);
    for (final repository in repositories.values) {
      if (repository is Map) credentialNames(repository['credentials']);
    }
    return BringProjectFile._(access['repository'] as String, List.unmodifiable(urls), List.unmodifiable(entries));
  }

  /// The signed project's private access repository address.
  final String access;

  /// The validated central migration URLs.
  final List<String> repositories;

  /// The declared vault entry names, with duplicates removed.
  final List<String> keys;
}
