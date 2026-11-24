import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_give_up.dart';

const _central = 'https://Forge.Example/acme/organization.git';

String _answer({List<Map<String, Object?>> removed = const [], List<Map<String, Object?>> kept = const []}) =>
    jsonEncode({'removed': removed, 'kept': kept});

const _organizationKey = {'project': null, 'repository': 'organization', 'title': 'porelo host orchard'};
const _gardenKey = {'project': 'garden', 'repository': 'garden', 'title': 'porelo host orchard project garden'};

void main() {
  // Harm: the token or the identity reaches an argument, or the answer is not asked for and cannot be read.
  test('give-up runs porelo for the host alone, asking for its JSON answer', () {
    expect(giveUpCommand('orchard'), ['porelo', 'host', 'give-up', '--json', '--', 'orchard']);
  });

  // Harm: a host name Porelo would read as an option changes what give-up does.
  test('a host name is taken as one, never as an option', () {
    expect(giveUpCommand('-x').sublist(4), ['--', '-x']);
  });

  // Harm: a row is lost or misnamed, a control character drives the terminal or the screen, or a huge answer hangs.
  test('the answer is read whole, the organization named as such, without control characters', () {
    final read = readGiveUpAnswer(
      _answer(
        removed: [_organizationKey],
        kept: [
          {
            ..._gardenKey,
            'why': 'the forge said no\u001b[2J',
            'link': 'https://forge.example/acme/garden/settings/keys',
          },
        ],
      ),
    )!;
    expect(read.removed.single.named, 'the organization, organization');
    expect(read.kept.single.named, 'project garden, garden');
    expect(read.kept.single.why, 'the forge said no [2J');
    expect(read.kept.single.link, 'https://forge.example/acme/garden/settings/keys');
    expect(
      readGiveUpAnswer(
        _answer(
          kept: [
            {..._gardenKey, 'why': 'x' * (256 * 1024)},
          ],
        ),
      ),
      isNull,
    );
    expect(readGiveUpAnswer('[]'), isNull);
    // A row that is no object is never dropped: the answer it stands in is unreadable as a whole.
    expect(readGiveUpAnswer('{"removed":[7],"kept":[]}'), isNull);
    expect(readGiveUpAnswer('{"removed":[],"kept":["garden"]}'), isNull);
    expect(readGiveUpAnswer(null), isNull);
  });

  // Harm: an outcome is said otherwise than it is: keys taken for removed, a run cut short for nothing done.
  for (final (name, code, answer, mayRunAgain, says) in <(String, int?, String?, bool, String)>[
    ('all removed', 0, _answer(removed: [_organizationKey, _gardenKey]), false, 'orchard is given up'),
    (
      'some kept',
      65,
      _answer(
        removed: [_organizationKey],
        kept: [
          {..._gardenKey, 'why': 'refused', 'link': null},
        ],
      ),
      true,
      '1 of its keys remain at the central forge',
    ),
    ('changed while given up', 65, _answer(removed: [_organizationKey]), true, 'changed while it was given up'),
    ('kept or changed, with no answer to read', 65, null, true, 'its answer could not be read: it ended with 65'),
    ('done, with no answer to read', 0, null, false, 'its answer could not be read: it ended with 0'),
    ('no identity', 66, null, false, 'keeps no identity of orchard'),
    ('no token', 69, null, false, 'No token for the central forge'),
    ('a shut vault', 77, null, false, 'Porelo-Vault is shut'),
    ('no organization', 78, null, false, 'no organization'),
    ('a bad host name', 64, null, false, 'as a host name'),
    ('cancelled', null, null, true, 'Some of its keys may already be removed'),
  ]) {
    test('$name says so', () {
      final outcome = giveUpOutcome(
        host: 'orchard',
        started: true,
        code: code,
        answer: answer,
        lastLine: 'porelo: the kept identity is not one to give up: a repository lacks its project',
      );
      expect(outcome.words, contains(says));
      expect(outcome.mayRunAgain, mayRunAgain);
      if (mayRunAgain) expect(outcome.words, contains('Give-up may be run again'));
      expect(outcome.allGone, code == 0 && answer != null, reason: 'only an answer read says all is gone');
      if (answer == null && (code == 0 || code == 65)) {
        expect(outcome.words, contains('a repository lacks its project'));
      }
    });
  }

  test('a run that never started says nothing was removed', () {
    expect(
      giveUpOutcome(host: 'orchard', started: false, code: null, answer: null, lastLine: '').words,
      contains('nothing was removed'),
    );
  });

  // Harm: a button sends the person to another site than the organization's own forge, with whatever they sign in to.
  test("a link is offered only on the organization's own central forge", () {
    expect(offeredLink('https://forge.example/acme/garden/settings/keys', _central), isNotNull);
    for (final link in [
      'https://forge.example@evil.com/acme/garden/settings/keys',
      'https://forge.example.evil.com/acme/garden/settings/keys',
      'http://forge.example/acme/garden/settings/keys',
      'https://forge.example:8443/acme/garden/settings/keys',
      'https://user@forge.example/acme/garden/settings/keys',
      'not a link',
      null,
    ]) {
      expect(offeredLink(link, _central), isNull, reason: '$link');
    }
    expect(offeredLink('https://forge.example/acme/garden/settings/keys', null), isNull);
  });

  // Harm: an organization with hosts stands at an ssh address, so no link is ever a button, or one elsewhere is.
  for (final central in [
    'git@Forge.Example:acme/organization.git',
    'ssh://git@forge.example:2222/acme/organization.git',
    'forge.example:acme/organization.git',
  ]) {
    test('a central forge at $central offers links on its host and the https port alone', () {
      expect(offeredLink('https://FORGE.example/acme/garden/settings/keys', central), isNotNull);
      for (final link in [
        'https://forge.example@evil.com/acme/garden/settings/keys',
        'https://forge.example.evil.com/acme/garden/settings/keys',
        'http://forge.example/acme/garden/settings/keys',
        'https://forge.example:2222/acme/garden/settings/keys',
        'https://forge.example:8443/acme/garden/settings/keys',
        'https://user@forge.example/acme/garden/settings/keys',
        'https://evil.com/acme/garden/settings/keys',
      ]) {
        expect(offeredLink(link, central), isNull, reason: link);
      }
    });
  }

  test('a central forge that names its https port offers links on that port alone', () {
    const central = 'https://forge.example:8443/acme/organization.git';
    expect(offeredLink('https://forge.example:8443/acme/garden/settings/keys', central), isNotNull);
    expect(offeredLink('https://forge.example/acme/garden/settings/keys', central), isNull);
  });
}
