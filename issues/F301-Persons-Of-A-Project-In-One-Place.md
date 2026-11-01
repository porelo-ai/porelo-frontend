# F301 — Persons Of A Project In One Place

**Status:** Idea.
**Severity:** medium.
**Size:** M - the project page's persons section, the developers dialog and the registry persons, with their tests;
no contract with another repository.

**What must be true.** A project page shows one *Persons* section: the project's developers and admins as the access
file Core verifies names them, with *Add a developer…* beside its heading for a project admin. It shows the same on
every machine the project is on, not only on the host whose registry admission it holds.

## Why

Seen in the sprint 6m walk (2026-11-01, step 18):
- michi, the project's admin, opened sprint6m-demo "on this machine" and found "Persons (0) … Verified access state
  has not been supplied" and no *Add a developer*.
- That section (`lib/src/ui/registry_persons.dart`) lists the *registry admission's* members. `RegistryReadSource`
  attaches an admission only to the watched machine of its host, so the page on this computer never has one.
- The project's developers, with *Add a developer*, live in a dialog behind ⋮ → *Project settings: Developers…*
  (`lib/src/ui/project_developers_dialog.dart`), which nothing on the page points to.

## The shape

- The page's *Persons* section reads the project's verified access (`ProjectAccess`), shows each developer with
  role, lock state and the host's state, and offers *Add a developer…*, *Lock*, *Let back in* and *Remove* as the
  dialog does today.
- The registry admission's members, where the host is watched, are a line under the host's own row, not a second
  persons list.
- The dialog stays reachable from ⋮ for keyboard use, or is folded into the page.

## Plan

- `lib/src/ui/registry_persons.dart`, `lib/src/ui/project_developers_dialog.dart`, `lib/src/ui/shell.dart`
  (`_openDevelopers`), `lib/src/app/project_developers.dart`.
- **Red first:** a widget test of a project followed here and registered on a host: its page on this machine shows
  the project admin under *Persons* and *Add a developer…* enabled for a project admin.

## Acceptance

- A project admin finds *Add a developer…* on the project's page without opening a menu.
- The project's persons read the same on each machine the project is on.
- Related: [F300](README.md#f300) (one entry per project).
