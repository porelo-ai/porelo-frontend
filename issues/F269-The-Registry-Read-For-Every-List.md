# F269 — The Registry Read For Every List

**Status:** Backlog. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - about a day across checkout storage, the Core client, shared list state and its interface.

**What must be true.** The interface asks once for the organisation's registry repository (an `git@` or `https` address) and reads it with the person's own access: SSH through the agent, or a token from the vault through Core's credential helper. It keeps a private checkout, fetched at start and on *Refresh*. Every list of persons, hosts, admitted project admins and projects comes from Core's `registry read` of that checkout: each person with login, name, email, fingerprint and state (trusted, first seen, refused with why). A refused card is shown in red, naming the login and why, and is never offered. A commit Core refuses is named, and the last good state stays shown. The registry's `owners.yml` (its owners and the host admins) is shown as Core reads it, with who signed it; the "who may" lines take registry owners and host admins from it. Writes go through Core's `registry file`, never through the forge's contents API.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 3: the state lies signed in Git on the central forge, and Porelo reads instead of asking.

## Plan

- Add `RegistryCheckout` in new `lib/src/app/registry_checkout.dart`. Reuse the private directory, safe repository address and clean fetch patterns of `lib/src/app/access_checkout.dart`. Do not reuse its requirement for one chosen project signing key or its single `access.yml` reader. Core judges registry history and each path's signer. Keep fetched history separate from the last accepted revision.
- Store only the credential-free registry address in `Settings` (`lib/src/app/settings.dart`). Wire the one-time address choice and startup fetch through `lib/main.dart` and `lib/src/ui/shell.dart`; add Refresh in `lib/src/app/commands.dart`. Git uses the person's SSH agent or Core's vault credential helper. Reject embedded credentials without echoing the input. Authentication failures lead to the existing terminal path, never a secret field.
- Add a shared `Registry` model in new `lib/src/app/registry.dart`. Extend `FleetBackend` and `PoreloBackend` in `lib/src/app/fleet_backend.dart`, `PoreloClient` in `lib/src/client/porelo_client.dart` and the models in `lib/src/client/models.dart` for Core's agreed registry read and file shapes. These contracts are not built yet; use a fake Core in tests, not parsed CLI output. Core receives the checkout and returns verified people, host cards, admissions, projects, owners, signers, revisions and refusals. Core uses Gorge's forge-account key and organization-owner checks; Dart does not duplicate trust decisions.
- Expose the same accepted snapshot and Core's eligibility verdicts to the pages ([F278](README.md#f278)) and actions ([F271](README.md#f271), [F272](README.md#f272), [F273](README.md#f273)). Replace locally assembled registry lists with these views. Preserve refused rows for explanation, outside selectable entries. Publish a new snapshot only after a complete valid answer; retain the last good snapshot beside a refused commit or failed fetch. Share the owners and host admins, signer and optional email for the "who may" line, with Write and Copy where an address exists. Registry mutations use Core's registry file boundary and signed Git publication, not a forge contents API.
- **Red first:** in new `test/app/registry_test.dart`, give fake Core a refused card and a rejected next commit. Attempt selection and refresh; assert no mutation is sent for the refused person, and the previous accepted people, hosts and revision remain with the rejected commit and reason. This guards unauthorized admission and loss of verified state. Add checkout tests in new `test/app/registry_checkout_test.dart` using an isolated local bare repository, including refused fetches and unsafe addresses.

## Acceptance

- One credential-free address survives restart. Startup and Refresh fetch that repository with the person's access. A refused clone or fetch leaves existing state intact and reports failure; no token is requested in a form or copied into settings, process arguments or diagnostics.
- People, hosts, admins and projects match a fake Core snapshot, including logins, names, optional emails, fingerprints, trust states, owners and signers. A refused card remains visible with its reason and cannot reach any mutation. First-seen eligibility follows Core's verdict.
- A refused next commit names the commit and reason and preserves the last accepted revision and lists. A malformed or unsupported Core answer cannot become an empty trusted list or enable an action.
- A denied action shows the applicable owners or host admins and their available contact addresses. A fake mutation records Core registry file and signed Git publication, with no forge contents write.

## Open questions

None.

## To be checked

- Confirm Core's served IDL for registry read and file, including last-good revisions, per-card eligibility, signer and rejection fields. Confirm the checkout path is on the daemon's machine; a remote daemon must not be given a desktop-only path.
- Confirm the registry layout and Core's credential-helper invocation and vault-locked answer. Confirm Gorge's public authentication-key list and organization-owner checks reach Core, rather than using the current GitHub signing-key list as a substitute.
- Check fetch serialization with pending registry writes, startup recovery of the accepted revision, and private permissions on Linux and Windows. Confirm old settings load without a registry address. Check the contact view when an admin's optional card email is absent; an email cannot always be supplied.

## Test

Only the change: tests against a fake Core and a local bare repository. No VM run.

## Deferred

- The address choice, the start-up fetch and *Refresh* wired to the Forges page's Registry section and the lists of [F278](README.md#f278) when the two are merged; until then `Registry` is built and tested on its own.

## Estimate

`F269 size=M est=60 basis=median M 61 (24 records)`
