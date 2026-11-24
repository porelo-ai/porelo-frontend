import 'dart:convert';

/// A host's identity as the person's Porelo-Vault keeps it: its SSH host keys, the organization's read key and each
/// project's repository key, private halves included.
///
/// **Opaque here.** The window carries it from the vault into a host's setup and back, and reads nothing in it but the
/// host it is for: the daemon checks the whole of it on every write and read, and the host's setup checks it again.
/// It never says its keys when printed, so no log or error can carry them.
final class HostIdentity {
  HostIdentity._(this._value);

  /// The identity as the daemon answered it; refused unless it is an object naming its host.
  factory HostIdentity.read(Object? value) {
    if (value is! Map<String, dynamic> || value['host'] is! String || (value['host'] as String).isEmpty) {
      throw const FormatException('The vault answered no host identity');
    }
    return HostIdentity._(Map<String, dynamic>.unmodifiable(value));
  }

  final Map<String, dynamic> _value;

  /// The host it is for, as its card names it.
  String get host => _value['host'] as String;

  /// The identity as one JSON text, for the host's setup to read on its standard input.
  String get json => jsonEncode(_value);

  /// The identity as the interface sends it.
  Map<String, dynamic> get wire => _value;

  @override
  String toString() => 'HostIdentity($host)';
}

/// What of a host's identity may be shown and pinned: no private half is in it.
final class HostIdentityPublic {
  /// Takes the host, its SSH host keys and its repositories.
  const HostIdentityPublic({required this.host, required this.sshHostKeys, required this.repositories});

  /// Reads the answer of `HostIdentityPublic`, keeping only what the window shows or pins.
  factory HostIdentityPublic.read(Object? value) {
    if (value is! Map<String, dynamic> || value['host'] is! String) {
      throw const FormatException('The vault answered no host identity');
    }
    List<Map<String, dynamic>> rows(String name) =>
        (value[name] is List ? value[name] as List : const <Object?>[]).whereType<Map<String, dynamic>>().toList();
    return HostIdentityPublic(
      host: value['host'] as String,
      sshHostKeys: [
        for (final key in rows('ssh_host_keys'))
          if (key['type'] case final String type)
            if (key['public'] case final String public) (type: type, public: public),
      ],
      repositories: [
        for (final repository in rows('repositories'))
          if (repository['project'] case final String project)
            if (repository['repository'] case final String name) (project: project, repository: name),
      ],
    );
  }

  /// The host, as its card names it.
  final String host;

  /// The host's SSH host keys, each by its type: ed25519, ecdsa or rsa.
  final List<({String type, String public})> sshHostKeys;

  /// The repositories whose read keys it carries, by project.
  final List<({String project, String repository})> repositories;

  /// The ed25519 host key, `ssh-ed25519 BASE64` without its comment, as a host set up with this identity answers with
  /// it; null where none is kept.
  String? get ed25519 => switch (sshHostKeys.where((key) => key.type == 'ed25519').firstOrNull?.public.split(' ')) {
    [final type, final key, ...] => '$type $key',
    _ => null,
  };
}

/// Why a call about a host's identity did not answer. Each is its own: only [HostIdentityUnknown] means the vault keeps
/// none for the host, and nothing else is ever read as that.
sealed class HostIdentityFailure implements Exception {
  /// For a subclass.
  const HostIdentityFailure();

  /// The failure, for a person.
  String get words;

  @override
  String toString() => words;
}

/// The vault keeps no identity for the host.
final class HostIdentityUnknown extends HostIdentityFailure {
  /// Takes the host asked about.
  const HostIdentityUnknown(this.host);

  /// The host asked about.
  final String host;

  @override
  String get words => 'Your Porelo-Vault keeps no identity for $host.';
}

/// The vault keeps another identity for the host; nothing changed.
final class HostIdentityExists extends HostIdentityFailure {
  /// Takes the host asked about.
  const HostIdentityExists(this.host);

  /// The host asked about.
  final String host;

  @override
  String get words =>
      'Your Porelo-Vault keeps another identity for $host: other keys, or repositories this one drops or changes.';
}

/// The vault is shut, so nothing in it can be read or kept.
final class HostIdentityVaultShut extends HostIdentityFailure {
  /// The one shut vault.
  const HostIdentityVaultShut();

  @override
  String get words => 'Your Porelo-Vault is shut: open it, then try again.';
}

/// This computer's Porelo does not know the call yet.
final class HostIdentityUnsupported extends HostIdentityFailure {
  /// The one missing call.
  const HostIdentityUnsupported();

  @override
  String get words => "This computer's Porelo cannot keep a host's identity yet: update it.";
}

/// This computer's Porelo was not reached, or the connection ended before it answered.
final class HostIdentityUnreached extends HostIdentityFailure {
  /// Takes what the connection said.
  const HostIdentityUnreached(this.why);

  /// What the connection said.
  final String why;

  @override
  String get words => "This computer's Porelo did not answer: $why";
}

/// Any other refusal, by its name: a value the daemon refused, or a vault that is a host's and not the person's.
final class HostIdentityRefused extends HostIdentityFailure {
  /// Takes the refusal's name and what it named.
  const HostIdentityRefused(this.name, this.detail);

  /// The name said for an answer that is no identity.
  static const malformed = 'MalformedAnswer';

  /// The refusal's own name.
  final String name;

  /// What it named, such as the field refused; never part of a key, as the interface says.
  final String detail;

  @override
  String get words => switch (name) {
    'HostIdentityNotReadOnAHost' =>
      "This is a host's own Porelo, which keeps no person's host identities: they are kept by your computer's "
          'Porelo alone.',
    malformed => "This computer's Porelo answered with something that is not a host identity.",
    _ => "This computer's Porelo refused it ($name${detail.isEmpty ? '' : ': $detail'}).",
  };
}
