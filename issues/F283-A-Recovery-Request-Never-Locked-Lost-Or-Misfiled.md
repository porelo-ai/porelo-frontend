# F283 — A Recovery Request Never Locked, Lost Or Misfiled

**Status:** Implementing.

**What must be true.** A key replacement or backup key kept here can always be finished or dropped, is never dropped
while Core may have made it or may still be running, never lets a new change through without a current read, and
never files against a base or a key the person did not review. Each harm is guarded by a test that goes red when it is
there.

Found on 2026-10-31 by the second and last independent reading of [F281](README.md#f281). Each point is still to be
checked against the code before it is fixed.

## To be fixed

1. **A failed check on an exit-0 answer drops the request.** When the first attempt exits 0 but its answer fails a
   check (another file path, as through a symbolic link, or a malformed fingerprint, scope or `pushed`), the check
   raises a refusal with code 0 that counts as proof that nothing was made. The receipt is forgotten, and the next
   attempt makes a second key or commit.
2. **Stuck for good:**
   - 2.1 A project replacement's receipt is never forgotten. The project's hosts always answer *pending*, so not
     every host is confirmed and the receipt stays. Every later replacement in that project resumes it, and neither
     Forget, Cancel nor Retry gets out of it.
   - 2.2 A made but unpushed registry commit whose push fails for good, or that is dropped by hand in Git, can never be
     finished or forgotten. A kept backup key then locks *Make a backup key…* for every list.
   - 2.3 An agent-key registry replacement that committed and lost its answer cannot be retried. The retry reads the
     already changed `owners.yml` and refuses, and readying the checkout refuses on the unpushed commit, before Core
     can be called with the kept ID.
3. **Forget or a second attempt while Core may run:**
   - 3.1 Making a backup key keeps no running state. While the save dialog or its terminal is open, the identity
     dialog's *Forget this attempt…* stays enabled. The same holds after the terminal times out on closing while Core
     still runs.
   - 3.2 On Windows, closing the terminal returns before Core has ended, so Forget is enabled while Core may still
     commit.
   - 3.3 *Use the backup key…* does not check that its terminal is already running. Two file pickers can start two
     Core terminals.
4. **A new change without a current read:**
   - 4.1 After a resumed attempt proves nothing was made, the reviewed replacement stays, and Confirm or the backup key
     files it under a new ID without a clean read. Only Review checks resume-only.
   - 4.2 *Make a new backup key…* in the recovery dialog passes a base, and so skips the resume-only check.
5. **A stale base:**
   - 5.1 The newest commit made here is taken as the base, but the people and roles still come from the old project
     view. A later replacement can show one old key and revoke another, because Core is given no old fingerprint.
   - 5.2 The kept base is never forgotten, not even on `base-moved`. A stale base is then handed out for good.
6. **Tests that stay green with their harm present:**
   - the exit-0 tests check only a malformed revision;
   - the file named in Core's answer is not checked through `makeBackupKey`;
   - the registry retry test stubs the checkout and the file read;
   - the newest-base test fakes the hosts, forgets the receipt by hand, and never makes a backup key;
   - the identity-view push-again test never closes its message, so the reload after the push is never seen.
7. In the recovery dialog's retry test, the backup file stays readable, so reading it would stay unseen.

## Built so far

- An exit-0 answer that fails a check, for a backup key's use or its making, is an answer not read: it keeps the
  request as uncertain, never as proof that nothing was made.
- Once Core was started, only its own refusal codes 64, 65 and 66 prove that nothing was made. A terminal put away,
  killed, or whose end was never seen keeps the request; only a terminal that never started Core leaves nothing. A
  program that outlives its terminal's close hands on its real exit code once it has ended.
- A pushed project replacement forgets its receipt at once: nothing of it can be made twice, and its hosts answer only
  *pending* here, which each host's line says. This was the smaller change than offering Forget once it is pushed.
  The dialog keeps saying what was done and offers no Retry; opened again on a project read older than it, it says the
  replacement was pushed as that revision, and *Make a new backup key…* stays offered.
- A pushed registry replacement that some host never confirms can be forgotten through a confirmation naming the
  hosts that have not confirmed it, to be checked by hand.
- A made commit not pushed, a replacement's or a backup key's, can be forgotten through a confirmation that names the
  commit and says it stays in the registry checkout, to be pushed or dropped there by hand; any other Forget of it is
  refused.
- A replacement of `owners.yml` or a host's access file keeps the file it hands Core in its receipt, made once before
  the first attempt. A retry hands Core the same file under the kept ID and base, skips the checks that need a clean
  registry read, and readies the checkout by accepting exactly one commit on that base that changes only that file to
  that content. A fresh filing still refuses any unpushed commit.
- A backup key being made counts as running from asking where its file goes until its terminal's program has ended:
  Forget, a second attempt and *Make a backup key…* wait meanwhile, in the identity dialog too. A terminal whose
  program outlives its close counts as running until the program ended, in the replacement dialog as well.
- What runs Core for a request is one shared state over the receipts, seen by every dialog however often it was
  opened again while it ran; the identity dialog reads the card again once a making it did not start has ended. In
  the registry checkout no replacement or backup key starts while another change runs there.
- A replacement's filing, its first attempt included, first checks against the registry as Core last read it that the
  commit in force is still the reviewed base and that the person's card holds the reviewed new key; otherwise it
  refuses, with nothing started: "The registry changed since the review; review again." A project replacement whose
  answer names another signer than the reviewed key is kept, never taken as made.
- *Make a new backup key…* is always made on the newest commit made here or the read's own base, never on an older
  one handed in.
- A retry readies the checkout only on its own commit: the registry's published commit is still its base, the commit
  has that one parent, changes exactly the one file (names read with `-z`) as a plain file (`100644`), and its blob is
  the file's exact UTF-8 bytes. Pushing a made commit again refuses unless the published commit is still its base. All
  of the checkout's Git calls run with `core.autocrlf=false`, and the content is compared by blob ID, so no line-end
  setting changes what is compared.
- On Windows, closing a terminal waits for its program to end, with the same bound as on Linux; past it the program
  counts as still running. The bound runs from before the console is let go; the program's job is ended before its
  console is closed; the end is said only once no process of the job is left, and when reading its output or waiting
  on it fails, it is watched until it is seen gone. A program still running when its session is put away is left to
  end, never an error.
- The backup key's file is asked once at a time, and its terminal does not open again while one is open.
- On a list known only from a kept request's record, nothing new is confirmed or used with the backup key, with or
  without a base handed in, and the review ends with the request.
- A project read older than a commit made here takes no new replacement: "Refresh the project before replacing a key."
  The base stays the read's own; a backup key is still made on the newest commit made here. That commit is forgotten
  on Core's `base-moved` and once a read is no longer the one it was made on.
- Tests for each, each seen red with the code broken on purpose: in `key_recovery_test`, `registry_checkout_test`
  against real Git, `terminal_close_test`, the dialog test (the backup file unreadable on disk, the earlier file's place
  said through `makeBackupKey`) and the identity view test (the card read again after the push, Forget held while the
  save dialog and an outliving terminal run; a new backup key held and the card read again after it, also in a
  dialog closed and opened again meanwhile).

## To be checked

- That the confirmation and the review's end both hold on a resume-only list: the review's end is proven by a test,
  while the confirmation's own refusal behind it cannot be reached through the controller once the review has ended.
- `ConPty`'s close is proven through the waiting it shares and its watching seam; the console, the job's end and the
  count of its processes run only on Windows and are not seen by any test here.
- A program behind the console (`wsl.exe`, `ssh.exe`) may keep running on the far side after the job has ended.
- Between the check against the review and Core's run, the registry may still move; Core's own `base-moved` covers
  that window.
- A `.gitattributes` line-end or filter rule in the registry is not looked at: the blob compared is the content's own
  bytes, so such a rule makes a retry refuse rather than accept another commit.
- The check against the review uses the registry as Core last read it, refused while a read runs; it does not read the
  card file itself.
- A registry replacement kept by an earlier version holds no file; its retry reads `owners.yml` again and is refused
  once its commit changed it, leaving Forget as the way out.
