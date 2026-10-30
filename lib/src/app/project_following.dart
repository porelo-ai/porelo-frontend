import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show quoteForAShell;

import 'fleet_backend.dart';

/// How a followed repository's commits are to be checked. Chosen, never assumed.
enum Checking {
  /// Against a public key pinned for this project.
  pinned,

  /// Not at all: whoever can push to the repository decides what this machine runs.
  unverified,
}

/// Following a project's repository, which is the only way a project comes to a machine.
///
/// **Nothing about the project is described here.** Its `project.yml` is written where its owner
/// commits, and what is wrong with it comes back from the follow as the named reasons — the machine
/// checks what it is handed, when it is handed it.
class ProjectFollowing extends ChangeNotifier {
  /// The project's name, which must be the one its `project.yml` gives itself.
  String name = '';

  /// Where its repository is: a URL, or a directory on that machine.
  String url = '';

  /// How its commits are checked, or null until somebody chooses.
  Checking? checking;

  /// The public key commits must be signed with, or its `SHA256:` fingerprint — the one a refusal
  /// names — when [checking] is [Checking.pinned].
  String key = '';

  /// What the machine answered, or null before it was asked.
  Followed? answer;

  /// What the machine said about the credential the repository would use, asked before following.
  CredentialChecked? check;

  /// Whether the machine is being asked right now.
  bool busy = false;

  /// Progress while following, or why it could not finish, in words.
  String? problem;

  FleetBackend? _backend;

  /// Opens it for [backend]'s machine — keeping what was typed for that machine until it is followed
  /// or left, since setting up its connection is a detour away from here and back.
  void startOn(FleetBackend backend) {
    if (!identical(backend, _backend)) {
      name = '';
      url = '';
      checking = null;
      key = '';
    }
    _backend = backend;
    answer = null;
    check = null;
    problem = null;
    notifyListeners();
  }

  /// Takes a change to what was typed or chosen. Any answer was about the old values.
  void answerWith(void Function() change) {
    change();
    answer = null;
    check = null;
    problem = null;
    hostKeyRefused = null;
    notifyListeners();
  }

  /// Whether everything a follow needs is there, with the checking chosen rather than defaulted.
  bool get ready =>
      name.trim().isNotEmpty &&
      url.trim().isNotEmpty &&
      (checking == Checking.unverified || (checking == Checking.pinned && key.trim().isNotEmpty));

  /// Whether the project is now in force on the machine.
  bool get taken => answer?.inForce ?? false;

  /// Whether the answer is a rewritten history, which only a person may accept.
  bool get rewritten => answer?.outcome == 'REWRITTEN';

  /// Whether the credential check stopped the follow, and says why.
  bool get held => check != null && !check!.clear;

  /// Follows it. With [acceptRewrite], a person's answer to a rewritten history — never a retry.
  ///
  /// Checks declared credentials first, without touching the network. HTTPS with no credential
  /// record is tried by the follow itself, since the offline check cannot know whether it is public.
  Future<void> follow({bool acceptRewrite = false}) async {
    final backend = _backend;
    if (backend == null || !ready || busy) return;
    busy = true;
    check = null;
    problem = 'Following the project…';
    notifyListeners();
    try {
      if (!acceptRewrite) {
        answer = null;
        check = await _checked(backend);
        if (check != null && check!.outcome.trim().isEmpty) {
          check = null;
          problem = 'The machine returned no credential-check outcome; nothing was followed. Try again.';
          return;
        }
        if (held) {
          problem = null;
          return;
        }
      }
      answer = await backend.follow(
        name.trim(),
        url.trim(),
        signedBy: checking == Checking.pinned ? key.trim() : null,
        unverified: checking == Checking.unverified ? true : null,
        acceptRewrite: acceptRewrite ? true : null,
      );
      problem = answer!.outcome.trim().isEmpty
          ? 'The machine returned no follow outcome; following is not confirmed. Try again.'
          : null;
    } on VarlinkException catch (refusal) {
      final said = refusal.parameters['message'];
      problem = said is String && said.isNotEmpty ? said : 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      problem = '$ex';
    } catch (_) {
      problem = 'The project could not be followed; following is not confirmed. Try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// A Porelo without the check is not a reason to stop: the follow itself still says what is wrong.
  Future<CredentialChecked?> _checked(FleetBackend backend) async {
    try {
      final checked = await backend.credentialCheck(url.trim());
      if (Uri.tryParse(url.trim())?.scheme == 'https' &&
          checked.connection.id.isEmpty &&
          const {'NO_CREDENTIAL', 'VAULT_LOCKED'}.contains(checked.outcome)) {
        return null;
      }
      return checked;
    } on FeatureNotSupported {
      return null;
    }
  }

  /// Whether the answer is a host key a person has to decide about — which following again cannot.
  bool get waitsOnAHostKey => const <String>{'UNKNOWN_HOST_KEY', 'HOST_KEY_CHANGED'}.contains(answer?.outcome);

  /// What trusting a host key answered when it recorded nothing — the host no longer offered the
  /// key that was confirmed — or null.
  String? hostKeyRefused;

  /// Trusts the one key of the host the follow named that a person confirmed, then follows again
  /// with nothing retyped. The host is the machine's, from the refusal, never read off the URL.
  Future<void> trustAndFollowAgain(String fingerprint) async {
    final backend = _backend;
    final host = answer?.host ?? '';
    if (backend == null || host.isEmpty) return;
    busy = true;
    hostKeyRefused = null;
    notifyListeners();
    try {
      final trusted = await backend.trustHostKey(host, fingerprint);
      if (!trusted.recorded) {
        hostKeyRefused = trusted.detail.isEmpty ? 'Nothing was recorded.' : trusted.detail;
        return;
      }
    } on VarlinkException catch (refusal) {
      final said = refusal.parameters['message'];
      hostKeyRefused = said is String && said.isNotEmpty ? said : 'Refused: ${refusal.simpleName}.';
      return;
    } on FeatureNotSupported catch (ex) {
      hostKeyRefused = '$ex';
      return;
    } finally {
      busy = false;
      notifyListeners();
    }
    await follow();
  }

  /// What the check found, in one line, before the machine's own sentence.
  String get checkWords {
    final checked = check;
    if (checked == null) return '';
    final why = switch (checked.outcome) {
      'NO_CREDENTIAL' => 'Nothing on this machine is set up to reach this address.',
      'VAULT_LOCKED' => 'The credential for this address is in the vault, and the vault is shut.',
      'MISSING_VALUE' => 'A connection for this address is set up, and its value is not there.',
      'UNUSABLE_VALUE' => 'A connection for this address is set up, and its value cannot be used.',
      'EXPIRED' => 'The token for this address has expired.',
      final other => other.toLowerCase().replaceAll('_', ' '),
    };
    return [
      why,
      if (checked.connection.id.isNotEmpty) 'The credential is ${checked.connection.id}.',
      if (checked.storeCommand.isNotEmpty)
        if (checked.storeStdin.isEmpty)
          'Add it on that machine with: ${checked.storeCommand.map(quoteForAShell).join(' ')}'
        else
          'The value must be piped in: ${checked.storeStdin}.',
    ].join(' ');
  }

  /// Puts it away.
  void letItBe() {
    _backend = null;
    answer = null;
    problem = null;
    notifyListeners();
  }
}
