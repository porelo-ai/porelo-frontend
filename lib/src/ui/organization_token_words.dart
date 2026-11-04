import '../app/organization_source.dart';

/// The central forge's address: as the organization names it, or as its repository's address says.
String organizationForgeAddress(OrganizationView? view) {
  final named = view?.forge?.trim() ?? '';
  if (named.isNotEmpty) return named;
  final repository = view?.address ?? '';
  final host = Uri.tryParse(repository)?.host ?? '';
  if (host.isNotEmpty) return host;
  return RegExp(r'^[^@/\s]+@([^:/\s]+):').firstMatch(repository)?.group(1) ?? '';
}

/// The address a token kept here may be used for at the central forge, or null where it is not sure:
/// tokens are kept by host, and one kept for a host says nothing of a forge on another port of it.
String? organizationKeptTokenAddress(OrganizationView? view) {
  final repository = view?.address ?? '';
  final uri = Uri.tryParse(repository);
  if (uri != null && uri.hasPort && uri.port != 443 && uri.port != 80) return null;
  if ((view?.forge ?? '').contains(RegExp(r'[\[\]:]'))) return null;
  final address = organizationForgeAddress(view);
  return address.isEmpty ? null : address;
}

/// Names the central forge where its address identifies it, otherwise keeps that address.
String organizationForgeName(OrganizationView? view) {
  final address = organizationForgeAddress(view);
  return switch (address.toLowerCase()) {
    'github.com' => 'GitHub',
    'gitlab.com' => 'GitLab',
    'codeberg.org' => 'Codeberg',
    '' => 'central forge',
    _ => address,
  };
}

/// Explains the setup token before the machine asks for it, for the organization or one waiting project.
String organizationTokenWords(OrganizationView view, String machine, {String? project}) {
  final forge = organizationForgeName(view);
  final where = forge == 'central forge' ? 'the central forge' : forge;
  final purpose = project == null
      ? "it adds its own read-only key to the organization's repository"
      : 'it adds a read-only key for $project to its central repository and copies that repository to its own forge';
  return '$machine has no account at $where, so it needs your $forge token once'
      '${project == null ? '' : ', for $project'}: $purpose. '
      'From then on it reads with that key. It does not keep the token. '
      'The token must be allowed to administer the repository (Administration: write) and read its contents.';
}
