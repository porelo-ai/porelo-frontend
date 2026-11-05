# F353 — The Page With The Work Cards Redesigned

**Status:** Review.

**What must be true.** *Work* shows all work in one list, as the other menu items do, with no decision in it, and every running agent in a tab of its own; what needs a decision is in *Needs you* alone, and one number counts it. A card whose terminal has ended, [F306](README.md#f306), goes into it.

## The shape

**The two views of *Work*.** The page's head holds its title, *New work* and a switch between *List* and *Running*.

- **List.** One card, *All work*, with its count, like the lists under the other menu items. The machine and project filter buttons go: a search over name, project and machine, and a sort, sorted by state to begin with, take their place.
- **A row** shows the state's dot, the name, its project, agent and machine, its state in words, a fold and a menu. Unfolded it shows its repository, way of working, start, tokens used and commits at the gate, its last lines, and what can be done from there: *Open its terminal*, *Follow its log*, *See it in Needs you*, or for ended work *Read its log* and *Start it again*. No row decides anything.
- **Running.** One tab per running agent, each with its state's dot and a short name, and finished work has none; many tabs scroll sideways, and a tab follows the window's light or dark. Below the tabs a bar names the work, its project, agent and machine, and its way of working. Ctrl+PgUp and Ctrl+PgDn go to the next agent.
- **A running task whose terminal has ended** keeps its tab, with the sentence "Its terminal session has ended" and the next step: *Open a new terminal*, or *Read its log* where one cannot be opened. There is no black bar. The row says the same.
- **A tile's other offers** move to the row's menu.
- **Work that waits on a person** says so in a line under that bar, with a link to answer in *Needs you*; the answer is given there.

**The console.** An agent in a terminal has the real terminal with the agent's own prompt, which takes every key, and no separate input line. An agent without a terminal shows in the same console look, with a *Follow* switch.

**What an unattended agent's console reads.** Today's log lines, marked with what the window can tell: headings, errors, results. The drawn summaries such as "Read 4 files" come later, in [F372](README.md#f372), and do not hold this page.

**A light console** is drawn, with its own colors for the terminal's text, lines and marks.

***Needs you*.**

- **Reviews leave *Work*.** They are a group of their own, *Reviews*, under the group of questions with a deadline, *Decide soon*, which also holds a held message. Each row names what waits and offers its next step, a question also *See its terminal*.
- **It counts every row:** one number in the page's header and on the rail's badge.
- **Finished work:** work that ended with a failure, or with something a person has not seen, is a row and counts until opened or put away. Work that finished with nothing waiting is no row and stays in *Work* alone. The rows that are no work, such as a silent machine, a host's stop, a failed operation or an authorization, stay and count.

**What this replaces in `doc/decisions.md`:**

- *Needs you has ranks*: "listed and not counted" goes; work at the gate counts like every other row.
- *One session at a time*: "It belongs to the place it was opened" goes: terminals have one place, *Work* > *Running*. "Leave is the only way out" goes: changing the tab, or leaving the page by a menu click, leaves the session; the agent runs on, and coming back shows the same tab. One session open at a time stays.

## Plan

- `WorkPage` in `lib/src/ui/work_page.dart` holds the head and switches between the list and `RunningView` (`lib/src/ui/running_view.dart`); `WorkView` keeps the search, the unfolded rows, the view and the tab. `WorkRow` in `lib/src/ui/attention_view.dart` is the list's row; `TaskTile` stays as the detail of a row of *Needs you*.
- `Sessions` loses `ConsolePlace`. `_openSession` in `lib/src/ui/shell.dart` goes to the tab, and the window leaves the session once *Running* is off screen.
- `Attention.needingSomebody` is every row; `putAwayTheEnd` keeps what was opened or put away in `Settings`. `AttentionView` stands the rows in cards.
- `TerminalLook.themeOf` and `ConsoleColours` give the console its light and dark; `console_lines.dart` marks a line. `Usage` is read through `FleetBackend.usage` when a row unfolds.
- Red first: `test/features/running_work.feature`, the new scenarios of `daily_work.feature` and `needs_a_person.feature`, `test/ui/console_look_test.dart` and `test/ui/running_tabs_test.dart`.

## Acceptance

- *Work* holds one list with a search and a sort, and no row decides anything.
- *Running* has a tab per running agent, and Ctrl+PgUp and Ctrl+PgDn move between them. Leaving and coming back shows the same tab, with its agent still running.
- *Needs you* holds every decision, and one number counts its rows in the page's header and on the badge.
- A running task whose terminal has ended says so, in its tab and its row, with its next step.
- Light and dark both read, in the console too.

## Decided while building

- **An answer needs nobody.** What came of a question somebody answered goes under *Recently resolved* for that list's time, an hour by default, with its words, and does not count; where its work has a row anyway it stays on that row with *Got it*.
- **A question that ran out counts until seen, past a restart.** It has a row of its own, kept in the settings, until *Got it* is pressed. The window cannot tell whether a person was looking when it ran out, so every one counts.
- **A row's *Tokens used*** is read when it unfolds, and every 30 seconds while a running row stays unfolded.
- **One node reached two ways** has one tab and one row. A tab whose machine does not answer stays, says so and opens nothing, as its agent may still run.

## To be checked

- That a light console holds up against what the agents' own colors do in it.
