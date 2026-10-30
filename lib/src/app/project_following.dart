import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show quoteForAShell, checkedEd25519;

import 'fleet_backend.dart';

/// Reads Core's verified project-admin public keys for this exact project and repository.
typedef ResolveProjectAdminSigners = Future<List<String>> Function(String name, String url);

/// Following a project's repository, which is the only way a project comes to a machine.
///
/// **Nothing about the project is described here.** Its `project.yml` is written where its owner
/// commits, and what is wrong with it comes back from the follow as the named reasons — the machine
/// checks what it is handed, when it is handed it.
class ProjectFollowing extends ChangeNotifier {
  /// Uses the served Core signer adapter when available.
  ProjectFollowing({this.resolveAdminSigners});

  /// The boundary to Core's verified signer state; it accepts no private material.
  final ResolveProjectAdminSigners? resolveAdminSigners;
  int _signerRequest = 0;
  bool _disposed = false;

  /// The project's name, which must be the one its `project.yml` gives itself.
  String name = '';

  /// Where its repository is: a URL, or a directory on that machine.
  String url = '';

  /// The accepted project-admin public signer set supplied by Core.
  List<String> adminSigners = const [];

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
      _signerRequest++;
      name = '';
      url = '';
      adminSigners = const [];
    }
    _backend = backend;
    answer = null;
    check = null;
    problem = null;
    notifyListeners();
  }

  /// Takes a change to what was typed or chosen. Any answer was about the old values.
  void answerWith(void Function() change) {
    final before = (name, url);
    change();
    if (before != (name, url)) {
      _signerRequest++;
      adminSigners = const [];
    }
    answer = null;
    check = null;
    problem = null;
    hostKeyRefused = null;
    notifyListeners();
  }

  /// Whether everything a follow needs is there, with the checking chosen rather than defaulted.
  bool get ready => name.trim().isNotEmpty && url.trim().isNotEmpty && adminSigners.isNotEmpty;

  /// Whether the selected project can ask Core for its verified signers.
  bool get canVerifySigners => resolveAdminSigners != null && name.trim().isNotEmpty && url.trim().isNotEmpty && !busy;

  /// The missing dependency that prevents following without verified signers.
  String? get signersUnavailable => adminSigners.isNotEmpty
      ? null
      : resolveAdminSigners == null
      ? 'Core project-admin signer verification is not available yet.'
      : 'Verify the project-admin signers before following.';

  /// Resolves signers for the current inputs and ignores answers to superseded inputs.
  Future<void> verifySigners() async {
    if (!canVerifySigners) return;
    final request = ++_signerRequest;
    final selected = (name.trim(), url.trim());
    busy = true;
    problem = null;
    adminSigners = const [];
    notifyListeners();
    try {
      final signers = await resolveAdminSigners!(selected.$1, selected.$2);
      if (!_current(request, selected)) return;
      if (signers.isEmpty) {
        throw const FormatException('Missing verified project-admin signers.');
      }
      for (final signer in signers) {
        checkedEd25519(signer);
      }
      adminSigners = List.unmodifiable(signers);
    } catch (_) {
      if (_current(request, selected)) {
        problem = 'Project-admin signer verification was not confirmed. Nothing was followed.';
      }
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool _current(int request, (String, String) selected) =>
      !_disposed && request == _signerRequest && selected == (name.trim(), url.trim());

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
    final request = _signerRequest;
    final selected = (name.trim(), url.trim());
    final signers = List<String>.unmodifiable(adminSigners);
    busy = true;
    check = null;
    problem = 'Following the project…';
    notifyListeners();
    try {
      if (!acceptRewrite) {
        answer = null;
        check = await _checked(backend);
        if (!_current(request, selected)) {
          check = null;
          problem = null;
          return;
        }
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
      final followed = await backend.follow(
        selected.$1,
        selected.$2,
        signers: signers,
        acceptRewrite: acceptRewrite ? true : null,
      );
      if (!_current(request, selected)) return;
      answer = followed;
      problem = answer!.outcome.trim().isEmpty
          ? 'The machine returned no follow outcome; following is not confirmed. Try again.'
          : null;
    } on VarlinkException catch (refusal) {
      if (!_current(request, selected)) return;
      final said = refusal.parameters['message'];
      problem = said is String && said.isNotEmpty ? said : 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      if (!_current(request, selected)) return;
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      if (!_current(request, selected)) return;
      problem = '$ex';
    } catch (_) {
      if (!_current(request, selected)) return;
      problem = 'The project could not be followed; following is not confirmed. Try again.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
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
    _signerRequest++;
    _backend = null;
    answer = null;
    problem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _signerRequest++;
    super.dispose();
  }
}
