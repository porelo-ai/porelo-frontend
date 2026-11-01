# F299 — A Registry Row With The Host's Confirmed State

**Status:** Idea.
**Severity:** low.
**Size:** S - the registry read source's snapshot and the row words, with their tests; no contract with another
repository.

**What must be true.** A project or host row taken from the registry says which revision the host confirmed, or that
this interface has not asked the host yet. It never says "change not confirmed on the host" for a registry decision
the host has applied.

## Why

Even after Register is confirmed on a host, the row reads "registry <revision>… · host state unknown · change not
confirmed on the host". `RegistryReadSource.snapshotOf` (`lib/src/app/registry_read_source.dart`) builds
`RegistryPageSnapshot` without `applied`, so `registryStateWords` (`lib/src/ui/projects_page.dart`) says this on every
row read from the registry, before and after any change.

## The shape

- Where the host is a watched machine whose tunnel is up, the snapshot takes the host's applied registry revision from
  the host, as the bring and sync report it; otherwise the row says "host not asked yet" instead of "not confirmed".

## Plan

- `lib/src/app/registry_read_source.dart`, `lib/src/ui/projects_page.dart`.
- **Red first:** a row of a registry host whose host answered the registry's revision shows "host <revision>" and no
  "not confirmed".

## Acceptance

- A row of a host that applied the registry's decision names the same revision and nothing pending.
- A row of a host not reached says so, without suggesting a failed change.
