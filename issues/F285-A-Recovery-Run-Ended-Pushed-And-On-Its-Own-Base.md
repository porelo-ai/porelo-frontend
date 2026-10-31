# F285 — A Recovery Run Ended, Pushed And On Its Own Base

**Status:** Idea.

**What must be true.** A key replacement or backup key always gets its running state back when its dialog goes away. A
commit of its own that already reached the registry is finished, never refused for good. A project backup key is made
on the project repository's own commit. A project replacement files exactly the card that was reviewed, and no
registry write runs in the checkout beside it. Closing a terminal never freezes the window or hangs for good, and never
loses the program's last answer. Each harm is guarded by a test that goes red when it is there.

Found on 2026-10-31 by the second and last independent reading of [F283](README.md#f283). Each point is still to be
checked against the code before it is fixed.

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
