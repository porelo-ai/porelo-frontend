# F131 — A Host Brought Up And Down By One Command

**Status:** Implementing.
**Size:** L - a new pure-Dart package and its command line, with the run, the stop and the
resume, proven against a real machine.

**What must be true.** A person types `porelo-host up <project>` on Linux or Windows, and a
host is rented, set up by the playbook and running the project's tasks. It stops once for the
person, and a second `up` goes on from there. `porelo-host down <project>` takes the last copies
and gives the host back. Each step is one line a program reads; the interface ([F135](README.md#f135)) is such a
program and does no step of its own.

## Why

[PJ40](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj40) puts a whole
project on a server with one command. By the operator's decisions the command is not Porelo's,
since Porelo does not run on the person's computer before the host exists and does not run on
Windows at all. The playbook ([porelo-host](https://github.com/porelo-ai/porelo-host))
runs on the host itself, so the person's computer needs only this command and ssh.

## Plan

- **A package of its own, `packages/porelo_host/`, pure Dart** (no Flutter), so the interface
  imports it and `dart compile exe` builds `porelo-host` from `bin/porelo_host.dart`. It shells out
  to the system's `ssh` and `scp` only, as `lib/src/app/tunnel.dart` already does, with
  `BatchMode=yes`.
- **`HostProvider`, one interface:** `create(name, tags, userData, sshPublicKey)`, `state(id)`
  (address, host key, running or not), `release(id)`. [F132](README.md#f132) is the Scaleway adapter. A second
  adapter, `GivenMachine`, rents nothing and names an existing address. It exists for the tests and
  for a person who has a machine already.
- **The inventory, split as decided:** the package writes the first play's part, the host's
  address, the account and the packages, none of it from `project.yml`. Porelo on the host writes
  the second play's part, as [B208](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b208) now says.
- **The run of `up`**, each step a JSON line on stdout, relayed from the collection's callback
  plugin, which writes one line per Ansible step into a file the package names, `{"step": "...", "state":
  "started|done|refused", "fix": "..."}`, with words for a person on stderr:
  1. rent, tagged with the project, unless a host tagged so already runs;
  2. wait for ssh, with the host key the provider reports pinned in a `known_hosts` of the
     package's own, never a keyscan (as [F128](README.md#f128) does for the leased leg);
  3. copy the collection's tarball and the inventory with `scp`;
  4. `apt-get install ansible-core` and `ansible-galaxy collection install`;
  5. `ansible-playbook -c local -i <inventory> porelo.host.up`, every play on `localhost`;
  6. **the stop:** one line `{"step": "person", "state": "waiting", "needs": ["drive",
     "vault"]}` and exit code **75**, taken from the second play's first check, which stops the
     play. `ansible-playbook` exits 2 there as on any failed task, so 75 comes from that line,
     never from the exit code alone;
  7. a second `up` finds the host by its tag, and the first play's steps are already done. It
     sends what the person gives on its own stdin on to `tresorit-cli login --password-on-stdin`
     and `porelo vault unlock --passphrase-stdin` over ssh. It never writes them anywhere, then
     runs the second play.
- **`down`:** the down play (the copies, then `vault clear --yes`), then `release`.
- **Exit codes:** 0 done, 75 waiting for the person, 65 refused with its `fix`, 69 the provider
  or the host unreachable.
- **The red test first:** a unit test with a fake provider and a fake ssh that holds the order,
  the stop's line and code, and a second `up` that does not rent again. It is run red with the
  resume taking the steps from the top.

## Built so far

- `packages/porelo_host/`: `HostProvider` and `GivenMachine`, `OpenSsh` with a `known_hosts` of
  its own, `HostRun` with `up`, the stop, the resume and `down`, and the command
  `bin/porelo_host.dart`. Seven unit tests, each seen red with its rule broken: a second `up` that
  rents again, the stop taken from the exit code, a secret in a command line, a wrong host key
  asked again.
- `tool/vm-run.sh`: a throwaway Ubuntu 26.04 VM on this machine's libvirt, `porelo-frontend-host-*`,
  with the stand-in collection `test/stub_collection/`, which keeps the contract: two plays, the
  waiting line, the callback `porelo.host.lines`. Green, nothing left in libvirt after.
- Measured on a fresh host and built in:
  - sshd may refuse for a while after the host is ready, so ssh is asked again, but never on a
    wrong host key;
  - a fresh image has no package lists, and cloud-init may hold apt's lock;
  - Ansible refuses a locale that is not UTF-8, and ssh brings this computer's along, so the host's
    commands run under `C.UTF-8`;
  - Ubuntu 26.04's sudo (sudo-rs) ignores `-E`, so the environment goes through `env`;
  - the collection is installed as root, since the plays leave root's files in it.
- Left for porelo-host's own plays (HO02, HO09): the run against the real collection.

- The tarball is taken only by its digest: [F137](README.md#f137).

## Acceptance

- The whole `up`, the stop, the resume and `down` run against `GivenMachine` on the test VM
  `ubuntu26.04` with porelo-host's collection, measured and named. Then the same against one
  rented host through [F132](README.md#f132), on the operator's word.
- Seen to fail:
  - a host key that differs from the provider's is refused before any login;
  - a second `up` rents nothing;
  - a wrong passphrase ends with 65 and the vault's own words;
  - nothing of the passphrase is in any file, log or argument (`ps` and the logs read).

## To be checked

- With Agent Machines: the callback's line fields and the inventory's names and version, once
  HO09 has them. Agent Machines read the order, the command and the resume as a plain second run
  of both plays, and they fit.
