/// A project file for a project called [name], its `name` the one it is registered under.
///
/// A task that is started needs its work repository's host met (Porelo 280 asks), so a scenario
/// that starts one names [backend]: a bare repository in the account, which needs no host at all.
String projectFile(String name, {String backend = 'git@nowhere.invalid:acme/backend.git'}) =>
    '''
project:
  name: "$name"
  security_class: "guarded"
image:
  base_image: "ubuntu:24.04"
repositories:
  backend:
    upstream: "$backend"''';
