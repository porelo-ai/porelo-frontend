import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart' show Connection;

import 'package:porelo_host/porelo_host.dart' show CentralToken;

import 'host_token.dart' show declaredOrganizationToken;

/// Where a host's forge token can come from, in the order they are asked.
enum TokenSource {
  /// The entry this computer's Porelo-Vault declares for the organization's forge; handed on by Porelo, never read.
  declared,

  /// The token this window keeps for the organization's forge, from signing in under *My forges*.
  kept,

  /// The secrets file or the variable this window was started with, fed in a terminal.
  secretsFile,
}

/// What asking one source came to.
enum TokenSourceState {
  /// It holds a token that can be given.
  found,

  /// It answered, and holds none.
  none,

  /// It could not be asked; never counted as none.
  failed,
}

/// One source's answer, with the words that say it.
class TokenSourceAnswer {
  /// Keeps what [source] answered.
  const TokenSourceAnswer(this.source, this.state, this.words, {this.declared, this.secrets});

  /// Which source was asked.
  final TokenSource source;

  /// What it came to.
  final TokenSourceState state;

  /// What it answered, in the person's words.
  final String words;

  /// The declared entry, where [source] is [TokenSource.declared] and it was found.
  final Connection? declared;

  /// The secrets source, where [source] is [TokenSource.secretsFile] and it was found.
  final CentralToken? secrets;

  /// The source's name as the person reads it.
  String get name => switch (source) {
    TokenSource.declared => "This computer's Porelo-Vault",
    TokenSource.kept => 'The token kept under My forges',
    TokenSource.secretsFile => 'The secrets file',
  };
}

/// Why this computer's Porelo-Vault could not be asked, in words; thrown, never read as an empty vault.
class DeclarationsUnread implements Exception {
  /// Keeps why.
  const DeclarationsUnread(this.words);

  /// Why, in the person's words.
  final String words;

  @override
  String toString() => words;
}

/// Asks every source of a forge token for a host, in order, and says what each answered.
class HostTokenSources {
  /// Asks [declarations] for this computer's vault entries matching [repository] (throwing [DeclarationsUnread] where
  /// it cannot say), [hasKept] whether a token is kept for the forge at [address], and [secrets] for the secrets file
  /// or variable.
  HostTokenSources({
    required this.forge,
    required this.repository,
    required this.address,
    required this.declarations,
    required this.hasKept,
    required this.secrets,
  });

  /// The organization's forge, as the person names it.
  final String forge;

  /// The organization's repository address, which a declared entry matches; null where the organization names none.
  final String? repository;

  /// The organization's forge address, which a kept token is kept under; null where none can be kept for it.
  final String? address;

  /// This computer's vault entries.
  final Future<List<Connection>> Function() declarations;

  /// Whether a token is kept for an address.
  final Future<bool> Function(String address) hasKept;

  /// The secrets file or variable, or null where none was chosen.
  final CentralToken? Function() secrets;

  /// Asks every source, and answers each one's answer in the order they are offered.
  Future<List<TokenSourceAnswer>> ask() async => [await _declared(), await _kept(), _secrets()];

  Future<TokenSourceAnswer> _declared() async {
    final organization = repository;
    if (organization == null) {
      return const TokenSourceAnswer(
        TokenSource.declared,
        TokenSourceState.none,
        'The organization names no repository address, so no entry can match it.',
      );
    }
    try {
      final held = await declarations();
      if (declaredOrganizationToken(organization, held) case final found?) {
        return TokenSourceAnswer(
          TokenSource.declared,
          TokenSourceState.found,
          'It declares ${found.id} for ${found.match}. Porelo hands it on itself; this window never reads it.',
          declared: found,
        );
      }
      final absent = held.where((each) => each.kind == 'TOKEN' && !each.present).map((each) => each.id).toList();
      return TokenSourceAnswer(
        TokenSource.declared,
        TokenSourceState.none,
        absent.isEmpty
            ? 'It declares no token for $organization.'
            : 'It declares no token for $organization that is there now; ${absent.join(', ')} '
                  '${absent.length == 1 ? 'is' : 'are'} declared but not there.',
      );
    } on DeclarationsUnread catch (unread) {
      return TokenSourceAnswer(TokenSource.declared, TokenSourceState.failed, unread.words);
    } on Exception catch (error) {
      return TokenSourceAnswer(TokenSource.declared, TokenSourceState.failed, 'It could not be asked: $error');
    }
  }

  Future<TokenSourceAnswer> _kept() async {
    final organization = address;
    if (organization == null) {
      return const TokenSourceAnswer(
        TokenSource.kept,
        TokenSourceState.none,
        'No token can be kept for this organization\'s forge on this computer: its address has a port of its own, or '
        'none is named.',
      );
    }
    try {
      return await hasKept(organization)
          ? TokenSourceAnswer(TokenSource.kept, TokenSourceState.found, 'A $forge token is kept on this computer.')
          : TokenSourceAnswer(
              TokenSource.kept,
              TokenSourceState.none,
              'No $forge token is kept on this computer. Sign in to $forge under My forges to keep one.',
            );
    } on Exception catch (error) {
      return TokenSourceAnswer(
        TokenSource.kept,
        TokenSourceState.failed,
        "This computer's secret store could not be read: $error",
      );
    }
  }

  TokenSourceAnswer _secrets() {
    try {
      return switch (secrets()) {
        final found? => TokenSourceAnswer(
          TokenSource.secretsFile,
          TokenSourceState.found,
          'A secrets file or variable was chosen; a terminal reads the token from it.',
          secrets: found,
        ),
        null => const TokenSourceAnswer(
          TokenSource.secretsFile,
          TokenSourceState.none,
          'No secrets file was chosen for this window, and no variable holds a token.',
        ),
      };
    } on Exception catch (error) {
      return TokenSourceAnswer(TokenSource.secretsFile, TokenSourceState.failed, 'It could not be read: $error');
    }
  }
}

/// Giving one host its forge token as a step of its own: connect, ask every source, give the one the person chooses.
class HostTokenStep extends ChangeNotifier {
  /// Gives [host] its token from [sources]; [connect] reaches the host first, [give] hands one source's token over and
  /// answers null once the host took it, or why not.
  HostTokenStep({required this.host, required this.sources, required this.connect, required this.give, this.heard});

  /// The host.
  final String host;

  /// Where a token can come from.
  final HostTokenSources sources;

  /// Connects to the host, throwing with why where it cannot.
  final Future<void> Function() connect;

  /// Hands the answer's token over; null once the host took it.
  final Future<String?> Function(TokenSourceAnswer answer) give;

  /// Asks the host what it now says, once it took a token, so that what shows it waiting follows its word.
  final Future<void> Function()? heard;

  List<TokenSourceAnswer>? _answers;
  bool _asking = false;
  bool _giving = false;
  bool _given = false;
  String? _problem;

  /// Every source's answer, once asked.
  List<TokenSourceAnswer>? get answers => _answers;

  /// Whether the host is being reached or the sources asked.
  bool get asking => _asking;

  /// Whether a token is being handed over.
  bool get giving => _giving;

  /// Whether the host took a token.
  bool get given => _given;

  /// Why the last step did not go through, or null.
  String? get problem => _problem;

  /// The first source that holds a token, which is offered.
  TokenSourceAnswer? get offered => _answers?.where((each) => each.state == TokenSourceState.found).firstOrNull;

  /// Connects to the host and asks every source again.
  Future<void> ask() async {
    if (_asking || _giving) return;
    _asking = true;
    _problem = null;
    notifyListeners();
    try {
      await connect();
      _answers = await sources.ask();
    } on Exception catch (error) {
      _problem = '$host could not be reached, so no source was asked: $error';
    } finally {
      _asking = false;
      notifyListeners();
    }
  }

  /// Hands [answer]'s token to the host.
  Future<void> giveFrom(TokenSourceAnswer answer) async {
    if (_giving || answer.state != TokenSourceState.found) return;
    _giving = true;
    _problem = null;
    notifyListeners();
    try {
      final why = await give(answer);
      _given = why == null;
      _problem = why;
    } on Exception catch (error) {
      _problem = '$host was given no token: $error';
    } finally {
      _giving = false;
      notifyListeners();
    }
    // What it says next is the host's own word; a host not asked now is asked by the next Refresh, as before.
    if (_given) {
      try {
        await heard?.call();
      } on Exception catch (_) {}
    }
  }
}
