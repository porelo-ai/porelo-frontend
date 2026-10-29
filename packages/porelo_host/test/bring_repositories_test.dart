import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

String machine(List<String>? repositories) => HostFiles.machineYaml(
  project: 'orchard',
  url: '/home/person/.local/share/porelo-host/setup/orchard/project.bundle',
  fingerprint: 'SHA256:fixture',
  act: HostAct.ownAccount,
  forgeRepositories: repositories,
);

void main() {
  // Harm: migration without its central home can strand commits on the server.
  test('a bring names every central repository and a join names no forge', () {
    final yaml = loadYaml(machine(['https://example.org/team/api.git', 'https://example.org/team/ui']));
    expect(yaml['forge']['repositories'], [
      {'name': 'api', 'url': 'https://example.org/team/api.git'},
      {'name': 'ui', 'url': 'https://example.org/team/ui'},
    ]);
    expect(loadYaml(machine(null)).containsKey('forge'), isFalse);
    expect(loadYaml(machine(['https://example.org/@team/api.git']))['forge']['repositories'], [
      {'name': 'api', 'url': 'https://example.org/@team/api.git'},
    ]);
  });

  // Harm: a secret in an upstream or an ambiguous migration name leaves the laptop.
  for (final (index, repositories) in <List<String>>[
    [],
    ['http://example.org/api.git'],
    ['ssh://git@example.org/api.git'],
    ['https://person:fixture@example.org/api.git'],
    ['https://example.org/api?fixture'],
    ['https://example.org/api#fixture'],
    ['https://example.org/'],
    ['https://example.org/.git'],
    ['https://example.org/a%20b.git'],
    ['https://example.org/api.git', 'https://other.example.org/api'],
    ['https://example.org/..'],
    ['https://example.org/api.git/'],
  ].indexed) {
    test('invalid migration set $index is refused by field', () {
      expect(
        () => machine(repositories),
        throwsA(isA<HostFilesRefused>().having((error) => error.toString(), 'field', contains('forge.repositories'))),
      );
    });
  }
}
