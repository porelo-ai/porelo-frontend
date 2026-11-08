import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/vault.dart';
import 'package:porelo_frontend/src/ui/vault_actions.dart';
import 'package:porelo_frontend/src/ui/vault_view.dart';

import 'tiles.dart';
import 'world.dart';

/// Finds the current machine's observations so a daemon fixture refreshes the model its page uses.
Future<Vault> vaultOfCurrentMachine(WidgetTester tester) async {
  final machine = World.machines.current;
  Vault? shown() {
    if (World.shell.place.machine != null && World.shell.place.machine != machine) return null;
    final views = tester.widgetList<VaultView>(find.byType(VaultView));
    if (views.isNotEmpty) return views.first.vault;
    final buttons = tester.widgetList<VaultButtons>(find.byType(VaultButtons));
    return buttons.isEmpty ? null : buttons.first.vault;
  }

  final visible = shown();
  if (visible != null) return visible;
  final place = World.shell.place;
  final project = World.shell.itemProject;
  await toTheMachinesPage(tester, machine.name);
  final vault = shown();
  expect(vault, isNotNull, reason: '${machine.name} must expose its own vault observations');
  if (place.machine != null && project != null) {
    World.shell.openProject(place.machine!, project);
  } else {
    World.shell.choosePlace(place);
  }
  await World.settle(tester);
  return vault!;
}
