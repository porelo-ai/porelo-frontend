# F430 — Leftovers Of The Rental Findings

**Status:** Idea.

**What must be true.** What the fixes of the 2026-11-07 trial move's findings ([F424](README.md#f424) to [F428](README.md#f428)) named as not built is kept
in one place until the operator places each part: in an issue of its own, in a sprint, or dropped. Each point came from
the one reading of its issue, and gets no reading of its own.

Each point is to be checked against the code before it is fixed.

## How it stands

Points 1 to 3 are taken as described; point 4 as decided under it.

**The operator's word (2026-11-08).** Points 1 to 3 and the three from [F432](README.md#f432)'s reading are built after
[F429](README.md#f429), each checked against the code first, with a test seen red first where one is possible, and
one reading for this issue as a whole. Point 4 is done.

- **From [F424](README.md#f424), the setup wizard's last pages:** the widget test does not walk pages 7 and 8 to their end, since
  `HostRun`'s start does file work the test clock never ends; the token page is tested alone.
- **From [F424](README.md#f424), the old preparing dialog:** the window no longer opens it, only its tests do; it and its tests are to be
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
  **Done** in [F435](README.md#f435) (b56fbec3, 27b260b8, 6b8e3679), on main since 2026-11-08.
- **From [F432](README.md#f432)'s reading, found there and older than it:**
  - `_hostTokenStep` in `shell.dart` reads the organization's view once, before its own `connect` refreshes it: a
    view not read yet gives the declared source no repository, so the one-click token falls back to the page.
  - `_giveHostToken` disposes its `HostTokenStep` when the page closes while an `ask`, a `giveFrom` or the vault's
    opening still runs; its later `notifyListeners` throws on a disposed notifier.
  - `readThisComputersDeclarations` and `isThisComputersVaultShut` read `Backend.local()`'s socket, while *Open this
    computer's Porelo-Vault* opens `Machine.local()`, which follows `PORELO_SOCKET`: with that variable set, the
    button does nothing.

## Open questions

None.
