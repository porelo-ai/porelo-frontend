# F393 — A Project File Is Changed By Its Admin

**Status:** Review.
**Size:** M - one source's commands and the dialogs that asked them: the entry shown instead of a signed change.

**What must be true.** Where a person adds, changes or removes a project's repository, changes its review policy, or fills a project from a checkout, the window shows the entry Porelo says to write, the file it goes in, and a way to copy it; the project admin commits it. Nothing is signed or written by the window or by Porelo for it.

## Why

Porelo no longer changes a project file that exists: `project repository add|change|remove` and `project review` answer `by-hand` with exit 65 and the entry, `project init` answers the entry and refuses `--yes`, and none of them takes `--base` or `--id`. The window asked all of them as signed writes against a revision, so each one was refused, and the person saw a bare refusal with no entry to write.

## Plan

Agreed with Agent Core: every `by-hand` answer carries `entry`, the YAML to write; `words` is for a person and is never cut apart. `project init` without `--yes` answers `entry` with exit 0.

- `lib/src/app/organization_source.dart`: `OrganizationChange.byHand` marks the five changes; `ProjectFileByHand` holds the project and its entry; `OrganizationRefused.entry`; `ProjectInitDraft.entry`, its `revision` no longer required; `Organization.entryFor` asks for the entry without an id, a revision or a provisional row, as nothing is written.
- `lib/src/app/porelo_organization_source.dart`: the five changes are asked with no `--yes`, `--base` or `--id`; a `by-hand` refusal with an entry, or `project init`'s answer with one, becomes `ProjectFileByHand`; one with no entry is said in Porelo's words.
- `lib/src/ui/project_file_entry.dart`: the entry verbatim, the file, a copy button, and that the project admin commits it signed.
- `lib/src/ui/organization_dialogs.dart`: a by-hand change shows the entry in its dialog, which then only closes.
- `lib/src/ui/project_init_dialog.dart`: the draft and its warnings beside the entry; no signing.
- `lib/src/ui/organization_project_pages.dart`: the four dialogs say that Porelo changes no project file, and their button is *Show the entry*.
- Red first: `test/app/porelo_organization_source_test.dart` and `test/app/project_init_test.dart` that no `--yes`, base or id is sent and the entry is read; `test/ui/project_init_dialog_test.dart`, `test/ui/organization_project_pages_test.dart` that the entry and its file are shown, a refusal shows none, and a repository asked to be removed stays listed.

## Acceptance

- None of the five changes sends `--yes`, `--base` or `--id`.
- Each shows the entry exactly as Porelo gave it, the file it goes in, and a copy button, or for a removal Porelo's words of what to take out; nothing is shown as written.
- A refusal is said in Porelo's words, with no entry beside it.
- Creating a new project's repository and every other organization change are still signed as before.

## Decided while building

- An older Porelo that wrote the change itself answers the revision it wrote: that is taken as written, the organization and the open project are read again, and nothing is asked twice.
- `project repository remove` has nothing to write and answers no `entry`: Porelo's words say what to take out, shown as an instruction, not as a refusal.
- From the reading: all its findings are fixed, each with a test seen red first (an older Porelo's write read as refused, the open project not read again, an entry for an edited form shown, `write` swallowing an entry, the repository rows and remembered review choice still treated as signed, a draft's failure worded twice and of signing, base and id not checked empty, a draft with no entry untested). `OrganizationChange.initializeProject` stays a by-hand change the dialog no longer asks through `apply`, so that nothing can ever sign it; its source tests stay.

## To be checked
