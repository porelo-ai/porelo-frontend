import '../app/host_progress.dart';
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

/// The forge's own word for what holds the Porelo organization's repository, and none where it is not known.
String forgeOrganizationWords(OrganizationView? view) => organizationForgeAddress(view).toLowerCase() == 'github.com'
    ? 'the GitHub organization'
    : "your forge's organization";

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
  if (project == null) {
    return '$machine has no account at $where, so it needs your $forge token once: it adds its own read-only key to '
        "the Porelo organization's repository. From then on it reads with that key. It does not keep the token. "
        'The token must be allowed to administer the repository (Administration: write) and read its contents.';
  }
  return '$machine has no account at $where and keeps no token, so it needs your $forge token once for $project: each '
      'repository of it the machine takes needs a read-only key added at $where and its first copy made on the '
      "machine's own forge. From then on it reads with those keys. "
      'The token must be allowed to administer those repositories (Administration: write) and read their contents.';
}

/// What [said] waits for, beside the project or its repository: this person's token for [forge], or the project's Git
/// repository where the machine took no address for it, which a token cannot help; null where it waits for neither.
String? waitingWords(HostProjectProgress? said, String forge) {
  if (said == null) return null;
  if (said.hasNoAddress) {
    return "waits for its Git repository to be made: the machine has no address for it until the project's admin "
        'creates it or files its address anew';
  }
  if (!said.waitsForToken) return null;
  final words = 'waits for your $forge token';
  return said.why == null ? words : '$words: ${said.why}';
}

/// One machine an organization names that, as it said last, waits for this person's token for a project, or for that
/// project's Git repository.
typedef ProjectWait = ({String host, HostProjectProgress said});

/// The machines carrying [project] that, as [connections] heard them last, wait for it: one for each, so a project on
/// two machines is given its token on the one that waits. Only a Machine Admin's machines were asked.
List<ProjectWait> projectWaits(OrganizationView? view, HostConnections? connections, String project) => [
  if (view != null && connections != null)
    for (final host in view.hosts)
      if (host.projects.contains(project) ||
          view.projects.any((each) => each.name == project && each.host == host.name))
        if (connections.heard(host.name)?.of(project) case final said? when said.waitsForToken || said.hasNoAddress)
          (host: host.name, said: said),
];
