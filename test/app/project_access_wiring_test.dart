import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_access_wiring.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/registry_read_source.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/signed_host.dart';

class _Checkout implements RegistryCheckout {
  _Checkout(this.repository);
  @override
  final String repository;
  @override
  String get root => '/private/registry';
  @override
  String get folder => '/private/registry/checkout';
  @override
  Future<String> fetch() async => 'c' * 40;
  @override
  Future<void> prepareRetry({required String base, required String file, required String content}) =>
      throw UnimplementedError();
  @override
  Future<void> prepareFiling() async {}
  @override
  Future<void> publishMade(
    String revision, {
    required String base,
    required String id,
    required String file,
    String? lastRead,
  }) async {}
  @override
  Future<void> publish(String revision) async {}
}

class _Core implements RegistryCore {
  @override
  Future<RegistryRead> read(String checkout) => throw UnimplementedError();
  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) => throw UnimplementedError();
}

void main() {
  // Harm: a project offered Register or Add with no registry to admit it, or two services for one project, each
  // with its own view of what was read and authorized.
  test('a project gets its access once a registry is chosen, one service per project and registry', () async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    String? address;
    final calls = <List<String>>[];
    final access = appProjectAccess(
      registry: RegistryReadSource(
        repository: () => address,
        open: (repository) => Registry(checkout: _Checkout(repository), core: _Core()),
        machines: () => const [],
      ),
      settings: settings,
      machines: machines,
      root: '/private/project-access',
      run: (program, arguments, {inDirectory, environment = const {}, input}) async {
        calls.add([program, ...arguments]);
        return (code: 1, out: '', err: '');
      },
    );
    expect(access('demo'), isNull);
    address = 'git@example.org:team/registry.git';
    final demo = access('demo')!;
    expect(access('demo'), same(demo));
    expect(access('other'), isNot(same(demo)));
    expect(demo.registry.checkout.repository, address);
    address = 'git@example.org:team/other-registry.git';
    expect(access('demo'), isNot(same(demo)));
    expect(calls, isEmpty, reason: 'nothing runs until the project is read');
  });
}
