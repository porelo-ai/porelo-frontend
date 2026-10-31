# F281 — A Kept Recovery Commit Finished, Not Made Again

**Status:** Idea.

**What must be true.** A key replacement or backup key that Core has committed but not pushed is finished by trying
again under the same request, never made a second time and never blocked by its own unpublished commit; the next
project action after a replacement starts from the new revision; and each harm is guarded by a test that goes red
when it is there.

## Built so far

- Built on 2026-10-31, the same night it was found. After an uncertain end, a request is kept through a cancelled,
  refused or mismatched retry, both for a key replacement and for a backup key.
- A backup key whose commit was kept but not pushed stays offered in the identity dialog as *Push the backup key
  again…*.
- A replacement or backup key kept here is resumed from its own receipt when the registry read refuses.
- *Make a new backup key…* after a project replacement starts from the replacing commit.
- Core's `not-in-this-release` is shown in its words and nothing is kept.
- Tests for each, each seen red: through the dialog and its commands, with a real unreadable backup file, and with
  the receipt read while it is still stored. Also a test that `owners` is handed to Core as `--file`.

## To be checked

- A host-access replacement opened from the registry persons page may be hidden by that page's own gate after a
  restart.
- A registry replacement through the agent key whose answer was lost has no commit to push yet. Its Retry still
  needs a clean registry read.
- A first attempt put away while Core may already be pushing still forgets its request.
- Making a backup key from the identity dialog after a project replacement reads the project view, which nothing
  refreshes yet. Core refuses `base-moved` and nothing is made.
