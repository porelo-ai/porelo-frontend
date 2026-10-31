# F281 — A Kept Recovery Commit Finished, Not Made Again

**Status:** Idea.

**What must be true.** A key replacement or backup key that Core has committed but not pushed is finished by trying
again under the same request, never made a second time and never blocked by its own unpublished commit; the next
project action after a replacement starts from the new revision; and each harm is guarded by a test that goes red
when it is there.

## To be checked

- From the second reading of [F280](README.md#f280) (2026-10-31), all in `lib/src/app/key_recovery.dart`,
  `lib/src/ui/key_recovery_dialog.dart`, `lib/src/ui/identity_view.dart` and `test/app/key_recovery_test.dart`:
  - An uncertain end (exit 69, 70, or 0 with an unreadable answer) followed by a cancelled, mistyped or refused retry
    (-1, 64, 65, 66, or `backup-only-own`) clears the kept request id: the next attempt mints a new `--id` and makes
    a second commit or backup key. `KeyRecovery.uncertain` is written and never read; `BackupKeyMaking` keeps none.
  - *Make a backup key…* in the identity dialog disables itself after a local commit that did not push, because
    `identity show` already omits the scope from `sole_without_backup`; the kept `backup-make/<scope>` receipt must
    keep it offered as *Push it again*.
  - After a restart or a registry refresh, a kept unpublished registry commit makes `KeyRecoveryServices.situation`
    refuse with "Refresh the registry …", and the refresh refuses on that same commit: nothing can publish it.
  - After a project replacement, `projectView` is not refreshed, so *Make a new backup key…* passes the old `--base`
    and Core refuses `base-moved`.
  - Tests that stay green with the harm present: the kept receipt checked for the backup file's path only after it
    is forgotten; the review-before-terminal and told-in-person rule tested on the controller only (no dialog or
    command test); no `CliRegistryCore.file` test for `owners … --file`; the "path kept nowhere" test against stubs
    whose strings can never hold it.
