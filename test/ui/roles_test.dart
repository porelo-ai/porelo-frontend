import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';
import '../support/host_organization.dart';

void main() {
  // Harm: a person the organization names as neither admin is offered preparing a machine and refused only inside it;
  // or the person who holds no organization yet has no way to see why it cannot be done.
  testWidgets('a person with no role in the organization is not offered Prepare a machine…', (tester) async {
    final fixture = HostFixture()
      ..admin = false
      ..organizationAdmin = false;
    await World.startBackend(World.work);
    await World.startApp(tester, hostAccess: fixture.access);
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    expect(find.byKey(const Key('host.prepare')), findsNothing);
  });

  testWidgets('with nothing read yet Prepare a machine… stays and says why', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('host.prepare'))).onPressed, isNull);
  });

  // Harm: an Organization Admin who founded it and is on no machine yet can never prepare the first one.
  testWidgets('an Organization Admin on no machine yet may prepare one', (tester) async {
    final fixture = HostFixture()
      ..admin = false
      ..organizationAdmin = true;
    await World.startBackend(World.work);
    await World.startApp(tester, hostAccess: fixture.access);
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('host.prepare'))).onPressed, isNotNull);
  });

  // Harm: the app's host setup is composed without the Machine Admin check, so a Machine Admin named in order is
  // never let in.
  testWidgets('the shell gives host setup the composed host access', (tester) async {
    final fixture = HostFixture();
    await World.startBackend(World.work);
    await World.startApp(tester, hostAccess: fixture.access);
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('host.prepare'))).onPressed, isNotNull);
  });

  // Harm: a host admin whose identity read ends after the organization's is kept from Prepare until something else redraws.
  testWidgets('the shell shows Prepare a server… once a late identity read proves a host admin', (tester) async {
    final fixture = HostFixture();
    final proof = FixtureProof(fixture)..hold = Completer<void>();
    fixture.actor = null;
    await World.startBackend(World.work);
    await World.startApp(tester, hostAccess: (settings) => fixture.access(settings, proof: proof));
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    final control = find.byKey(const Key('host.prepare'));
    expect(tester.widget<OutlinedButton>(control).onPressed, isNull);
    final late = proof.readAgain();
    proof.hold!.complete();
    await late;
    await World.settle(tester);
    expect(tester.widget<OutlinedButton>(control).onPressed, isNotNull);
  });
}
