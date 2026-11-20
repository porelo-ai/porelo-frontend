import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningForgeAccess;

void main() {
  ({ShellPlanningHost host, List<String> handed}) hostHandingOn([Future<void> Function(String origin)? how]) {
    final handed = <String>[];
    final host = ShellPlanningHost(
      ShellModel(),
      needsYou: () {},
      handOn: (origin) async {
        handed.add(origin);
        await how?.call(origin);
      },
    );
    return (host: host, handed: handed);
  }

  test('the window offers the screen its hand-on of a forge token', () {
    expect(hostHandingOn().host, isA<PlanningForgeAccess>());
  });

  // Harm: a token asked for by another machine's planner is put into this computer's vault, where that planner never
  // reads it, or answered as handed on.
  test("another provider's ask hands nothing on and answers false", () async {
    final (:host, :handed) = hostHandingOn();
    for (final provider in ['silentmaxx-ms', '', 'porelo-planner ', 'Porelo-Planner']) {
      expect(
        await host.handOnForgeToken(provider: provider, address: 'https://github.com'),
        isFalse,
        reason: provider,
      );
    }
    expect(handed, isEmpty);
  });

  // Harm: the planner's origin, untrusted, reaches the vault as more than a forge's host.
  test("this computer's planner hands on for the forge's bare origin only", () async {
    final (:host, :handed) = hostHandingOn();
    expect(await host.handOnForgeToken(provider: LocalPlanner.name, address: 'https://GitHub.com/'), isTrue);
    for (final address in [
      'https://github.com/acme',
      'https://x@github.com',
      'http://github.com',
      'https://a.b:1',
      'https://github.com:443',
      'https://github.com:',
    ]) {
      expect(
        await host.handOnForgeToken(provider: LocalPlanner.name, address: address),
        isFalse,
        reason: address,
      );
    }
    expect(handed, ['https://github.com']);
  });

  // Harm: the screen reads the board again as if a token stood there, when none was handed on.
  test('a refused or failed hand-on answers false', () async {
    for (final failure in [const OrganizationRefused('No forge token was handed over.'), Exception('broken')]) {
      final (:host, handed: _) = hostHandingOn((_) async => throw failure);
      expect(await host.handOnForgeToken(provider: LocalPlanner.name, address: 'https://github.com'), isFalse);
    }
  });

  // Harm: a second refusal while the person still answers the first opens a second vault dialog or terminal.
  test('a second ask while the first still runs opens nothing more and shares its answer', () async {
    final waiting = Completer<void>();
    final (:host, :handed) = hostHandingOn((_) => waiting.future);
    final first = host.handOnForgeToken(provider: LocalPlanner.name, address: 'https://github.com');
    final second = host.handOnForgeToken(provider: LocalPlanner.name, address: 'https://github.com');
    await Future<void>.delayed(Duration.zero);
    expect(handed, hasLength(1));
    waiting.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(await host.handOnForgeToken(provider: LocalPlanner.name, address: 'https://github.com'), isTrue);
    expect(handed, hasLength(2), reason: 'once the first ended, a new ask runs again');
  });

  // Harm: an ask for another forge or another provider, made while one hand-on runs, is answered with that run's
  // `true`, so the screen reads a board again as if a token stood there.
  test('an ask for another forge or provider while one runs answers false at once', () async {
    final waiting = Completer<void>();
    final (:host, :handed) = hostHandingOn((_) => waiting.future);
    final first = host.handOnForgeToken(provider: LocalPlanner.name, address: 'https://github.com');
    expect(await host.handOnForgeToken(provider: LocalPlanner.name, address: 'https://forge.example.org'), isFalse);
    expect(await host.handOnForgeToken(provider: 'silentmaxx-ms', address: 'https://github.com'), isFalse);
    waiting.complete();
    expect(await first, isTrue);
    expect(handed, ['https://github.com']);
  });

  // Harm: a window that gave its host no way to hand a token on answers as if one stood there.
  test('a host without a hand-on answers false', () async {
    final host = ShellPlanningHost(ShellModel(), needsYou: () {});
    expect(await host.handOnForgeToken(provider: LocalPlanner.name, address: 'https://github.com'), isFalse);
  });
}
