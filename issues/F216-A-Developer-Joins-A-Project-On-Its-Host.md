# F216 — A Developer Joins A Project On Its Host

**Status:** Backlog; blocked by [F209](README.md#f209), [F212](README.md#f212), [F214](README.md#f214) and [F215](README.md#f215).
**Size:** L - the join's steps from a signed file to a working account, the laptop's keys, and their tests.

**What must be true.** A developer whom a project's signed access file lists joins it on its host with nothing handed over: the interface checks the file, brings this laptop's own VPN up with its address from the list, trusts the host's CA by its signed fingerprint, pins the host key, and runs the join in the developer's own account; *Copy my public keys for <host>* gives a project admin what the list needs.

## Why

Decided: developers come from the signed access file; the hand-carried access request and access file go for them.

## Plan

- ***Copy my public keys for <host>*** (`user`): this laptop makes that host's ssh key and WireGuard key (private halves in the system secret store, as the VPN key today) and copies the public halves as one text block with no ssh comment.
- ***Join this project on its host*** (`user`):
  1. clone the access repository with the developer's own read access; without it, say so, naming the repository and GitHub's invitation, and change nothing;
  2. a local `porelo` runs `project verify --json --access-repository … [--access-since …]`; where Porelo is missing, say "Install Porelo on this computer" and stop; the laptop keeps the commit it joined at;
  3. the VPN for this host with this laptop's `vpn_address` ([F209](README.md#f209));
  4. the CA fetched over ssh from `/etc/porelo-host/forge/ca.pem` and installed only where its SHA-256 equals `ca_sha256` ([F212](README.md#f212)), refused with both fingerprints otherwise;
  5. the ssh host key pinned from `host:`;
  6. `porelo-host join` in the developer's own account, its stop in own-account mode ([F214](README.md#f214)): their vault, the gate's and agents' tokens from the helper's file, their lasting forge password, their own forge write token for the gathered push.
- **Locked:** a developer the list dropped is told the host refuses them, and offered nothing to repair.
- **Red first:** a test that a `ca.pem` whose SHA-256 differs from `ca_sha256` is refused before the root step, and that no step runs before `project verify` answers.

## Acceptance

- A developer listed in the signed file joins with no file handed over and starts their agents there ([F148](README.md#f148)).
- A tampered `access.yml` or a wrong CA is refused before anything on the laptop changes.
- Seen to fail: the CA test red before the fingerprint is checked.
