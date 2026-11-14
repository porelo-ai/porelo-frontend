# F575 — A Carried Credential Seen End To End

```json
{
  "$schema": "issue-1.json",
  "id": "F575",
  "title": "A Carried Credential Seen End To End",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 20,
  "blockedBy": [],
  "covers": "Story ST362: carrying a credential from this computer to a host is held by a feature scenario across two stand-in machines and checked once against porelo with B774 and B775."
}
```

**Why this size.** The feature world gains a second machine's backend; the window's code is [F572](README.md#f572)'s.

**What must be true.** The carry is held from the row's button to the host's providers read again.

## Plan

Left from [F572](README.md#f572).

- The feature world has one backend. A second stand-in machine, which carries credentials, lets one scenario press
  *Import from this computer…* on a host's row, pick a source, carry it, and see the host's provider authenticated.
- Once B774 and B775 are on porelo's main, the wire shapes are compared with the interface file, and the client is
  corrected where they differ.

## Acceptance

- The scenario, red first; the wire shapes match porelo main.

## Built

- The shell took this computer's Porelo from `thisComputersPorelo()` directly, a socket no widget test can answer.
  It now comes from `PoreloApp.thisComputer`, a `CarryingBackend` (a `FleetBackend` that `CarriesCredentials`),
  defaulting to that function; nothing changes in the running window.
- The feature world has a second stand-in, `CarryingFakeBackend` (`test/features/support/carrying.dart`), as this
  computer and as the host `elsewhere`. It acts on what it is told: the host makes one-use keys and ends each at its
  first receipt, opens only a seal made to a live key under the same name and kind, keeps an entry of that name
  unless asked to replace it, and its `Providers` then reads the provider keeping its credential under that name as
  authenticated; this computer seals a vault entry by name, or a sign-in its `ImportableCredentials` lists by agent
  and provider, under the name its own `Providers` gives that provider.
- `carrying_a_credential.feature` holds three scenarios from the row's *Import from this computer…* to the host's
  providers read again: a vault entry carried, an agent's sign-in carried (sealed by agent and provider alone), and
  an entry the host already holds kept until *Replace it on the host*. Each was seen red: without the providers read
  again after the dialog (the first two), with every receipt sent as a replace and with none (the third), and with the
  sign-in sealed by a vault name (the second).
- The client's four calls were compared field by field with porelo main's `30-vault.varlink` (at `40841d54`): the
  parameters of `ImportableCredentials` (none), `CredentialReceiver` (none), `SealCredential` (`key`, and the optional
  `name`, `agent`, `provider`, `configDirectory`) and `ReceiveCredential` (`sealed`, `name`, `kind`, `replace`), and
  the fields of `ImportableCredential` (`agent`, `provider`, `kind`), of `CredentialReceiver`'s answer (`outcome`,
  `key`, `until`), of `SealCredential`'s (`outcome`, `sealed`, `name`, `kind`, `detail`) and of `ReceiveCredential`'s
  (`outcome`, `detail`), with every outcome the file names worded. They match; nothing in the client changed.
  `test/client/credential_carry_wire_test.dart` holds the parameters sent and the fields read over the mock daemon's
  socket, seen red with `replace` sent under another name and `key` read under another.
- Not run against a real porelo: the comparison is by reading the interface file.
