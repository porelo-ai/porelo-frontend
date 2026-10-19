import 'dart:io';

import 'secret_store_linux.dart';
import 'secret_store_windows.dart';

/// A provider's key, kept by the system's own store and nowhere else.
///
/// **Never a file, a log or a command line**: the value goes from standard input or the
/// interface's field into the store, and from the store into the provider's request.
abstract interface class SecretStore {
  /// The value kept under [name], or null when none is.
  Future<String?> read(String name);

  /// Keeps [value] under [name], in place of what was there.
  Future<void> write(String name, String value);

  /// Removes what is kept under [name]; nothing happens when nothing is.
  Future<void> remove(String name);

  /// Lets go of the way to the store, so a program that used it can end.
  Future<void> close();

  /// The store of the system this runs on: the Secret Service on Linux, Credential Manager on Windows.
  static SecretStore forThisSystem() {
    if (Platform.isLinux) return SecretServiceStore();
    if (Platform.isWindows) return CredentialManagerStore();
    throw UnsupportedError('no secret store on ${Platform.operatingSystem}: Linux and Windows only for now');
  }
}

/// What the store refused, in its own words.
class SecretStoreFailed implements Exception {
  /// Constructor taking what happened.
  const SecretStoreFailed(this.message);

  /// What happened, in words; never the value.
  final String message;

  @override
  String toString() => message;
}

/// The name a provider's key is kept under, the same for the interface and the command.
String providerKeyName(String provider) => 'porelo-host/$provider';
