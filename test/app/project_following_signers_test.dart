import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machine_binding.dart' show keyPart;
import 'package:porelo_frontend/src/app/project_following.dart';
import 'package:porelo_frontend/src/app/registry.dart';

import '../support/project_access.dart';

void main() {
  late ProjectAccessFixture fixture;

  setUp(() async {
    fixture = ProjectAccessFixture();
    addTearDown(fixture.registry.dispose);
    await fixture.registry.refresh();
  });

  String aliceKey() => keyPart(fixture.registry.people.singleWhere((card) => card.login == 'alice').key);

  // Harm: a project followed by its address against signers nobody verified, or never followable at all.
  test('a project is followed against the keys of the project admins the registry names', () async {
    final following = ProjectFollowing(resolveAdminSigners: registryAdminSigners(() => fixture.registry))
      ..name = 'demo'
      ..url = 'git@github.com:example/demo.git';
    addTearDown(following.dispose);
    await following.verifySigners();
    expect(following.adminSigners, [aliceKey()], reason: 'alice is the registry\'s project admin of demo');
    expect(following.ready, isTrue, reason: 'Follow it is offered once the signers are known');
  });

  // Harm: a project the registry does not name, or an admin whose card it does not trust, is followed anyway.
  test('no signer is taken for a project the registry does not name, or from a card it does not trust', () async {
    final resolve = registryAdminSigners(() => fixture.registry);
    await expectLater(resolve('other', 'git@github.com:example/other.git'), throwsA(isA<RegistryRefusal>()));
    fixture.registrySource
      ..projectAdmin = 'bob'
      ..refusedPerson = true;
    await fixture.registry.refresh();
    await expectLater(resolve('demo', 'git@github.com:example/demo.git'), throwsA(isA<RegistryRefusal>()));
  });

  // Harm: the reason no signer was found is hidden, so the person cannot tell what to fix.
  test('the reason is said in words, and nothing becomes followable', () async {
    final following = ProjectFollowing(resolveAdminSigners: registryAdminSigners(() => null))
      ..name = 'demo'
      ..url = 'git@github.com:example/demo.git';
    addTearDown(following.dispose);
    await following.verifySigners();
    expect(following.problem, contains('Choose the registry repository first'));
    expect(following.ready, isFalse);
  });
}
