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
- A request is kept as uncertain before Core runs, for a replacement and a backup key alike. A crash while Core runs,
  an exit-0 answer that fails the checks, and a registry filing's exit 69 or 70 all keep it. An answer proving this
  attempt made nothing restores what was kept before the attempt.
- Core's `base-moved` or `not-in-this-release` drops even an uncertain request: no commit exists under its ID.
- *Forget this attempt…* drops a kept uncertain request on the person's word, after a confirmation that names the
  request and says what may already be committed and must be checked by hand. It is in the replacement dialog and,
  for a kept backup key, in the identity dialog; a made commit owed its push is never forgotten.
- A retry of an uncertain backup key takes the file an earlier attempt wrote and says where it is; a first attempt
  still refuses another file.
- A list known only from a kept request's record finishes that request and allows no new review or new backup key.
  A kept backup key whose record does not read is not offered as *Push the backup key again…*.
- *Retry with the backup key…* is disabled with its reason where the terminal cannot open.
- A project read before a replacement or backup key made here starts from the newest commit made here on that read.
- Tests for each, each seen red with the code broken on purpose: in `key_recovery_test`, `registry_cli_core_test`,
  the dialog test (reached through `showKeyRecovery`, `showRegistryKeyRecovery` and `makeBackupKey`, a stolen key's
  file picked, a real backup file on disk and the picker's folder recorded) and the identity view test through the
  real entry and settings.

## To be checked

- A host-access replacement opened from the registry persons page may be hidden by that page's own gate after a
  restart.
- A registry replacement through the agent key whose answer was lost has no commit to push yet. Its Retry still
  needs a clean registry read; *Forget this attempt…* is the way out.
- A first attempt put away while Core may already be pushing still forgets its request.
- A registry filing refused without Core's exit code, such as Porelo not installed, keeps its request as uncertain
  until it is retried or forgotten.
