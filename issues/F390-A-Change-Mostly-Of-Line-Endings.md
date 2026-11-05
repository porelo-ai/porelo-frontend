# F390 — A Change Mostly Of Line Endings

**Status:** Backlog.
**Size:** S - a sentence and a count, if the machine can give the count.

**What must be true.** Where a change is mostly line endings, *What it touched* says so, with the real count beside the raw one, and the person can read the diff without them, or is told that the diff shown holds them.

## Why

A real test showed a change of three lines as `+1042 -1043`: the agent's commit turned a CRLF file into LF, and `git diff --ignore-space-at-eol` shows `+1 -2`. The person was given a whole file to read for three lines, and a change of line endings is itself something to see, so it is said rather than hidden.

## Plan

- Read whether the daemon's diff can give both counts; if not, agree it in the room.
- Show both counts where the change is mostly line endings, and say so in words.

## Acceptance

- A CRLF to LF commit touching three lines reads with both counts, and says line endings changed.
- A change that is not of line endings reads as today.

## Decided while building

## Open questions

- Whether the review shows a diff that ignores line endings, or says that the one shown holds them.

## To be checked
