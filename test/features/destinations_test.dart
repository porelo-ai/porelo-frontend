// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_open_the_menu.dart';
import './step/the_menu_offers.dart';
import './step/i_choose_the_menu_entry.dart';
import './step/the_destinations_of_the_machine_are_open.dart';
import './step/the_machine_declares_the_destination_at.dart';
import './step/i_choose_the_command.dart';
import './step/it_says.dart';
import './step/i_add_the_destination_at.dart';
import './step/the_destination_cannot_be_written_yet.dart';
import './step/i_check_the_destination.dart';
import './step/nothing_was_written_to_the_machine.dart';
import './step/i_write_the_destination.dart';
import './step/the_machine_wrote_the_destination.dart';
import './step/i_type_the_destinations_address.dart';
import './step/i_remove_the_destination.dart';
import './step/a_package_declares_the_destination_at.dart';
import './step/the_destination_offers_no_removal.dart';
import './step/i_put_my_own_in_the_place_of_at.dart';

void main() {
  group('''The services a credential can be for, managed from here''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''the machine's menu opens its destinations''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheMenu(tester, 'What this machine can be told to do');
      await theMenuOffers(tester, 'Destinations — the services a credential can be for');
      await iChooseTheMenuEntry(tester, 'Destinations — the services a credential can be for');
      await theDestinationsOfTheMachineAreOpen(tester);
    });
    testWidgets('''each destination says where it is and where its key goes''', (tester) async {
      await bddSetUp(tester);
      await theMachineDeclaresTheDestinationAt(tester, 'weather', 'https://api.weather.example/v1');
      await iChooseTheCommand(tester, 'Destinations — the services a credential can be for');
      await itSays(tester, 'https://api.weather.example/v1');
      await itSays(tester, 'The key goes in the header Authorization, after "Bearer ".');
    });
    testWidgets('''a destination is checked by the machine before it is written''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(tester, 'Destinations — the services a credential can be for');
      await iAddTheDestinationAt(tester, 'weather', 'https://api.weather.example/v1');
      await theDestinationCannotBeWrittenYet(tester);
      await iCheckTheDestination(tester);
      await itSays(tester, 'The machine would read it back as https://api.weather.example/v1');
      await nothingWasWrittenToTheMachine(tester);
      await iWriteTheDestination(tester);
      await theMachineWroteTheDestination(tester, 'weather');
      await itSays(tester, 'Written: weather');
    });
    testWidgets('''a destination changed after its check is checked again before it is written''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(tester, 'Destinations — the services a credential can be for');
      await iAddTheDestinationAt(tester, 'weather', 'https://api.weather.example/v1');
      await iCheckTheDestination(tester);
      await iTypeTheDestinationsAddress(tester, 'https://api.weather.example/v2');
      await theDestinationCannotBeWrittenYet(tester);
    });
    testWidgets('''a destination the machine refuses is said in its words, and nothing is written''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(tester, 'Destinations — the services a credential can be for');
      await iAddTheDestinationAt(tester, 'weather', 'http://api.weather.example');
      await iCheckTheDestination(tester);
      await itSays(tester, 'must be reached over https');
      await theDestinationCannotBeWrittenYet(tester);
      await nothingWasWrittenToTheMachine(tester);
    });
    testWidgets('''a destination of one's own is removed, and the file it was is named''', (tester) async {
      await bddSetUp(tester);
      await theMachineDeclaresTheDestinationAt(tester, 'weather', 'https://api.weather.example/v1');
      await iChooseTheCommand(tester, 'Destinations — the services a credential can be for');
      await iRemoveTheDestination(tester, 'weather');
      await itSays(tester, 'Removed weather');
      await itSays(tester, 'No destination is declared on this machine.');
    });
    testWidgets('''a destination a package installed is not removed or changed here''', (tester) async {
      await bddSetUp(tester);
      await aPackageDeclaresTheDestinationAt(tester, 'search', 'https://api.search.example');
      await iChooseTheCommand(tester, 'Destinations — the services a credential can be for');
      await theDestinationOffersNoRemoval(tester, 'search');
      await itSays(tester, 'Put your own in its place');
    });
    testWidgets('''one's own destination put in the place of a package's says the package's is not in force''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await aPackageDeclaresTheDestinationAt(tester, 'search', 'https://api.search.example');
      await iChooseTheCommand(tester, 'Destinations — the services a credential can be for');
      await iPutMyOwnInThePlaceOfAt(tester, 'search', 'https://search.internal.example');
      await itSays(tester, 'Installed by a package, and not in force');
    });
  });
}
