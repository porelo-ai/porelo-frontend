# F273 — A Developer Joins At One Click

**Status:** Implementing.
**Size:** M - replaces the join wizard and laptop-based setup across discovery, verification, project UI and saved host state.

**What must be true.** A person named in a project's access file, which they find through `hosts/<host>/access.yml`'s access repository addresses, sees "in project P on host X" and *Join*. One click follows the project (verified by its signers), writes the host's ssh config and opens the tunnel ([F270](README.md#f270)). Nothing is pasted or typed. A project whose access file cannot be read is said, naming the repository and who may grant it.

## Why

One-click joining from signed state, the flow's step 6.

## Plan

- **Red first:** replace the setup fixture in `test/app/project_join_test.dart` with fake Core discovery and follow results. An unverified access state naming the person must cause no follow, config write or host connection. This guards joining through forged admission. Then supply verified admission and observe one follow with its trusted signers and one tunnel request after a click.
- Extend the Core boundary in `lib/src/app/fleet_backend.dart` and its adapter in `lib/src/client/porelo_client.dart` for verified admission discovery. Core reads the registry's host access entries, their project access repository addresses, the person's login and keys, and project signers. Consume typed verified results and repository-specific failures. Do not add a second YAML or signature verifier in Flutter. The agreed person, registry and access behavior is not implemented yet; use a fake Core with those shapes until the served contract is available.
- Add admitted project/host rows to `ProjectsPage` in `lib/src/ui/projects_page.dart`, even before a project is followed or a host is watched. Wire their *Join* command through `lib/src/app/commands.dart` and `lib/src/ui/shell.dart`. Replace the selected-project-only and secrets-file prerequisites. An unreadable access repository gets its own row naming the repository and the project admins who can grant access, using verified contact data.
- Rewrite `ProjectJoin` in `lib/src/app/project_join.dart` around the selected verified admission. Use the existing `FleetBackend.follow` signer-list support and observe its verified in-force result. Request the card config and host tunnel from [F270](README.md#f270). Reuse an already followed project or open host. Save the project/host association through `Settings` in `lib/src/app/settings.dart` and add the account to `Machines` in `lib/src/app/machines.dart` only after confirmation. Prevent overlapping clicks and resume safely after partial failure.
- Remove the join wizard and copy-laptop-keys action in `lib/src/ui/project_join_dialog.dart` and their shell and command wiring. Remove the join path's use of `AccessJoin` in `lib/src/app/access_join.dart`, `JoinKeys`, VPN/CA activation, signing-key and secrets-file pickers, local bundle creation, upload playbooks, forge-password feed and secrets terminal. Retire code used only by that path; retain helpers still used by host setup. Own-account provisioning belongs to Machines, tested here behind a fake admitted host. It does not run from the developer's interface.

## Acceptance

- Starting with no followed project and no watched host, verified access naming the current person offers *Join*. One click requests a follow with the supplied signers and the selected host tunnel, then records confirmed membership. It asks for no key, address, password, file or pasted value.
- Forged, revoked or stale admission supplied as a Core refusal starts nothing. An unreadable access repository names its address and the verified admins who may grant it; it does not appear as an empty project list. A follow refusal never falls back to unverified following.
- Double clicks and retry after a failed tunnel do not duplicate follows, watched accounts or host tunnels. A partial result stays visible and never claims the person is ready before confirmation. Two projects on one host reuse its connection.
- Once Machines admits the person's card key, rehearse a real join from an already configured identity and forge session. Check the verified followed revision and reachable account daemon, separately from fake tests.

## Plan as built

- `ProjectJoin` in `lib/src/app/project_join.dart` joins one verified admission. Core's discovery (`JoinDiscovery`: `JoinOffered`, `JoinUnreadable`) and the host side (`JoinHost`: the card tunnel, what the account daemon follows, and its follow with Core's signers) are two small interfaces, faked in tests. Before acting it asks Core again and refuses an admission that changed. It reuses a watched account on the host and a project already followed at the verified revision, and saves the account and the project/host association only after the host confirms the verified revision. A join not confirmed takes down the card tunnel it raised and the `<host>.conf*` files published for it (`HostCardSsh.unpublish`, only while every file holds that card's bytes), unless the account is watched or another join on the host still runs, so a later join with a rotated card is not refused; a tunnel that does not come up is taken down the same way. A watched entry by the host's name that is not this card's account refuses the join with words. A failure to save the project/host association after the account was added says so, and a retry saves it.
- `readJoinable` reads the answer of Core's `porelo registry joinable --login L --json`: each `projects[]` entry as a `JoinOffered` from its `host_card`, read with Core's own fields (`host`, `address`, `ssh_port`, `ssh_host_key`, `services`, `signed_by`) by `PreparedHost.card`, and each `refused[]` entry as a `JoinUnreadable` naming its access repository and `admins`. A broken answer, a row whose `host_account` is not the login asked for, a host card whose `host` is not its row's, or an address carrying a credential is refused whole and never shown as an empty list. Every form Core answers is read: an admin contact with `name` and `email` null (named by the login), a host address as a DNS name, IPv4 or IPv6 address as Core's card takes it, `source` and `access_repository` as `https://`, `ssh://user@host[:port]/…` or `user@host:path`, a project name `[a-z0-9][a-z0-9-]{0,62}`. A row in a form not joined here is a `JoinUnusable` row of its own, never the whole list refused.
- A join reaches the host only through a watched account made from its host card (name, ssh host, address, SSH port and host key as Core verified them), whose tunnel is up with the ssh configuration this desktop publishes for the card (`JoinHost.ready`), never a rental record by the same name. A follow counts only when the daemon answers it verified, from the verified source, at the verified revision. Rows joined at once on one host share one tunnel and one watched account. A source or access repository with credentials is refused.
- *Projects you may join* on `ProjectsPage` shows "in project P on host X" with *Join*, and an unreadable access repository as its own row naming its address and who may grant it.
- The join dialog, `AccessJoin`, the *Join this project on its host…* command and `SignedHostActions.join` are removed. The rest of the join wizard was already taken out ([F276](README.md#f276)).
- The app supplies both adapters (`appJoins` in `lib/src/app/join_adapters.dart`, used by `lib/main.dart`). Discovery asks Core on the registry checkout the registry pages read (one `RegistryReadSource`, never a second checkout), for the login `identity show` names, and refuses with its own sentence before a registry is chosen. It asks only once that registry's read has ended accepted, waits while a fetch, read or filing runs in it or a key replacement holds it, and the shell asks it after the pages' first read, after each refresh and after a registry is chosen. Both adapters use the person's card only while it may be used (`whyCardUnusable`): not revoked, verifying, its key held by the agent, and filed `done` in the registry the join reads; otherwise there are no join rows and the reason is said. The connect builds the card (`joinCard`) from the row: the host card's name, address, SSH port, host key and service ports as Core verified them, the login from `host_account` once it equals the login `identity show` names now, and the person's own public key; it raises the card tunnel through `Machines.tunnels` and watches nothing before the join is confirmed.
- The card names no uid: the host links the account's daemon at `/run/porelo-host/people/<login>/porelod.sock` and takes the return socket at `/run/porelo-host/people/<login>/return.sock`, in the person's own directory, so the tunnel forwards `-L <local>:…/porelod.sock` and `-R …/return.sock:<messenger>`. The login is checked against Core's rule `[a-z][a-z0-9-]{0,31}` in the row and in `HostCardSsh` before it reaches a path. A card saved with `uid`, `return_socket` or a `/run/user/` daemon socket still reads: they are read past, its daemon endpoint is taken from the login, and the list is saved again at once without them. A stored machine whose card does not read is set aside, kept in the file as it was and said; it never stops the others from loading.
- The vault of a card host is opened by Core's `host unlock` at the card's verified address with its pinned host key and the card's own key (`--key`), never at its bare name. Core's `host unlock` takes neither a port nor an ssh configuration, so a card on another port than 22, or at an IPv6 address, gets a refusal with words instead of a probe elsewhere.

## Deferred

- The return forward: the app's tunnels have no local messenger socket to give, so the card tunnel raised for a join carries no `-R` until the messenger supplies one.
- Whether a follow already there is pinned to Core's signers: the daemon's follow answer names no signers, so a follow at the verified revision, from the verified source and not unverified, is taken as confirmed.
- A tunnel that drops while a join runs is the tunnel's own watch ([F270](README.md#f270)); a join that ends unconfirmed takes its tunnel down, and a retry raises it again.
- The vault of a card host on another SSH port than 22, or at an IPv6 address: Core's `host unlock` takes no port and no ssh configuration yet.
- The real join rehearsal from a configured identity, once Machines admits the person's card key.

## To be checked

- Discovery waits for the registry's running work but does not hold the checkout: a refresh started while `registry joinable` runs is not excluded. `Registry` has no public way to run work in its one-at-a-time queue; adding one belongs to `lib/src/app/registry.dart`.
- Whether Core's `identity show` names the registry's `address` exactly as the checkout's chosen address, which `whyCardUnusable` compares it with.
- Confirm on a host that admits by the card's key that `/run/porelo-host/people/<login>/porelod.sock` answers through the tunnel and that the return socket binds in the person's directory.
- Confirm the served follow response can distinguish verified in-force state from a held or rewritten project.
- Trace remaining callers before deleting `AccessJoin`, `JoinKeys` or VPN helpers; project registration and host setup currently share them. Identify obsolete wizard tests to remove and retain guards for forged admission and failed confirmation.
- Confirm how retry observes a successful follow when host connection failed, and how a later revoked admission affects an already displayed join row. Measure Linux and Windows behavior against the card tunnel implementation.

## Test

Only the change: tests against a fake Core. One VM check once porelo-host admits by the card's key.

## Estimate

`F273 size=M est=60 basis=median M 61 (24 records)`
