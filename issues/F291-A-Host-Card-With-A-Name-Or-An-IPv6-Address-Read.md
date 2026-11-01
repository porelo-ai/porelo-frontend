# F291 — A Host Card With A Name Or An IPv6 Address Read

**Status:** Idea.
**Severity:** high.
**Size:** S - one read path in the project access contract and its tests; no contract with another repository.

**What must be true.** *Register the project* and *Add a developer* work for a host whose card names a host name
or an IPv6 address, as Core's card allows, and not only for an IPv4 address.

## Why

`CoreProjectAccess` finds the admitting host with `PreparedHost.card`, which takes every address form Core's card
takes. `ProjectAccess` then stores the request and reads it back through `ProjectAccessChange.read`
(`lib/src/app/project_access.dart`), which reads the host card with `PreparedHost.read`
(`lib/src/app/project_access_contract.dart`). `PreparedHost.read` is the reader of a preparation's completion and
takes an IPv4 address only, so both actions stop with a `FormatException` for such a host.

## Plan

- `ProjectAccessChange.read` reads `host_card` as the card it is, through `PreparedHost.card`'s rules, and stores
  it in that shape. `PreparedHost.read` stays the reader of a completion.
- **Red first:** in `test/app/project_access_test.dart`, register a project and add a developer on a host whose card
  names `orchard.example.org`, and on one naming `2001:db8::7`, through `ProjectAccessChange.read`. Both fail today
  with the `FormatException`.
- A stored request of an IPv4 host still reads as before.

## Acceptance

- Both actions reach Core for a host card with a host name and with an IPv6 address; a card with an address Core's
  card refuses is still refused with words.
- The test of `project_access_core_test.dart` that builds its change without `ProjectAccessChange.read` builds it
  through the reader, so the read is part of what it tests.
