# F578 — The Token Hand-Over Shows It Runs

```json
{
  "$schema": "issue-1.json",
  "id": "F578",
  "title": "The Token Hand-Over Shows It Runs",
  "state": "Backlog",
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

## To be checked

- Why the operator saw the button not greyed: whether the press reached `giveFrom` at once, or the long wait lay
  before it (connecting, asking the sources again) or after it (`heard`, the host asked again as root), where nothing
  is shown either.
- What a close during the run does: `step.dispose()` runs in `_giveHostTokenNow`'s `finally` while `give` still
  runs, and the step notifies after it.
