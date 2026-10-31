# F286 — A Recovery Hold Never Stuck And Its Commit Its Own

**Status:** Implementing.

**What must be true.** A key replacement or backup key never holds the registry checkout for good. Its made commit is
taken as done only when it is the request's own, and a commit Core made on a newer base is still finished. The card
handed to Core is the reviewed one, copied privately and always removed. A project backup key's records follow the
repository each one lives in. Closing a terminal neither hangs nor leaks, on Windows too. Each harm is guarded by a
test that goes red when it is there.

Found on 2026-10-31 by the second and last independent reading of [F285](README.md#f285). Each point is to be checked
against the code before it is fixed.

## To be fixed

1. **Registry hold:**
   - A terminal dialog whose navigator goes away never returns from `showDialog`. The hold, the running mark and the
     card copy then stay for good, and every refresh waits forever.
   - A registry terminal put away whose program never ends keeps the hold with no way out.
   - Choosing another registry address makes a new, unheld `Registry` on the same checkout while a run holds the old
     one. `identity rotate` and `publish` commit into every checkout Core read, but only the chosen one is held, and
     none when no registry was read.
   - The identity page's writes move the checkout's `HEAD` and card, then let go without reading again, so the next
     filing or run sees a stale accepted revision.
   - A project replacement takes no hold, yet it is refused while the registry is held or refreshing.
2. **Made commit:**
   - A retried backup key whose first attempt ended uncertain, after a refresh moved the checkout, is committed by Core
     on the new `HEAD`. `publishMade` then refuses it for good, as its parent is not the kept base.
   - A `registry file` answered with two commits (a change-step removal, then the filing) is refused for good.
   - `publishMade` checks neither the change id nor the changed file, so a kept receipt naming another person's
     commit on the base is taken as the request's own.
3. **Card copy:**
   - On Windows the folder is made with its parent's ACL and restricted only afterwards.
   - The sweep can remove a live copy: with a relative or unnormalized root, or while a second copy is being made.
   - A login with a path separator leaves a folder that no sweep removes. Nothing sweeps at start or at exit.
   - A card that is a symbolic link in the checkout is copied as a plain file, so Core's own refusal of links never
     runs.
   - A receipt from before the card text was kept can strand a commit already made, or pass a rotated card of the
     same key.
   - A review opened while a refresh runs gets no card texts and stays refused for the dialog's life.
4. **Project backup key records:** `--use` changes the project file alone, but the dialog treats that commit as if it
   changed the access file. Before a refresh it blocks a replacement and offers a making Core refuses. After a refresh
   it offers the old key again. Chained makings keep only the first base, so a read that has caught up only to the
   middle commit drops the last one.
5. **Windows close:**
   - When the console close on its own isolate fails, a program ending meanwhile no longer closes the console. The
     close then waits out its bound and reports a false still running, or the last resort closes the console on the UI
     isolate, or closes it twice.
   - With no job, or a failed job query, the top process's end closes the console under a child still writing.
   - A throw in the console's release leaks the process handle. A failed or synchronously throwing read or wait leaves
     an unhandled error and a port.
6. **Terminals:**
   - A `Session` whose forward throws on close never closes its channel, and drops the error unhandled.
   - `Session.live` stays true after leave or dispose.
   - An exit seen while the terminal closes never reaches `onExit`.
7. **Tests that stay green with their harm present:**
   - the three terminal callers are tested only with code 0 at close;
   - the receipt-without-card test fakes the refusal, while the real core passes a rotated card;
   - the dialog's fake ignores the project repository's records, and the tear-down skips its hold and copy checks while
     a run is marked;
   - the Windows close test asserts the skip that causes the hang;
   - the unremovable-copy test runs `chmod` with no Windows skip and fails as root.

## Idea

Each point gets a test that goes red with its harm first. These are the fixes in view:
- The hold is bound to the dialog's life: a run whose dialog went away ends its hold.
- Identity writes hold every checkout Core will write.
- `publishMade` takes the commit's change id and the parent Core answers.

## Built so far

Each harm below has a test that was seen red with the harm put back, then green.
- **Hold bound to the dialog.** `runInATerminal` returns when its navigator goes away, completed from the terminal's
  `dispose`, so each caller's `finally` lets go of the hold, the running mark and the card copy. A close-time exit
  reaches `onExit`. `IdentityModel.dispose` lets go of its terminal's hold. A registry backup-key terminal put away
  while its program runs keeps the hold only until that program ends; the dialog shows it running with *End Core in
  the put-away terminal*, which ends it and waits a bounded time.
- **One registry per checkout.** `RegistryReadSource` keeps one `Registry` per address, so switching away and back gives
  the same object. Identity writes hold every registry read here (`RegistryCheckouts.holdAll`), refuse with words
  while any is held, and hold nothing when none was read, leaving Core alone to decide. Each held registry is read
  again through its hold before it is let go. `fileCard` says its unpushed commit.
- **Project runs.** A project replacement is never refused because the registry is held or busy.
- **Made commit.** Each request keeps the change id it sent; `publishMade` takes a commit only when its single
  `Porelo-Change-Id` (or, for the removal step, `Porelo-Change-Step`) line is the request's id and it changes only the
  expected file, on the kept base or the commit read last. A two-commit `registry file` answer is taken whole.
  Anything else is refused with words.
- **Card copy.** On Windows copies are made under a private root restricted once with `privateDirectory`. The sweep
  compares normalized absolute paths, and a folder is made and marked live under a lock the sweep honours. A login
  must match `[a-z][a-z0-9-]{0,31}`. The app sweeps at start. A card or folder that is a link or no plain file is
  refused with words. A receipt kept without its card text is refused with words, and Forget is offered. A list opened
  while the registry is read waits for the read to end, then reads its cards.
- **Project backup-key records.** Each commit made here is kept with its own base. A read forgets only those it holds,
  so a read that has caught up to the middle of a chain keeps the newer ones. A backup key's use (`--use`) is kept only
  in the project repository's record. It blocks nothing in the access file and is shown as done. Neither the use nor a
  new backup key is offered again while the access file still names the key it replaced.
- **Windows close.** A program end closes the console even when the close on its own isolate failed. The last resort
  never runs on the UI isolate and never closes twice. With no job, or a failed job query, the console stays open
  until output EOF. Every release step has its own try. `read` and `wait` go through `Future.sync` with the error
  handled.
- **Terminals.** `Session.leave` and `dispose` close the channel in a `finally` and catch every error; `live` is false
  once left.
- **Tests.** The three terminal callers are tested with codes 0, 1 and none. The receipt-without-card test runs the
  real core. The dialog's fake reads the project repository's records, and its tear-down checks hold, run and copy
  every time. The unremovable-copy test is skipped on Windows and as root.

## To be checked

- A backup-key commit is assumed to carry `Porelo-Change-Id: <the request's id>`, as `registry file` does. Core's
  contract says only "the same `--id` answers the commit already made". Confirm it on a real Core run.
- `prepareRetry` still accepts only a single-commit chain on the base. A two-commit answer is finished by
  `publishMade`, but a retry before Core answered again does not take it.
- `readRegularFile` checks the card's type before it reads the card, which leaves a short gap between check and read.
  Core's own refusal of links runs on the copy's source only if Core reads the checkout itself.
- The identity page's rotate terminal lets go of its hold when it is put away while its program runs. It has no
  *End* command like the replacement dialog's.
- Nothing sweeps card copies at exit, only at start and before each copy.
- The start sweep in `main.dart` is not tested at the app level. `PrivateCards.sweep` itself is.
- The unremovable-copy test was not seen red as root: no root run was made here.
