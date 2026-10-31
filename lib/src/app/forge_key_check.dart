import 'dart:convert';
import 'dart:io' show ProcessException;

import 'package:flutter/foundation.dart';

import 'run_here.dart';

/// Whether the forge lists the person's key; `unknown` is "could not be asked", never "fine".
enum ForgeKeyListed {
  /// The forge's key list holds the card's key.
  listed,

  /// The forge's key list does not hold the card's key.
  notListed,

  /// The forge lists no public keys or could not be asked.
  unknown,
}

/// The `forge` part of Core's identity answer.
@immutable
class ForgeKeyState {
  /// Keeps one checked answer.
  const ForgeKeyState({required this.login, required this.listed, required this.keysUrl, required this.accountUrl});

  /// The person's login on the forge.
  final String login;

  /// Whether the card's key is on the forge's list.
  final ForgeKeyListed listed;

  /// Where the forge lists the account's public keys.
  final Uri keysUrl;

  /// Where the person adds a key to the account.
  final Uri accountUrl;
}

/// What Core said about the person's identity and their key on the central forge.
sealed class ForgeKeyReading {
  const ForgeKeyReading();

  /// Whether the page may show the forge check as good.
  bool get good => false;
}

/// A card is kept here; [forge] is null when no registry has been read, so no forge is known.
class ForgeKeyAnswered extends ForgeKeyReading {
  /// Keeps the checked answer.
  const ForgeKeyAnswered({required this.forge, this.cardProblem});

  /// The forge's key check, or null without a known forge.
  final ForgeKeyState? forge;

  /// Why the card is not good (revoked or not verifying), or null.
  final String? cardProblem;

  @override
  bool get good => cardProblem == null && forge?.listed == ForgeKeyListed.listed;
}

/// No card is kept on this computer.
class ForgeKeyNoIdentity extends ForgeKeyReading {
  /// Keeps Core's words for the person.
  const ForgeKeyNoIdentity(this.words);

  /// Core's explanation.
  final String words;
}

/// Core could not answer; nothing about the key is known.
class ForgeKeyUnavailable extends ForgeKeyReading {
  /// Keeps a sentence safe to show.
  const ForgeKeyUnavailable(this.words);

  /// The safe explanation.
  final String words;
}

/// The read of the person's key on their central forge.
abstract interface class ForgeKeyCheck {
  /// Asks again; never throws.
  Future<ForgeKeyReading> read();
}

/// Reads `porelo identity show --json` through an argument list.
class ForgeKeyCheckCli implements ForgeKeyCheck {
  /// Uses [run] for the process, `runHere` by default.
  ForgeKeyCheckCli({RunHere? run}) : _run = run ?? runHere;

  final RunHere _run;

  @override
  Future<ForgeKeyReading> read() async {
    try {
      return parse(await _run('porelo', const ['identity', 'show', '--json']));
    } on FormatException {
      return const ForgeKeyUnavailable('Core answered in a form this interface does not know. Check again.');
    } on ProcessException {
      return const ForgeKeyUnavailable('Porelo could not be started here.');
    }
  }

  /// Maps an exit code and answer to a reading, refusing an unknown or incomplete answer.
  static ForgeKeyReading parse(Ran result) => switch (result.code) {
    0 => _answered(_object(result.out)),
    65 => _refused(_object(result.out)),
    64 => const ForgeKeyUnavailable('Core refused how it was asked.'),
    66 => const ForgeKeyUnavailable('Your card or key file could not be read.'),
    69 => const ForgeKeyUnavailable('A service Core needs could not be reached. Check again.'),
    77 => const ForgeKeyUnavailable('The vault was opened by another key.'),
    _ => const ForgeKeyUnavailable('Core could not read your identity.'),
  };

  static ForgeKeyReading _refused(Map<String, dynamic> value) {
    final words = value['words'];
    if (value['reason'] != 'no-identity' || words is! String) {
      throw const FormatException('Unknown identity refusal.');
    }
    return ForgeKeyNoIdentity(words);
  }

  static ForgeKeyReading _answered(Map<String, dynamic> value) {
    if (!const ['holds', 'not-held', 'absent'].contains(value['agent'])) {
      throw const FormatException('Unknown agent state.');
    }
    final revoked = value['revoked'];
    if (revoked is! bool) throw const FormatException('Missing revoked state.');
    final Object? refused = value['card_refused'];
    if (!value.containsKey('card_refused') || (refused != null && refused is! String)) {
      throw const FormatException('Invalid card refusal.');
    }
    if (!value.containsKey('forge')) throw const FormatException('Missing forge state.');
    final Object? forge = value['forge'];
    return ForgeKeyAnswered(
      forge: forge == null ? null : _forge(forge),
      cardProblem: revoked
          ? 'Your key is revoked.'
          : refused == null
          ? null
          : 'Your card does not verify: $refused',
    );
  }

  static ForgeKeyState _forge(Object forge) {
    if (forge is! Map<String, dynamic> || !forge.containsKey('key_listed')) {
      throw const FormatException('Invalid forge state.');
    }
    final login = forge['login'];
    if (login is! String || login.isEmpty) throw const FormatException('Missing forge login.');
    return ForgeKeyState(
      login: login,
      listed: switch (forge['key_listed']) {
        true => ForgeKeyListed.listed,
        false => ForgeKeyListed.notListed,
        null => ForgeKeyListed.unknown,
        _ => throw const FormatException('Unknown key listing.'),
      },
      keysUrl: _web(forge['keys_url']),
      accountUrl: _web(forge['account_url']),
    );
  }

  /// A browser address without user information, so no credential reaches the browser.
  static Uri _web(Object? value) {
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || !const ['https', 'http'].contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid forge address.');
    }
    return uri;
  }

  static Map<String, dynamic> _object(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) throw const FormatException('Core did not return a JSON object.');
    return value;
  }
}
