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
- Pushing a made registry commit fetches first and takes nothing from a commit whose only parent is not its own base,
  the base itself included. It is done, with nothing pushed, when the published branch holds it on its first-parent
  line, the only one Core reads, as that commit or one before the tip; a commit merged in beside that line is not
  taken, and a commit of the checkout above it is refused with words, as it would go with the next push. It is refused
  when the branch moved on without it. Forget's confirmation of a made commit not pushed from here says that Retry
  pushes it or finds it pushed, and names the hosts it then tells.
- A review keeps the new card's exact text as the checkout held it when the list was read, read only while no
  registry read, filing or run moves the checkout. A project replacement and a backup key's use hand Core a private
  copy of that card, never the checkout's file: read once right after the check, compared with the reviewed text, not
  only its key, kept with the request, and handed again on every retry, also after a restart. A card for the reviewed
  key that is another card, such as one naming a predecessor, refuses the run with nothing started. A request kept
  before its card was is retried only while the list still reads as reviewed and the checkout's card is the reviewed
  one; otherwise it is refused with words, and Forget is the way out. The check on a `by` field Core never answers is
  gone, and so is its test.
- Each copy is written into a folder of its own made private at its creation, its file created exclusively and
  restricted before its text is written, on Windows too. It is removed once Core ran, and a removal that fails never
  throws over Core's answer; a folder a crash left behind is swept when the next copy is made.
- Key recovery runs and the registry's own reads and filings exclude each other through one hold on the registry,
  taken by a token made for each run and let go of only by that token. A replacement holds it from its check to the
  end of its push and delivery, a backup key's use until its program ended and its answer was read, pushed and
  delivered, and counts as running as long; a backup key's making holds it for its whole attempt, whose start, end and
  push take no hold of their own. A project's run never holds it, as it never writes the checkout. A run reads the
  registry again one read after another, before the refresh that waited for its release. A hold is refused with words
  while a read or filing runs, a filing is refused with words while a run holds it, and a refresh waits for the
  release; a check of a reviewed card refuses while another run holds the checkout. Filing the person's card, changing
  their key and publishing that change take the same hold, and refuse with its words while a run holds it.
- A project's backup key, made or used, is made on the project repository's own commit: a list read carries it as the
  backup key's base, the newest made here on that read. Its commit is kept apart from the access file's, and Core's
  `base-moved` for a backup key forgets only the project repository's. A replacement its backup key made is read back
  from that record as made here, so the dialog shows its commit and the key it replaced, and no new replacement is
  reviewed until the project's own repository is read again.
- On Windows, a console whose job could not be ended, or that has none, is closed on an isolate of its own; the job's
  handle stays open for the waiter until the program's end was seen; the waiter reads each answer once; and a waiter
  that fails after it started counts as still running, while the program is asked for every poll on this side. A job
  that cannot be asked leaves the program's end to its own handle. A console counts as closed only once it was, and
  one whose close on its own isolate failed is closed on this isolate after the close's bound. A reader isolate that
  dies counts as drained. The first pipe is closed when the second cannot be made, the input once the program ended,
  and a throw while the program is asked for or its console closed counts as still running.
- A session that is left keeps reading its terminal until the channel has closed or its bound passed, so a program's
  last answer printed while it closes is the line read; it takes no link, copy or forward from it, and is quiet once
  disposed. The key wizard, the forge token, the provider key and the provider sign-in take the exit code the terminal
  saw, also one seen while it closed. A terminal whose window goes away while its program still runs raises nothing
  unhandled.
- The tests that stayed green with their harm present now fail with it: the close bound is measured from before
  letting go without blocking, and the cancel test's terminal ends with a real code, with tests for an answer printed
  while closing and for a terminal that never started. The recovery tests' Core holds the registry checkout as the
  registry does and refuses a change or push without the hold, and every test that ended its runs checks that nothing
  stays held and no card copy stays behind. The card copy's folder and file are checked as they are made, and a made
  commit is tried as the base, as a commit before it, merged in beside the first-parent line, and with a commit above
  it.

## To be checked

- Point 4's third harm, a project read with no access revision forgetting the kept commit, cannot happen today: a
  project view's access and project revisions are both non-nullable, and no view means no read at all. Nothing was
  changed for it.
- The Windows changes are tested through their seams only; closing a console on its own isolate, the waiter's failure
  report and the reader's end still want a run on Windows. A reader isolate that dies before its first read still
  leaves its output handle open.
- A backup key made here in a project's own repository that replaced no key does not hold a new review: the people
  and roles a replacement is reviewed on are the access file's, which that commit does not change. Only one that
  replaced a key does.
- A key change in a KeePassXC terminal lets go of the registry checkout once its terminal returned, which may be
  before its program ended when the window was put away.
- The sweep of card copies left behind takes every `porelo-card-` folder of this user that this program is not using,
  so a second instance of the program running a replacement at the same moment could lose its copy; Core then cannot
  read the card and makes nothing.
- A request kept by the first build of this issue, with its card but without the review's card text, is compared by
  the card's key alone.
