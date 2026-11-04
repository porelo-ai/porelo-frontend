# F344 — The Look Of A Page With Lists

**Status:** Review.

**What must be true.** On a page with several lists a person sees at once where one ends and the next begins, can sort each, and meets a filter only when they ask for it.

## How it stands

Read from the code, not run. `FilteredListSection` in `lib/src/ui/filtered_list_section.dart` draws a bordered
card with a header band, title and count, separated rows, a magnifier and a sort menu. The filter appears
when requested. Filter, sort direction and expansion are kept per list in `PageStorage`. Lists may supply
sort keys; the default is *Name*. `lib/src/ui/organization_page.dart` supplies *Name* and *State*, plus
*Machine* for projects.
Sections without explicit `sorts` in `lib/src/ui/filtered_list_section.dart` offer only *Name*, so
*State* sorting is not available on every list as decided below.

## Three proposals

Drawn as images with invented data, the same in each, and the shape of [F335](README.md#f335) with the rows of [F329](README.md#f329). They are drawings, not the app. A few words in them, such as *Add a card…*, *Enter a machine…* and *Name one…*, are placeholders.

| | A. Cards | B. Tabs and a table | C. A ledger with an index |
|---|---|---|---|
| Sections | each a card with a header band, all on one page | one list at a time, under a tab with its count | all on one page, under a colored rule, with an index beside them |
| Rows | two lines, in the pane's width | one line, in columns | one line, in columns |
| Filter | a magnifier per section, a small field after a click | a magnifier per tab | one field at the top, across all sections |
| Sort | a small menu in the header | a click on a column's head | a small menu in the header |
| Shown at a glance | everything, long | one list, short | everything, dense |
| A narrow window | as today: words shorten | columns must drop, per list | columns must drop, per list |
| Size | M | L | L |
| What it takes | the header of `FilteredListSection`, which every list then shares, a sort key per list, and a row with one height | a table for each list, tabs in the page, and the finder's way to a row, which must open its tab; the walks' steps change | columns for each list, an index that follows the scroll, and a filter over all sections |

**Recommended: A.** It answers all three of the operator's points in one widget every list already uses, so all pages change together. It keeps the page's overview, and a row keeps its long words, which a person's roles need and a column cuts off. B reads best for one list and sorts most naturally, but hides the rest of the organization behind tabs, and a page with one list gains nothing from them. C is the densest, and the most to keep aligned as a window narrows.

## Decided

Proposal A, the cards. Sort keys: name and state, plus the machine for a project, the choice kept per list. No section starts folded because it is long.

## A narrow layout

The Coordinator drew a narrow layout the operator found good, at 820 and 390 pixels: the rail becomes a menu behind a button, targets of 44 pixels,
the header on one line on a tablet, and on a phone the title first, search and sort below it and the buttons
behind ⋮, a row's state below its text, and only the first card open. Whether the app ships on those widths
is not decided here.

Read from the code, not run. `WindowSize` in `lib/src/ui/window_size.dart` selects the layout at 600 and
840 pixels; `lib/src/ui/shell.dart` puts the rail in a drawer below 840. `FilteredListSection` uses
`Sizes.touchTarget` (44 pixels) for header controls below 840. Below 600 it puts the title first, search
and sort below it, and header commands behind ⋮. `openWhenCompact` controls which cards start open;
`lib/src/ui/organization_page.dart` starts only its first card open and puts row state below the text.
`FilteredListSection` still uses a `Wrap` for the tablet header, so it does not guarantee the promised
single line. `ExpandableListRow` in `lib/src/ui/expandable_list_row.dart` keeps state beside the title,
so that row does not meet the narrow layout's state placement.

## Words

*Add a card…* or *Add a person…*, *Enter a machine…* and *Name one…* are placeholders until built.
