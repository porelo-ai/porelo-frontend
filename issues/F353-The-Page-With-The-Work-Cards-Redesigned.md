# F353 — The Page With The Work Cards Redesigned

**Status:** Idea. The design below is accepted as drawn; it is built right after the foo test.

**What must be true.** *Work* shows all work in one list, as the other menu items do, with no decision in it, and every running agent in a tab of its own; what needs a decision is in *Needs you* alone, and one number counts it. A card whose terminal has ended, [F306](README.md#f306), goes into it.

## The shape

**The two views of *Work*.** The page's head holds its title, *New work* and a switch between *List* and *Running*.

- **List.** One card, *All work*, with its count, like the lists under the other menu items. The machine and project filter buttons go: a search over name, project and machine, and a sort, sorted by state to begin with, take their place.
- **A row** shows the state's dot, the name, its project, agent and machine, its state in words, a fold and a menu. Unfolded it shows its repository, way of working, start, tokens used and commits at the gate, its last lines, and what can be done from there: *Open its terminal*, *Follow its log*, *See it in Needs you*, or for ended work *Read its log* and *Start it again*. No row decides anything.
- **Running.** One tab per running agent, each with its state's dot and a short name, and finished work has none. Below the tabs a bar names the work, its project, agent and machine, and its way of working. Ctrl+PgUp and Ctrl+PgDn go to the next agent.
- **Work that waits on a person** says so in a line under that bar, with a link to answer in *Needs you*; the answer is given there.

**The console.** An agent in a terminal has its console with an input line. An agent without a terminal shows in the same console look, without an input line, with a *Follow* switch.

**What an unattended agent's console reads.** What is to be read is what the agent writes in its console, as in a terminal now: its text and what it did. Today's formatter gives `[Bash]`-style lines.

**A light console** is drawn, with its own colors for the terminal's text, lines and marks.

***Needs you*.**

- **Reviews leave *Work*.** They are a group of their own, *Reviews*, under the group of questions with a deadline, *Decide soon*, which also holds a held message. Each row names what waits and offers its next step, a question also *See its terminal*.
- **It counts every row:** one number in the page's header and on the rail's badge.

**What this replaces in `doc/decisions.md`:**

- *Needs you has ranks*: "listed and not counted" goes; work at the gate counts like every other row.
- *One session at a time*: "It belongs to the place it was opened" goes: terminals have one place, *Work* > *Running*. "Leave is the only way out" goes: changing the tab, or leaving the page by a menu click, leaves the session; the agent runs on, and coming back shows the same tab. One session open at a time stays.

## To be checked

- With the agent adapters' repositories: how an unattended agent's console gets its text and what it did, in place of `[Bash]`-style lines. This is the design's open part.
- That a light console holds up against what the agents' own colors do in it.
