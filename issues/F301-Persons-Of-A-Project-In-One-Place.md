# F301 — Persons Of A Project In One Place

**Status:** Idea.
**Severity:** high.
**Size:** L - the project page's persons section, a redesign of the developers dialog, and the registry persons, with
their tests; no contract with another repository.

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

The developers dialog itself, opened in the walk after it was put back on the menu (michi: "Das ist völlig unklar. Der
Dialog ist nicht gut => Redesign"):
- It opens frozen for several seconds, every control locked, with no sign that it is loading.
- Its field "Registry person" reads as "choose a registry"; it is the person to add.
- The radio list of current members sits between that field and *Add a developer*, so michi picked michael-schnell
  there and expected *Add* to add him.
- Four disabled buttons, each "not connected to Core and the host yet", crowd it.

The operator's decision (2026-11-01, in the sprint 6m walk): machines and projects are two separate processes. Who belongs
to a project is edited on the project and names no host; a host follows its projects' state by itself, and no step of
a project's edits reaches into a host.

## The shape

- The page's *Persons* section reads the project's verified access (`ProjectAccess`), shows each developer with
  role, lock state and the host's state, and offers *Add a developer…*, *Lock*, *Let back in* and *Remove* as the
  dialog does today.
- The registry admission's members, where the host is watched, are a line under the host's own row, not a second
  persons list.
- The dialog is replaced by the page's section: the members as a list with each one's actions on the member's own row
  (⋮), and *Add a developer…* as one button that opens a picker titled "Add a developer to <project>" with a search
  over the directory's persons, those already in the project shown and not pickable.
- The section shows a loading line while Core reads the access file; nothing is locked while it reads.
- An action that cannot run now is hidden, or said once for the section ("Changes need Core's verified access; it is
  being read"), never as a row of disabled buttons with the same words.
- As machines and projects are separate, adding a developer files and publishes the access change only; no step of it connects to a host,
  and the hosts the project is on follow by themselves.

## Plan

- `lib/src/ui/registry_persons.dart`, `lib/src/ui/project_developers_dialog.dart`, `lib/src/ui/shell.dart`
  (`_openDevelopers`), `lib/src/app/project_developers.dart`.
- **Red first:** a widget test of a project followed here and registered on a host: its page on this machine shows
  the project admin under *Persons* and *Add a developer…* enabled for a project admin.

## Acceptance

- A project admin finds *Add a developer…* on the project's page without opening a menu.
- The project's persons read the same on each machine the project is on.
- Related: [F300](README.md#f300) (one entry per project).
