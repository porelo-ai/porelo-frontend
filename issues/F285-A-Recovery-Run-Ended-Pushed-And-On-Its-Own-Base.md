# F285 — A Recovery Run Ended, Pushed And On Its Own Base

**Status:** Implementing.

**What must be true.** A key replacement or backup key always gets its running state back when its dialog goes away. A
commit of its own that already reached the registry is finished, never refused for good. A project backup key is made
on the project repository's own commit. A project replacement files exactly the card that was reviewed, and no
registry write runs in the checkout beside it. Closing a terminal never freezes the window or hangs for good, and never
loses the program's last answer. Each harm is guarded by a test that goes red when it is there.

Found on 2026-10-31 by the second and last independent reading of [F283](README.md#f283). Each point was checked
against the code before it was fixed.

## To be fixed

1. **Running for good:**
   - The recovery dialog can be closed with Escape while a backup-key start is being prepared. The run is then marked
     as started but never ended, which locks Forget, Retry and every registry recovery until a restart.
   - If the dialog goes away while a new backup key is being prepared, the receipt stays uncertain although no terminal
     ever opened.
2. **Already pushed:**
   - When the request's own commit already reached the registry (pushed before a crash, or by hand) and was fetched,
     `publishMade` refuses it for good. The hosts are then never told, and Forget says the commit is unpushed.
   - A project backup key's commit is kept as made on the access repository's base, so a project replacement stays
     refused after every refresh.
3. **Filed as reviewed:**
   - A project replacement hands Core the card's path in the registry checkout, and a refresh can change that file after
     the check. Core's answer names no key, so the check on `by` never runs.
   - Recovery runs and the registry's own filings and refreshes do not exclude each other in the same checkout.
4. **Wrong base for a project backup key:** `--base` is the access repository's commit, but Core compares it with the
   project repository's head, so it is always `base-moved`. That refusal also forgets the kept commit made here. With no
   access revision read, the kept commit is forgotten as well.
5. **Windows close:**
   - When ending the job fails, or no job exists, the console is closed on the UI isolate and can freeze the window.
   - The waiter can hang for good on a closed job handle, or crash on a second read.
6. **Other terminals:**
   - Output printed while a terminal closes is lost, so the last answer is taken from an earlier line.
   - The key dialog reports exit -1 for a key made during close.
   - `TerminalStillRunning` goes uncaught when the navigator goes away while a terminal is open.
7. **Tests that stay green with their harm present:**
   - the project replacement test fakes a `by` field Core never sends;
   - the Windows close test blocks before it measures;
   - the cancel test's channel cannot tell a code from none.

## Built so far

- The replacement dialog cannot be put away by a pop from outside it while a backup key's use is readied or its
  terminal is open, and its Close is held meanwhile; Escape never closed it, as its barrier is not dismissible. Every
  path that marks a backup key's use started ends it: a dialog that went away, or a terminal that threw, ends it as
  never started when no terminal opened, and as uncertain when one did. A backup key's making whose window went away
  before its terminal opened ends as never started, which restores its request as it was before.
- Pushing a made registry commit fetches first and is done, with nothing pushed, when the published branch holds it
  already, as that commit or one before the tip; it is refused only when the branch moved on without it. Forget's
  confirmation of a made commit not pushed from here says that Retry pushes it or finds it pushed, and names the hosts
  it then tells.
- A project replacement hands Core a private copy of the card, never the checkout's file: read once right after the
  check, its key compared with the reviewed one, kept with the request, and written for each attempt into a folder of
  its own only this user reaches, removed once Core ran. A card file naming another key refuses the replacement with
  nothing started. The check on a `by` field Core never answers is gone, and so is its test.
- Key recovery runs and the registry's own reads and filings exclude each other through one hold on the registry:
  a run takes it before it checks, readies or files, and lets go once its program ended; a hold is refused with words
  while a read or filing runs, a filing is refused with words while a run holds it, and a refresh waits for the
  release. A retry of a lost answer and a backup key's making take the same hold.
- A project's backup key, made or used, is made on the project repository's own commit: a list read carries it as the
  backup key's base, the newest made here on that read. Its commit is kept apart from the access file's, so neither
  holds the other's replacements, and Core's `base-moved` for a backup key forgets only the project repository's.
- On Windows, a console whose job could not be ended, or that has none, is closed on an isolate of its own; the job's
  handle stays open for the waiter until the program's end was seen; the waiter reads each answer once; and a waiter
  that fails after it started counts as still running, while the program is asked for every poll on this side.
- A session that is left keeps reading its terminal until the channel has closed or its bound passed, so a program's
  last answer printed while it closes is the line read. The key wizard takes the exit code the terminal saw, also one
  seen while it closed. A terminal whose window goes away while its program still runs raises nothing unhandled.
- The tests that stayed green with their harm present now fail with it: the close bound is measured from before
  letting go without blocking, and the cancel test's terminal ends with a real code, with tests for an answer printed
  while closing and for a terminal that never started.

## To be checked

- Point 4's third harm, a project read with no access revision forgetting the kept commit, cannot happen today: a
  project view's access and project revisions are both non-nullable, and no view means no read at all. Nothing was
  changed for it.
- The Windows changes are tested through their seams only; closing a console on its own isolate and the waiter's
  failure report still want a run on Windows.
