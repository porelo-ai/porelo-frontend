# F430 — Leftovers Of The Rental Findings

```json
{
  "$schema": "issue-1.json",
  "id": "F430",
  "title": "Leftovers Of The Rental Findings",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 2,
  "blockedBy": [],
  "covers": "What the fixes of the trial move's findings named as not built, gathered for the operator to place: the wizard's last pages in a test, the old preparing dialog, Forward's stale-push check, a give-back that leaves the machine listed."
}
```

**What must be true.** What the fixes of the 2026-11-07 trial move's findings (the setup wizard to [F428](README.md#f428)) named as not built is kept
in one place until the operator places each part: in an issue of its own, in a sprint, or dropped. Each point came from
the one reading of its issue, and gets no reading of its own.

Each point is to be checked against the code before it is fixed.

## How it stands

Points 1 to 3 are taken as described; point 4 as decided under it.

**The operator's word (2026-11-08).** Points 1 to 3 and the three from the token asks' reading are built after
the side bar as a folding tree, each checked against the code first, with a test seen red first where one is possible, and
one reading for this issue as a whole. Point 4 is done.

- **From the setup wizard, its last pages:** the widget test does not walk pages 7 and 8 to their end, since
  `HostRun`'s start does file work the test clock never ends; the token page is tested alone.
- **From the setup wizard, the old preparing dialog:** the window no longer opens it, only its tests do; it and its tests are to be
  taken out.
- **From [F426](README.md#f426), Forward's stale-push check:** the check that the push is still the same after the forge's branches
  arrived has no test, since no stand-in of the tests reaches that list today.
- **Found after the push, giving a machine back:** *Take Porelo off this machine…* asks "…and remove this machine from
  the organization's list?", but after a confirmed down it only forgets the machine on this computer and sends no
  `org host remove`. So the machine stays listed, and still carries what it carried, as porelo-move did after the
  2026-11-07 trial move. Decided: after a confirmed down the window sends `org host remove`; a refusal stands in the
  protocol with its words, and the row keeps *Remove the machine…*. Until that is built, the question is reworded to
  promise no removal. It is built before the third trial move; meanwhile the organization page's row ⋮ → *Remove the
  machine…* removes the listing by hand; it needs only the role, not a machine that answers.
  **Done** (b56fbec3, 27b260b8, 6b8e3679), on main since 2026-11-08.
- **From the token asks' reading, found there and older than it:**
  - `_hostTokenStep` in `shell.dart` reads the organization's view once, before its own `connect` refreshes it: a
    view not read yet gives the declared source no repository, so the one-click token falls back to the page.
  - `_giveHostToken` disposes its `HostTokenStep` when the page closes while an `ask`, a `giveFrom` or the vault's
    opening still runs; its later `notifyListeners` throws on a disposed notifier.
  - `readThisComputersDeclarations` and `isThisComputersVaultShut` read `Backend.local()`'s socket, while *Open this
    computer's Porelo-Vault* opens `Machine.local()`, which follows `PORELO_SOCKET`: with that variable set, the
    button does nothing.

- **From the folding side bar's part 3 reading, found there and older than it** (checked against the code before
  part 3; not the operator's word yet, which places them):
  - *Work*'s *List* keeps its selection in the machine's `selectedTask`, *Running* its tab in `WorkView.tab`, and
    neither tells the other: a running task chosen in *List* opens as the first tab in *Running*, and a tab chosen in
    *Running* is not the task *List*, the shortcuts and the finder see.
  - On a phone, closing the drawer while *Running* is shown gives the keyboard to the menu button, not to the terminal
    (`onDrawerChanged` asks for the menu's focus whatever page is shown), so the next Space or Enter opens the drawer
    again.

- **Found on 2026-11-08, a person's stop read as a restart:** a task stopped with `porelo task stop` (exit 143, porelod
  not restarted) reads on its row "the machine's restart interrupted its run; it stays stopped with its session kept,
  and its next start continues it", and its *Started* "not said". The words are not the window's own (no such text in
  lib): find whether the daemon's list answers them or the window reads exit 143 as a restart, red first, and make a
  person's stop read as a stop. Not before the third move (the operator's word).

## Open questions

None.

**Noted 2026-11-08 (the third move's guide):** the start choice *A shell, driven by hand* starts the agent's own
session (mode `agent`), and its task row then reads "an agent session, worked through"; the bare shell is *A bare shell,
without the agent*. The same mode has two names: the choice should say what the row says, or both the same new words.
