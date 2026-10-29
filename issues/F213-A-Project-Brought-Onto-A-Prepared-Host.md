# F213 — A Project Brought Onto A Prepared Host

**Status:** Implementing; blocked by [F208](README.md#f208), [F211](README.md#f211) and [F214](README.md#f214).
**Size:** L - a dialog of its own in the project admin's account, the access repository's checkout and its signed `host:` block, on contracts with two repositories.

**What must be true.** A project admin puts their project on a host they were admitted to, renting nothing: the interface writes the host's values and the project's Matrix settings into the project's private, signed `access.yml`, runs the bring in their own account with no `sudo`, feeds its stop from their own secrets file, and the project's room is made; taking the project off is refused while anything is unpushed.

## Why

Decided: bringing a project is the project admin's act in their own account; `host:`, `developers:` and Matrix's settings live in a second signed file in a private repository, so the public `project.yml` names none of it.

## Plan

- ***Put this project on a server…*** (`project-admin`, `Home.projectMenu`) chooses among hosts this person was admitted to; *The project* step stays, *Where it is rented* goes.
- **The access checkout:** cloned with the person's own git credentials from `access.repository` of the signed `project.yml` into `~/.local/share/porelo-frontend/access/<project>/` (`0700`); never into a log or a support bundle.
- **The `host:` block and Matrix's settings** written into `access.yml` with `yaml_edit` (kept comments), from the values the host admin gave ([F211](README.md#f211)); committed and signed with the person's own git, pushed; the interface signs nothing itself and refuses where git's signing is not set up.
- **The bring:** `ansible-playbook -c local porelo.host.bring -e porelo_project=<project>` over the admin's own ssh, `machine.yml`, `project.bundle`, and `access.bundle` uploaded into their own `~/.local/share/porelo-host/setup/<project>/` ([F214](README.md#f214)), its stop in own-account mode fed from their secrets file: `vault-new` or `vault`, `keys`, `forge-central-token` while a repository is to migrate. It ends with one `sync`.
- **The repositories, agreed with porelo-host:** the bring loads each one as a Forgejo migration from the central
  forge, which keeps its `original_url`; `porelo-host-project remove` compares each repository with that URL and
  refuses only while a commit is on the host and nowhere centrally. The interface gives `remove` only the central
  token on standard input, never a central URL.
- **The room:** through the daemon's room call of `porelo`, shown as made.
- ***Take this project off the server***: refused in the helper's words while anything is unpushed; then unfollowed; the organization's deletion is the host admin's ([F211](README.md#f211)).
- **Red first:** a widget test that the dialog offers no renting and runs the bring with no `sudo`, against stand-ins for `porelo-host` and git.

## Acceptance

- A project brought onto a host prepared by another person, by its admin alone, follows there in the admin's account, with its room made.
- The public `project.yml` holds no address, key or name of a person; `access.yml` holds them, signed.
- *Take the project off* is refused while a repository holds an unpushed commit, and green once it is pushed.
- Seen to fail: the widget test red while the dialog still rents.

## To be checked

- `porelo`'s exact commands once their issues are written.
