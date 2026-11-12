import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e.dart';
import 'rehearsal.dart';

/// The repository at GitHub that forwarded work lands in, and its branches, as `tool/walk_idea.sh --test
/// forwarding_to_a_branch` is told them. GitHub is read with git, through the run's own credential helper: no token is
/// ever in this process.
abstract final class Forwarding {
  /// The repository's https address at GitHub, for example `https://github.com/porelo-ai-test/foo-1`.
  static String get url => _required('PORELO_FORWARD_URL');

  /// The repository's name in the project, as the window lists it.
  static String get repository => _required('PORELO_FORWARD_REPOSITORY');

  /// A branch the repository has before the run, made by the script at the default branch's tip.
  static String get existing => _required('PORELO_FORWARD_EXISTING');

  /// The new branch the person types, made by nobody before the forward.
  static String get typed => _required('PORELO_FORWARD_TYPED');

  static String _required(String variable) {
    final value = Platform.environment[variable] ?? '';
    if (value.isEmpty) throw StateError('$variable is not set: run this through tool/walk_idea.sh');
    return value;
  }

  /// The branch the work was forwarded onto.
  static String? branch;

  /// The default branch and its head before the forward.
  static (String branch, String head)? defaultBefore;

  /// Every branch at GitHub and its head before the forward: all but the chosen one must stand there after it.
  static Map<String, String>? branchesBefore;
}

/// Every branch at GitHub with its head.
Future<Map<String, String>> theBranchesAtGitHub() async {
  final listed = await _git(['ls-remote', '--heads', Forwarding.url]);
  return {
    for (final line in listed.split('\n'))
      if (line.split('\t') case [final head, final ref] when ref.startsWith('refs/heads/'))
        ref.substring('refs/heads/'.length): head,
  };
}

/// The head of [branch] at GitHub, or null where GitHub has no such branch.
Future<String?> theHeadAtGitHub(String branch) async {
  final listed = await _git(['ls-remote', Forwarding.url, 'refs/heads/$branch']);
  final line = listed.split('\n').where((each) => each.endsWith('\trefs/heads/$branch')).firstOrNull;
  return line?.split('\t').first;
}

/// The default branch at GitHub and its head.
Future<(String, String)> theDefaultAtGitHub() async {
  final listed = await _git(['ls-remote', '--symref', Forwarding.url, 'HEAD']);
  final named = RegExp(r'^ref: refs/heads/(\S+)\tHEAD$', multiLine: true).firstMatch(listed);
  final head = RegExp(r'^([0-9a-f]{40,64})\tHEAD$', multiLine: true).firstMatch(listed);
  if (named == null || head == null) throw StateError('GitHub names no default branch of ${Forwarding.url}: $listed');
  return (named.group(1)!, head.group(1)!);
}

/// Runs git against GitHub; a refusal is asked again twice, a moment apart, so one lost answer is not the run's end.
Future<String> _git(List<String> arguments) async {
  for (var tried = 1; ; tried++) {
    final result = await Process.run(
      'git',
      ['-c', 'credential.interactive=never', ...arguments],
      environment: {'GIT_TERMINAL_PROMPT': '0'},
    );
    if (result.exitCode == 0) return result.stdout as String;
    if (tried == 3) fail('git ${arguments.join(' ')} exited ${result.exitCode}: ${result.stderr}');
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

/// Forwards the reviewed work through *Forward it upstream…* onto [branch]: chosen from the branches the dialog offers,
/// or [typed] as a new one. The dialog must offer the repository's own branches, its default first, as GitHub says
/// them; it waits until the machine no longer holds the work at the gate.
Future<void> forwardUpstream(WidgetTester tester, String branch, {required bool typed}) async {
  Forwarding.branch = branch;
  final forward = find.ancestor(of: find.textContaining('Forward it'), matching: find.byType(FilledButton));
  await pumpUntil(tester, () => forward.evaluate().isNotEmpty, what: 'the gate to offer forwarding');
  await tester.ensureVisible(forward.first);
  await tester.tap(forward.first);
  await pumpFor(tester);
  final offered = find.byKey(const Key('forward-branch'));
  await pumpUntil(tester, () => offered.evaluate().isNotEmpty, what: "the dialog to offer the repository's branches");
  await tester.tap(offered.first);
  await pumpFor(tester);
  final (defaultBranch, _) = Forwarding.defaultBefore!;
  final items = find.byWidgetPredicate((w) => w is DropdownMenuItem<String?>);
  final values = [for (final each in items.evaluate()) (each.widget as DropdownMenuItem<String?>).value];
  // The menu shows each item twice while open, the chosen one and the list; the list's own order is what is read.
  final listed = values.where((each) => each != null).toSet().toList();
  expect(listed.firstOrNull, defaultBranch, reason: 'the default branch is offered first; got $listed');
  if (typed) {
    expect(listed, isNot(contains(branch)), reason: 'GitHub had no $branch, so it is not offered');
    await tester.tap(find.text('A new branch…').last);
    await pumpFor(tester);
    final field = find.byKey(const Key('forward-new-branch'));
    await pumpUntil(tester, () => field.evaluate().isNotEmpty, what: 'the field for a new branch');
    await tester.enterText(field, branch);
    await pumpFor(tester);
  } else {
    expect(listed, contains(branch), reason: 'the branch GitHub has is offered; got $listed');
    await tester.tap(find.text(branch).last);
    await pumpFor(tester);
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Forward it'));
  await pumpFor(tester);
  // Sent once the machine no longer holds the work at the gate; a refusal stays on screen and is the failure.
  await pumpUntil(
    tester,
    () async {
      final task = (await theProjectsTasksOnTheHost()).where((t) => t['name'] == Rehearsal.waitingTask).firstOrNull;
      return task != null && (task['waiting'] as int? ?? 0) == 0;
    },
    timeout: const Duration(minutes: 3),
    what: 'the gate to send it to $branch',
  );
}
