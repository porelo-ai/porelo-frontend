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
