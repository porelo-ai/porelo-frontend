/// A project file `Follow` takes, for a project called [name].
///
/// **Measured, not guessed**: the file Porelo's acceptance legs followed and started a task in
/// on `snapshot.159`, six legs on Ubuntu and Fedora, with the second repository
/// Porelo measured applying — a work repository is not fetched by following, so it may
/// name a forge nobody can reach. Its `name` must be the one `Follow` is given.
///
/// A task that is started needs its work repository's host met (Porelo 280 asks), so a scenario
/// that starts one names [backend]: a bare repository in the account, which needs no host at all.
String projectFile(String name, {String backend = 'git@nowhere.invalid:acme/backend.git'}) => '''
project:
  name: "$name"
  security_class: "guarded"
image:
  base_image: "ubuntu:24.04"
repositories:
  backend:
    upstream: "$backend"''';
