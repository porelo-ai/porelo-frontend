# F288 — Small Leftovers Of The One-Click Flow

**Status:** Idea.

**What must be true.** Small edge cases left over from the one-click flow's build are kept in one place, for the operator to place:
address forms, quoting, encodings, texts and test gaps. A grave finding never goes here; it gets an issue of its own.

Each point is to be checked against the code before it is fixed.

## Gathered

1. **An scp path holding `@`:** the join refuses any `@` after the host in every address form. Core's final address
   rule cuts the scp form where git splits it, and keeps `git@example.org:team@v2:repo.git` as given,
   with no credential. So this interface shows such a project as a refused row of its own. The rest of the join's
   checks agree with Core's rule: a bracketed host must be an IPv6 literal, `%40` is refused, and `host:a@b:c`
   without a user is read as `user:password@host:path`. Only the scp path is to be read as Core reads it.
2. **Linux CI timeout of the terminal close test:** `pty_test` "termination and close wait for the output consumer
   to reach EOF" timed out once on a Linux runner (Build 41235532851). It did not fail here in 5 single runs or in 24
   runs with 8 in parallel, and the close code had not changed. If it recurs, the test's bound is to be looked at
   against a loaded runner.
3. **A SHA-256 registry:** the registry bundle for a host is built in a bare repository made as SHA-1, so a registry
   whose commits are SHA-256 cannot be brought; it is to be made in the registry's own object format.
4. **`--since` per registry address:** the last revision a host applied is kept per host alone, so after switching to
   another registry sharing an ancestor, the local verification skips history up to it; it is to be kept per registry
   address and host.
5. **Registry bundle folders swept at start:** a crash while sending leaves a `registry-bundle-` folder under the
   app's data that nothing removes; the start sweeps them as it sweeps card copies.
6. **A test of `main.dart`'s composition:** the shell's host access test hands its own host access in, so it stays
   green when `main.dart` composes none; a test of the composed app is to hold it.

## Left open by the finished one-click issues

What the finished issues of the one-click flow had deferred or still to check, kept here so it is not lost. Much of it changes or falls away with the organization model; each point
is read against that model before it is placed.

- **Keys and cards:** after a create, rotate or lost-key run in the KeePassXC terminal, a reason that does not fit on
  the terminal's last line is read back from Core; a filed card is committed, not pushed, until the registry's
  publication step; *Make a backup key…* refuses until Core's backup-key verb is served. Core's recovery identifiers,
  reset completion after an interruption, host-vault reset over SSH, and per-host KRL and lock acknowledgment are
  still to be confirmed against Core and the host.
- **Registry reads:** Core's served registry IDL (last-good revision, per-card eligibility, signer and rejection
  fields); a checkout path on the daemon's machine, never a desktop path given to a remote daemon; fetch serialized
  with pending writes; the contact view when an admin's card has no email.
- **Card tunnels:** a port reservation can leak when a card machine becomes card-less or is renamed during an
  overlapping edit (freed on restart); a locked signer is told apart from a refused admission only once Core answers
  it in a typed result; `.localhost` URLs in browsers and Element and the exposure of loopback ports to other local
  users are to be measured; the machine list is to read the host state and problem the fleet model holds.
- **Host administration:** a host card filed through the agent needs a card the host admin signed; host-wide lock,
  let back in and account deletion have no Core verb; the daemon's `RegistryFile` takes the text as `content`, the
  CLI `--file`; the host's `registry status` answer is built to the shape porelo-host stated and was not run live;
  Scaleway preparation stays refused until Core's rental and identity adapter is there.
- **Project administration:** Remove, Lock, Let back in and accepting a new key stay unavailable until the host
  answers each person's applied state; the host has no own-account registration a project admin can run without a
  hand step; automatic collaborator grants on the central forge are not built.
- **Joining:** the card tunnel of a join carries no `-R` return forward until the messenger gives a socket; a follow
  is taken as confirmed without the daemon naming its signers; a card host on another SSH port or an IPv6 address
  cannot open its vault until Core's `host unlock` takes a port; a refresh can start while `registry joinable` runs.
- **Central transfers:** central pull requests and reviews need list, read and create calls the forge clients lack;
  the host-forge refresh needs a served contract that never contacts the central forge; the five-minute terminal
  deadline and thirty-second review bound are unmeasured; the legacy bring token entry is not migrated.
- **Sign-in flow:** the wire spelling of `login.flow` and how a refused loopback flow on a host account reaches the
  terminal are to be confirmed with Core.
- **Removed VPN era:** project take-off goes through the host's access list; the Connections private-key form,
  machine-signers texts and the VPN-era forwards in `tunnel.dart` and `homeserver_forwards.dart` are still to go;
  operating-system VPN and trust artifacts left by older versions need a reviewed, ownership-checked migration.
- **Signing:** workspace commits and merges are checked against Core's signer lines only once Core names the project
  of a forge repository; the key choice in the binding views and the forge-derived signer list in machine binding
  wait for the binding path over the host forge's Git socket.
- **Pages:** older guided walks, tests and tooling still hold machine-specific values; the action models for gathered
  push and pull and for the backup key are to be checked against their final contracts.

## Declined from the reading of the walk's fixes

A reading of the fixes made during the walk reported these. None was reproduced by a test, so each is an unconfirmed
finding; each is declined with its reason, and is read again where its code is rebuilt.

- **Register, Add and the developers dialog** (not fixed: the organization model removes these dialogs). Reported:
  closing the Register dialog while a step runs leaves the project's access
  work running, and reopening it reads into the same checkouts; *Verify* carries a filed change on to the host;
  the change's own registry wait is not bounded where it files; a registry read that fails while the dialog is open
  empties the person picker without saying why; a registry refresh started by a change is not bounded; a `replace`
  or `lock` the host took in an earlier sync is not confirmed on retry. Each must hold in the rebuilt flow: no
  background work outlives its dialog unseen, a read never changes a host, and every wait is bounded.
- **The busy port's holder** is named from `ss` across address families: another account's listener on
  `127.0.0.1` can be passed over for this account's on `[::1]`. Only the sentence can name the wrong process; nothing
  is ended from it.
- **Callers that word a refusal again:** some callers of local commands catch every exception and show their own
  sentence ("Git could not be run on this computer."), so a command ended at its limit loses its own words there.
- **A test instance's entry flag** keeps the last of several `--forge-token-entry` given, as a command line usually
  does; an entry name outside the installation pattern never reaches the secrets file.
- **The registry environment** lists the test secrets file twice per call when it looks for the installation entry.
- **A copy over ssh with a deadline and agent-only identities:** no caller combines the two.
- **A card's address, against what can be reached:** a saved card takes `::`, `0.0.0.0` and a multicast address, which the check of a server's completion refuses; the upload and the stop feed then ask ssh for it, and the pinned host key still decides.
- **A server that reports no usable address:** given by name or IPv6 address, it fails as "did not confirm completion" rather than in its own words; no server does it while the host's play needs an IPv4 default route.
- **Push and pull in the command finder** stand only in the project's menu, as the project's other actions do.

## Idea

Each point gets a test that goes red with its harm first, when it is placed.
