# F364 — Repositories Added Before A Machine

**Status:** Implementing.
**Size:** S - the add dialog names `central` always, and a row with none says so.

**What must be true.** A person's natural order is repositories first and a machine later, and that order works. In the foo test, `foo-1` and `foo-2` were added in the window before any machine carried the project.

## Why it fails today

- **The window sends a `central` only with a local address.** `OrganizationView.localAddress` is null for a project on no machine, or on a machine whose card names no port, so *Add a repository* sends `--upstream` with what was typed and no `--central`.
- **A host takes nothing from such a row.** The follow skips it with no refusal, and the project still reads as carried. The first sign comes when a task starts on it: "names no central address, so this host has no copy of it".
- **Nothing says so.** *Put it on a machine…* neither mends the rows nor warns, and neither the window nor `project show` names a row's `central`, so a person cannot see the difference.

## The shape

- **Adding always names `central`.** With no machine yet it is the address typed, in both `upstream` and `central`; on a machine it stays as today. A row with a `central` needs no refiling when it comes to a machine, so no port has to be known and the order stops mattering.
- **A row that has none says so,** on the project's page, with one way to mend it. Rows filed by an earlier build stay until mended.
- **Mending a row needs no remove and add.** `ProjectFile` can write a row's fields, and whether a command offers that is to be read.

## Plan

1. *Add a repository* names `central` always: the address typed where no local address is known.
2. A row with none says so on the project's page, once `project show` gives a row's `central`, which the window cannot read today.

## Acceptance

- A repository added on a project with no machine is filed with its `central`. Seen to fail first.
- A repository added on a project on a machine with a known port is filed as today.
- A row with no `central` says so on the project's page, and says what to do.
- On a machine, rows filed before it came are taken over by the first refresh, with no second one.

## To be checked

- That a `central` written as an https address is taken by a host, read but not run.
- What `project show` should answer so that the window can see a row's `central`, which is Core's to say.
- How a row added once the project is on a machine reaches the host, as the follow reads the file on the host's forge.
