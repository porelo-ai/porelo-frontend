# F465 — Needs You Rows Say Their Name Once And Whole

```json
{
  "$schema": "issue-1.json",
  "id": "F465",
  "title": "Needs You Rows Say Their Name Once And Whole",
  "state": "Implementing",
  "size": "XS",
  "priority": "Medium",
  "rank": 14,
  "blockedBy": [],
  "covers": "A row under *Needs you* names its machine once, and its title is shown whole where the row has room."
}
```

**Why this size.** a machine's row under *Needs you* named once, and a row's title given the width the row leaves free.

**What must be true.** Each row under *Needs you* names what it is about once and, where the window has room, whole.
- Seen live (2026-11-10, the move rehearsal against a rented host, window 1280x720): the row of this computer's
  machine, not answering, read "this machine · this machine". The row's title is the machine's name, and every row
  that is not a token's or a repository's gets " · <machine>" appended (`_row` in `lib/src/ui/attention_view.dart`).
- Seen live at the same size: the row of work waiting at the gate read "porelo-foo-project-gate-1: 1 c…", cut after
  two words, while about 50 pixels stood free between its state chip and its button, and the title column ended
  well before the chip. The title is one line with an ellipsis in a column that does not grow with the row
  (`ExpandableListRow`, `lib/src/ui/expandable_list_row.dart`).

## Plan

- `_row` in `lib/src/ui/attention_view.dart`, through `NeedsYouTitle.of`: a row appends " · <machine>" only where
  its title does not already hold the machine's name, so a silent machine's row and a server being prepared name it
  once; a token's and a repository's row append nothing, as before. A row of work (one row per cause) already names its
  machine once, under its sentence ("on <machine>"), and appends nothing.
- `ExpandableListRow` in `lib/src/ui/expandable_list_row.dart`: the state chip and the one action are as wide as
  they need, each up to `Sizes.rowSideShare` (0.3) of the row, in place of `Flexible`, which kept for them half the
  free width whether they used it or not; the title is `Expanded` and takes all they leave. Where it is still cut,
  its tooltip keeps it whole, as before. The state stands beside the name where the card is 480 wide or more, as
  decided, and also needs 160 pixels of words of its own (`WindowSize.chipBesideWords`), so next steps that leave the
  words less put it under the name rather than past the row's edge.
- Tests, `test/ui/needs_you_row_words_test.dart`, each at 1280x720 and at 390x800: a silent machine's row names it
  once; a gate row names its machine once and its title is whole or leaves no free pixel on its line; a row with a
  long title, a short state and a short action leaves no free pixel either, and nothing beside a title takes more
  than its share; a title the row holds is whole at 1280 and cut at 390; a row whose steps leave about 70 pixels
  lays out without overflow; and a unit test of `NeedsYouTitle.of` names the machine once for each kind of row.

## How it stands

- Built (2026-11-10).
- **Reading fixed** (2026-11-10), one reading by another model, 0 must and 4 may, each checked against the code first:
  - May 1, taken with a different fix: with the state no longer `Flexible`, steps that left the words under about
    80 pixels on a card 480 wide or more overflowed. Red: `Expected: null Actual: FlutterError:<A RenderFlex
    overflowed by 6.4 pixels on the right.>`. The proposed fix, placing the state by the words' own width, was
    declined: the state stands beside the name by the card's width, as decided for every list. The state now also
    needs 160 pixels of words beside it, or it stands under the name.
  - May 2, taken: a server being prepared read "demo server · demo server", or "orchard server · orchard" where the
    host carries the project's name. Red: `Expected: <1> Actual: <2>`, `AttentionKind.host reads "demo server · demo
    server"`. A row now appends its machine only where its title does not already hold its name.
  - May 3, taken: the gate row's test now names the title it expects, instead of reading it back from the row.
    Deliberate break, the gate row titled by the work's name alone: `Expected: exactly one matching candidate Actual:
    ... Found 0 widgets with text "porelo-checkout-migrate: 1 commit ...`, at both widths.
  - May 4, taken: nothing beside a cut title may take more than its share of the row. Deliberate break, the state
    given half the row: `Expected: a value less than or equal to <384.0> Actual: <571.7999992370605>`. A new test
    has a title the row holds whole at 1280 wide. Deliberate break, the state `Flexible` again: `Expected: <false>
    Actual: <true>`.
- Already held by the rebuild of *Needs you* into one row per cause, shown by the gate row's test, green on the code
  before this change: a row of work names its machine once, under its sentence, at both widths; and at 390 wide a
  gate row's cut title already reached the disclosure beside it.
- Red first, on the code before this change:
  - The silent machine's row at both widths: `Expected: <1> Actual: <2>` (the row read the name twice).
  - The gate row at 1280 wide: `Expected: a value less than or equal to <16.0> Actual: <161.6999969482422>`, the
    width the action's `Flexible` kept free after the disclosure.
  - The long title at 1280 wide, with only the state chip's `Flexible` put back: `... Actual: <450.79999923706055>`,
    `while 450.79999923706055 pixels stand free at 696.7999992370605 on its line`.
- The test font draws each letter as wide as it is tall, about twice a real font, so no gate row's title fits at
  1280 in a widget test; the tests hold the layout instead: a cut title has no free pixel beside it. Measured once
  with Noto Sans loaded in a throwaway widget test at 1280x720: the gate row's title "porelo-checkout-migrate: 1
  commit waits at the gate" was cut at 210 pixels before this change and is whole (350 pixels) after it.
- Not seen in the window against the mock: the window was not started for it. That the title stands whole at
  1280x720 in the window's own font stays for the operator's test.

## Acceptance

- Under *Needs you* against the mock, a machine that does not answer reads its name once; a gate row's title at
  1280x720 is shown whole; both tests seen red first.
