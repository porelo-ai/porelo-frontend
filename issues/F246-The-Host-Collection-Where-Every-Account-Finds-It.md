# F246 — The Host Collection Where Every Account Finds It

**Status:** Accepted.
**Size:** S - `up` installs the collection read-only for every account on the host, so a person's own bring and join run the version root's `up` ran.

**What must be true.** After `up`, the host's `porelo.host` collection is installed in a place every account's `ansible-playbook` finds without settings: root-owned, readable by all, writable by root alone. It is the version `up` checked by its digest. A project admin's own-account `porelo.host.bring` and a developer's `porelo.host.join` find it there, and run exactly that version.

## Why

Walk 23 on walk9server (2026-10-30), the own-account bring on VM A: "[ERROR]: the playbook: porelo.host.bring could not be found". `HostRun` (`packages/porelo_host/lib/src/host_run.dart`) installs the collection only under `/var/tmp/porelo-host/collections`, and runs root's plays with `ANSIBLE_COLLECTIONS_PATH` pointing there. A person's login sees `~/.ansible/collections` and `/usr/share/ansible/collections`, neither of which holds `porelo.host`. Walk 23 was the first walk to reach the own-account bring. For the walk, Agent Coordinator copied the installed tree into walkadmin's own `~/.ansible/collections`.

## Plan

- `up` installs the checked collection with `ansible-galaxy collection install --force -p /usr/share/ansible/collections`, as root. Its tree is root-owned, directories 0755 and files 0644. Root's own plays run with that path.
- The plays leave root's files in the collection today. Whether they still need to write there, Agent Machines says; where they do, those files go to `/var/lib/porelo-host` instead, and the collection stays read-only.
- The copy under `/var/tmp/porelo-host/collections` is no longer made; a second `up` replaces the installed one, as now.
- The bring and join keep running `ansible-playbook -c local porelo.host.bring` (or `join`) as the person, with no path set: the default finds it.
- **Red first:** a test that `up`'s install command names `/usr/share/ansible/collections` and its play the same path; a test that the bring's command sets no collections path.

## Test

Only the change: the tests above and `porelo_host`'s own tests. The VM test covers only an own-account `ansible-playbook --syntax-check porelo.host.bring` after `up` on the walk's host.
