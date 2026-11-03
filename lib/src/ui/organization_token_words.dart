import '../app/organization_source.dart';

/// Names the central forge where its address identifies it, otherwise keeps that address.
String organizationForgeName(OrganizationView? view) {
  var address = view?.forge?.trim() ?? '';
  if (address.isEmpty) {
    final repository = view?.address ?? '';
    address = Uri.tryParse(repository)?.host ?? '';
    if (address.isEmpty && repository.startsWith('git@')) {
      address = repository.substring(4).split(':').first;
    }
  }
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
