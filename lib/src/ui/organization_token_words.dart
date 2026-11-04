import '../app/organization_source.dart';

/// The central forge's address: as the organization names it, or as its repository's address says.
String organizationForgeAddress(OrganizationView? view) {
  final named = view?.forge?.trim() ?? '';
  if (named.isNotEmpty) return named;
  final repository = view?.address ?? '';
  final host = Uri.tryParse(repository)?.host ?? '';
  if (host.isEmpty && repository.startsWith('git@')) return repository.substring(4).split(':').first;
  return host;
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
