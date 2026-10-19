import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'secret_store.dart';

/// Windows' Credential Manager, a generic credential per name, kept for this user on this machine.
///
/// **The value is copied into native memory only for the call and wiped before it is freed.**
class CredentialManagerStore implements SecretStore {
  @override
  Future<String?> read(String name) async => using((arena) {
    final target = PCWSTR(name.toNativeUtf16(allocator: arena));
    final found = arena<Pointer<CREDENTIAL>>();
    final read = CredRead(target, CRED_TYPE_GENERIC, found);
    if (!read.value) {
      if (read.error == ERROR_NOT_FOUND) return null;
      throw SecretStoreFailed('Credential Manager refused to read $name: error ${read.error}');
    }
    try {
      final credential = found.value.ref;
      return utf8.decode(credential.CredentialBlob.asTypedList(credential.CredentialBlobSize));
    } finally {
      CredFree(found.value);
    }
  });

  @override
  Future<void> write(String name, String value) async => using((arena) {
    final bytes = utf8.encode(value);
    final blob = arena<Uint8>(bytes.length);
    blob.asTypedList(bytes.length).setAll(0, bytes);
    final credential = arena<CREDENTIAL>();
    credential.ref
      ..Type = CRED_TYPE_GENERIC
      ..TargetName = PWSTR(name.toNativeUtf16(allocator: arena))
      ..CredentialBlobSize = bytes.length
      ..CredentialBlob = blob
      ..Persist = CRED_PERSIST_LOCAL_MACHINE
      ..UserName = PWSTR('porelo-host'.toNativeUtf16(allocator: arena));
    try {
      final written = CredWrite(credential, 0);
      if (!written.value) throw SecretStoreFailed('Credential Manager refused to keep $name: error ${written.error}');
    } finally {
      blob.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
    }
  });

  @override
  Future<void> close() async {}

  @override
  Future<void> remove(String name) async => using((arena) {
    final removed = CredDelete(PCWSTR(name.toNativeUtf16(allocator: arena)), CRED_TYPE_GENERIC);
    if (!removed.value && removed.error != ERROR_NOT_FOUND) {
      throw SecretStoreFailed('Credential Manager refused to remove $name: error ${removed.error}');
    }
  });
}
