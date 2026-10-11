# F52 — Release A Device's Key Only With A Touch Or A PIN

**Status:** Estimated.
**Size:** XL - splits into a store that derives the share at unlock behind `DeviceKeyStore`,
with its words (M), and a TPM2 object behind a PIN on Linux and Windows (L); FIDO2 `hmac-secret`
(L) is an issue of its own, later.

**What must be true.** A person can enroll this device so that its key is released only with a
touch on a security key or a PIN at this machine's TPM, which code running as the same user cannot
supply.

## Why

On Linux and Windows a device keeps the key that opens a vault in a store that unlocks at login, so
anything running as that user can read it. Sokar's keyslots already carry `FIDO2` and `TPM2`
(`EnrollDevice`, `Keyslot.storage`), and this interface already says what each is worth when a
device declares one; nothing here can enroll a device that way.

## Plan

- **Today:** `DeviceKeyStore` (`lib/src/app/device_key.dart`) keeps a `DeviceKey` (slot and
  share) per node, `PlatformDeviceKeyStore` (`lib/src/app/keystore.dart`) in
  `flutter_secure_storage`, and `storageOn` declares user-scoped on Linux and Windows.
  `VaultDevices.enroll` (`lib/src/app/vault_devices.dart`) makes the share with `newShare`, keeps
  it, and sends it with `enrollDevice(storage: store.storage)`; `unlock` reads it and calls
  `unlockWithShare`. `storageWords` already words `FIDO2` and `TPM2`.
- **The seam turns from keeping a share to giving one now:** the store keeps only what is not
  secret (the slot, a credential id and salt, or a TPM object), and answers the share at unlock
  time after a touch or a PIN. The contract stays: the derived share is what `enrollDevice` and
  `unlockWithShare` carry.
- **FIDO2, later, in an issue of its own:** `hmac-secret` through libfido2 on Linux and the platform's WebAuthn on Windows, over
  `dart:ffi` as `lib/src/app/pty.dart` does with libc; `packaging/nfpm.yaml.in` names the library.
- **TPM2:** an object behind a PIN, through the TPM's software stack on Linux and the platform's
  provider on Windows.
- **The words:** a token not there or a wrong PIN set `VaultDevices.problem`, shown in
  `lib/src/ui/vault_view.dart`; nothing is offered that the device cannot do.
- **Red first:** a test in `test/app/vault_devices_test.dart` that enrolls with a fake token and
  finds no share in the store afterwards; then the refusals in
  `test/features/enrolled_devices.feature`.

## Acceptance

- **TPM2 first; FIDO2 later, as an issue of its own.** The share is derived at unlock time from a
  TPM2 object behind a PIN, and is never kept where same-user code can read it. Seen to fail: a test that
  enrolls with a fake token and finds no share in any store or file afterwards.
- **The device declares `TPM2`**, and every place it is shown says what that
  protects against, as for the other classes. Seen to fail: the enrollment request in a test, and
  widget tests of each place a device is shown.
- **A TPM or PIN that is not there refuses the unlock in words**, and offers nothing it cannot
  do. Seen to fail: a widget test unlocking without the token and with a wrong PIN.

## To be checked

- **Which native library for each, and whether the packages' dependencies may grow by it.**
  (Agent Frontend's, with the operator's word on a new dependency)
- **How it is tested beyond a fake**: a software TPM or a real token in a leg. (Agent Frontend's)
