# F570 — A Token Wait Gives Way To A Carried Answer

```json
{
  "$schema": "issue-1.json",
  "id": "F570",
  "title": "A Token Wait Gives Way To A Carried Answer",
  "state": "Review",
  "size": "S",
  "priority": "Highest",
  "rank": 15,
  "blockedBy": [],
  "covers": "Story ST361: once porelo answers that a project is carried, the window drops what it kept of an earlier token wait and stops offering the token, without a restart."
}
```

**Why this size.** The window's projects model and its watch: one stale state, one test.

**What must be true.** A machine's project page says what porelo says now.

## Plan

Found live: after the token took effect, the window still said that the project waits for the forge token.

Agent Core read porelod. It holds no cache of the host state. `Projects` reads it afresh on every call, and
`WatchProjects` pushes each change within 3 s. So the stale state is the window's. Either a WatchProjects stream ended
and was not opened again, or a model keeps `hostState` from an earlier answer (or the hand-over's) and does not replace
it on a Refresh.

- Find which, and fix it.
- Agent Core's B772 is rewritten or closed on this issue's finding.

## Acceptance

- The red test Agent Core named: a WatchProjects or Projects answer carrying hostState "carried" after one with "waiting-for-token" shows carried and drops *Give token*, with no restart. Also one where the watch stream ended.

## Built

- **Cause: neither of the two guesses.** The window does not follow `WatchProjects` at all, and it never read
  `hostState`. The token wait on a machine's project page, its rows and its menus came only from what the machine said
  as root (`org status`) when its Machine Admin connected; that answer is asked once per connection and asked again
  only on a reconnect, *Refresh* or a token given from this window. A token that took effect later, or after the
  window's one ask right behind it, left the wait on screen. Porelo's `Projects` answer, read again on every push of
  the work, on the quiet refresh and on *Refresh*, already said `carried` and was not looked at.
- `Project` and `Repository` now read `hostState` and `hostWhy`. `HostProgress.asListedBy` puts Porelo's word in
  place of a kept project word that says otherwise, keeping what the host said of central for a repository taken in
  both; `cannot-say` and a project Porelo says nothing of leave the kept word standing. The shell applies it wherever
  the machine's project page, its rows, its menus and *Give it my … token…* read what the machine said. No root
  login is added.
- The case where the watch stream ended: the `Watch` of a machine's work had no end handler, so a watch the daemon
  ended left the window believing it live with nothing arriving. It now goes not live and opens again after the
  retry pause; its first push reads the project list anew.
- `WatchProjects` stays unused (`doc/Contract-Gaps.md`, *On the wire, not used here yet*): the project list keeps
  arriving with the work's pushes, the quiet refresh (every 60 s by default) and *Refresh*. porelo needs nothing new:
  its answer was right, and Agent Core's issue can be closed on this finding.
- Tests: `test/ui/machine_own_pages_test.dart` *a project its machine's Porelo answers carried after a token wait no
  longer waits, with no restart* and *a project carried after its machine ended the watch no longer waits, once the
  watch is open again*, both red before the fix; `test/app/host_progress_test.dart` *the machine's Porelo replaces a
  kept word only where it says otherwise, and never by cannot say*, seen red by letting `cannot-say` through.
- A watch that fails is not opened again when it ends, only one the machine ended with a final reply: a machine whose
  Porelo has no `Watch` was otherwise asked for one again every two seconds, its status line repeating that it cannot
  push changes. `test/app/fleet_model_test.dart` *a watch the machine cannot serve is not asked for again* was red
  first (ten asks), and *a watch the machine ended is opened again after a pause* was seen red with the reopening taken
  out.
- A watch opened again also reads the project list anew: a daemon may send nothing on a watch until the work
  changes, and the token wait stayed until then or the quiet refresh. Seen red with a fake that pushes nothing on
  opening: `test/ui/machine_own_pages_test.dart` *a watch opened again reads the projects anew, though the machine
  pushes nothing on opening* and `test/app/fleet_model_test.dart` *a watch opened again reads the projects anew*.
- The later read stands: the root answer is stamped when it is kept (`HostProgress.heardAt`) and the project list
  when it is read (`FleetModel.projectsReadAt`), and Porelo's word replaces the root's only where the list was read
  after the answer was heard. A Refresh that hears the wait again, as after the token was revoked, is no longer hidden
  by an older list that said carried. `test/app/host_progress_test.dart` *the machine's Porelo replaces a kept word only
  when it was read after that word was heard*, red first.
- A project only the list names is still taken from it, now only where the list is the later read. Both read the
  host's one publication (`hostState` is "the host's published project progress", and the root's `org status` reads
  the same), so a project the root did not name is one published since it was asked, not one it left out on purpose;
  and `hostWhy` for `waiting-for-token` says the person's forge token is needed, which is what *Give token* offers.
  *a project only the machine's Porelo names is taken from it only when it was read after the answer*, red first.
- `test/app/fleet_model_test.dart` *a watch that failed with an error and then ended is not asked for again* (seen red
  by counting only an unserved watch as failed) and *a watch waiting to be opened again is not opened once the machine
  is let go* (seen red with the reopening left to run after dispose).
