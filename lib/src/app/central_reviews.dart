import 'dart:async';

import 'forge.dart';
import 'forge_connection.dart';

/// One central pull request, separate from approval at the host's gate.
class CentralPullRequest {
  /// Carries the public fields supplied by the forge adapter.
  const CentralPullRequest({
    required this.number,
    required this.title,
    required this.body,
    required this.head,
    required this.base,
    required this.state,
  });

  /// The forge's pull request number.
  final int number;

  /// The public title.
  final String title;

  /// The public description.
  final String body;

  /// The proposed branch.
  final String head;

  /// The target branch.
  final String base;

  /// The forge's state, including values newer than this interface.
  final String state;
}

/// One review made on the central forge by a person.
class CentralReview {
  /// Carries the forge's public review fields.
  const CentralReview({required this.id, required this.author, required this.body, required this.state});

  /// The forge's review identifier.
  final int id;

  /// The reviewer's login.
  final String author;

  /// The review text.
  final String body;

  /// The forge's review state.
  final String state;
}

/// A forge page whose continuation stays opaque to app code.
class CentralPage<T> {
  /// Captures one page and its optional adapter continuation.
  CentralPage(List<T> items, {this.next}) : items = List.unmodifiable(items);

  /// The items returned by the forge.
  final List<T> items;

  /// The next page, or null when the listing is complete.
  final String? next;
}

/// The explicit review decisions supported by the adapter boundary.
enum CentralReviewDecision {
  /// Leaves a comment without an approval decision.
  comment,

  /// Approves the central pull request.
  approve,

  /// Requests changes on the central pull request.
  requestChanges,
}

/// Typed capability missing from today's [Forge] clients.
///
/// These are app types, not a proposed wire or JSON contract for a forge.
abstract interface class CentralForgeReviews {
  /// Lists pull requests only when the person asks.
  Future<CentralPage<CentralPullRequest>> list(String repository, {String? page});

  /// Reads one pull request.
  Future<CentralPullRequest> read(String repository, int number);

  /// Lists reviews of one pull request.
  Future<CentralPage<CentralReview>> reviews(String repository, int number, {String? page});

  /// Creates a pull request with the person's own authentication.
  Future<CentralPullRequest> create(
    String repository, {
    required String title,
    required String body,
    required String head,
    required String base,
  });

  /// Submits a review, never a local gate decision.
  Future<CentralReview> submit(String repository, int number, CentralReviewDecision decision, String body);
}

/// Core's pending boundary for a short-lived, person-authenticated forge client.
abstract interface class CentralForgeSource {
  /// Uses the selected forge as [person] without exposing a token to widgets.
  ///
  /// Implementations check the authenticated login and sanitize exceptions and
  /// returned fields. They must not fall back to [ForgeTokens].
  Future<T> withReviews<T>(ForgeEntry forge, String person, Future<T> Function(CentralForgeReviews client) use);
}

/// A lost forge response whose write may already have happened.
class CentralResponseLost implements Exception {
  /// Marks uncertainty without carrying HTTP diagnostics or credentials.
  const CentralResponseLost();
}

/// Captured central-forge actions with no background polling or write replay.
class CentralReviews {
  /// Captures the person, forge and repository before an action starts.
  CentralReviews({
    required this.source,
    required this.forge,
    required this.person,
    required this.repository,
    this.answerWithin = const Duration(seconds: 30),
  }) {
    if (!GitHub.isFullName(repository)) throw const ForgeRefused('Choose a repository as owner/name.');
    if (person.isEmpty) throw const ForgeRefused('Choose the current person.');
  }

  /// The person-authenticated adapter boundary.
  final CentralForgeSource source;

  /// The selected central forge, independent of the host's local gate.
  final ForgeEntry forge;

  /// The current person's login.
  final String person;

  /// The captured repository.
  final String repository;

  /// The bound on one explicit forge action, including authentication.
  final Duration answerWithin;
  bool _writing = false;
  bool _uncertain = false;
  int _pendingWrites = 0;
  int _generation = 0;

  /// Why another write must wait, or null when it can be explicitly started.
  String? get unavailable => _writing || _pendingWrites > 0
      ? 'A central forge change is still running.'
      : _uncertain
      ? 'Read the central forge state before retrying an unconfirmed change.'
      : null;

  Future<T> _ask<T>(Future<T> Function(CentralForgeReviews client) use) async {
    var submitted = false;
    var active = true;
    try {
      return await source
          .withReviews(forge, person, (client) {
            if (!active || submitted) throw const CentralResponseLost();
            submitted = true;
            return use(client);
          })
          .timeout(answerWithin);
    } on CentralResponseLost {
      rethrow;
    } on ForgeRefused {
      throw const ForgeRefused('The central forge refused this request.');
    } on Exception {
      if (submitted) throw const CentralResponseLost();
      throw const ForgeRefused('Your central forge vault credential is unavailable.');
    } finally {
      active = false;
    }
  }

  /// Lists a page on explicit request; construction performs no network work.
  Future<CentralPage<CentralPullRequest>> list({String? page}) => _ask((client) => client.list(repository, page: page));

  /// Reads the selected pull request without creating a review.
  Future<CentralPullRequest> read(int number) => _ask((client) => client.read(repository, number));

  /// Reads a page of reviews on explicit request.
  Future<CentralPage<CentralReview>> reviews(int number, {String? page}) =>
      _ask((client) => client.reviews(repository, number, page: page));

  /// Creates a pull request once, without retrying a lost response.
  Future<CentralPullRequest> create({
    required String title,
    required String body,
    required String head,
    required String base,
  }) => _write((client) => client.create(repository, title: title, body: body, head: head, base: base));

  /// Submits the person's central review once.
  Future<CentralReview> submit(int number, CentralReviewDecision decision, String body) =>
      _write((client) => client.submit(repository, number, decision, body));

  /// Reconciles a lost reply only after an explicit read of observed forge state.
  Future<void> reconcile(Future<void> Function() readObservedState) async {
    final generation = _generation;
    void requireSettled() {
      if (_writing || _pendingWrites > 0 || generation != _generation) {
        throw const ForgeRefused('The central forge operation must settle before its result can be reconciled.');
      }
    }

    requireSettled();
    await readObservedState();
    requireSettled();
    _uncertain = false;
  }

  Future<T> _write<T>(Future<T> Function(CentralForgeReviews client) use) async {
    if (unavailable case final reason?) throw ForgeRefused(reason);
    _writing = true;
    _generation++;
    try {
      return await _ask((client) async {
        _pendingWrites++;
        try {
          return await use(client);
        } finally {
          _pendingWrites--;
        }
      });
    } on CentralResponseLost {
      _uncertain = true;
      rethrow;
    } finally {
      _writing = false;
    }
  }
}
