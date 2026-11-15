# F578 — The Token Hand-Over Shows It Runs

```json
{
  "$schema": "issue-1.json",
  "id": "F578",
  "title": "The Token Hand-Over Shows It Runs",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 60,
  "blockedBy": [],
  "covers": "Story ST361: from the press of the token page's give button until the machine's answer, the page shows that the hand-over runs, offers no second press, and Close says what happens to the running hand-over."
}
```

**Why this size.** One panel and the dialog around it; the running state is already kept by the step.

**What must be true.** A person who gives a machine their forge token from `Give <machine> your <forge> token, once`
sees at once that the hand-over runs and that it ended, and knows what closing the page meanwhile does.

## Plan

- Today `HostTokenStep.giveFrom` (`lib/src/app/host_token_sources.dart`) sets `giving` and notifies, and
  `HostTokenPanel` (`lib/src/ui/server_setup_wizard.dart`) only takes `onPressed` away from *Give it the token
  from …*: no progress mark and no words while Porelo or ssh hands the token over, which takes long on a rented
  host. The dialog around it (`_giveHostTokenNow` in `lib/src/ui/shell.dart`) keeps *Close* as it is.
- While `step.giving`: the give button shows the progress mark the placing dialog uses (`Sizes.mark`,
  `Sizes.spinnerStroke`) and the words `Handing the token to <machine>…`; *Ask again* stays grey as now.
- *Close* during the run: the dialog says under its actions that the hand-over goes on after it closes and that the
  machine's row says how it ended. What runs on after the close is checked first (see below), and the words say what
  is true.
- Harm and test: a second press while the first runs must not hand the token twice. `giveFrom` refuses while
  `_giving`, and `TokenGiving` gives one machine one token at a time; a widget test presses twice during a give held
  open by the test and expects one call of `give`, red first by dropping the guard. The progress mark and the words
  only read wrong and get no test.

## Acceptance

- The double-press test, seen red; the page in the debug build shows the mark and the words from the press until
  the answer.

## Built

- `HostTokenPanel` (`lib/src/ui/server_setup_wizard.dart`): while `step.giving` the give button keeps its colour,
  shows the placing dialog's progress mark (`Sizes.mark`, `Sizes.spinnerStroke`) and `Handing the token to
  <machine>…`, and takes no press; it takes none while the sources are asked again either. While `step.hearing` (the
  host, having taken the token, asked what it says now) a progress mark and `Asking <machine> what it says now that it
  has the token…` show. *Ask again* stays grey as before.
- `HostTokenStep` (`lib/src/app/host_token_sources.dart`): a `hearing` state around `heard`, `giveFrom` refused while
  giving or hearing, `handOverEnded()` completing once the last hand-over ended with the host's word after it, and
  `QuietAfterDispose`, so a step disposed while it runs says nothing more instead of throwing.
- `_giveHostTokenNow` (`lib/src/ui/shell.dart`): while the step gives or hears, a line above *Close* says that Close
  leaves the hand-over running and that the machine's row then says whether it still waits for its token. After the
  page closes it awaits `handOverEnded()` before it answers and disposes the step, so `TokenGiving` keeps the machine
  busy (its row's *Give it your token…* grey with why) until the hand-over ended, and the answer is the end's.
- What the wait was: `giveFrom` sets `giving` and notifies before its first await, so a press greys the button in the
  next frame; but greyed with its label unchanged it read as a button that stopped working (the placing dialog says
  the same of its own), it stayed live while the sources were asked again (*Ask again*, or after the vault was
  unlocked), which runs `_connectHost` (an organization refresh, then the connection), and after the give `heard`
  (`tokenTaken`, which asks the host again) ran with nothing shown. Which of these the operator met is not known from
  the code; the page now shows all three.
- What a close during the run did: `step.dispose()` ran in `_giveHostTokenNow`'s `finally` at once; when the give
  ended, `giveFrom`'s `notifyListeners` threw *A HostTokenStep was used after being disposed* (an assertion, so in
  debug builds), and `heard` never ran, so the machine's row kept saying it waited for its token. In every build the
  close answered at once, so `TokenGiving` let the machine be given a token again while the first still went, and the
  machine page read the closed page as a given token.
- Tests, each seen red:
  - `a step disposed while it hands the token over still has the host asked once it took it`
    (`test/app/host_token_sources_test.dart`): red before the fix with the use-after-dispose error from `giveFrom`.
  - `the end of a running hand-over is awaited, the host asked after it included` (same file): red with
    `handOverEnded` answering at once (`Expected: false, Actual: <true>`).
  - `a press while the token is handed over gives nothing a second time` (`test/ui/server_setup_wizard_test.dart`):
    two presses and a direct `giveFrom` while a give is held open; red with `giveFrom`'s guard dropped, and red on the
    presses alone with the button's guard dropped too (`Expected: <1>, Actual: <2>`).
- The reading by another model (Claude Sonnet) found nothing red. Taken from its yellows: `giveFrom` also refuses
  while the sources are asked and once the host took a token, in the model and not only at the button; *a step asking
  its sources, or one whose host took a token, gives nothing more* (same file), each half seen red with its guard
  dropped. Left: *Ask again* stays offered while the host is asked after the give, which only reads the sources anew;
  an `Error` (not an `Exception`) from the give escapes `handOverEnded()` after the flags are reset.
- Not shown by a test: the shell's wait for `handOverEnded()` and the line above *Close* (no widget test opens the
  token's page in the shell); the progress mark and the words only read wrong. Not yet seen in the debug build.
