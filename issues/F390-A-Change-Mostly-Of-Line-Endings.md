# F390 — A Change Mostly Of Line Endings

**Status:** Review.
**Size:** S - a sentence and a count, if the machine can give the count.

**What must be true.** Where a change is mostly line endings, *What it touched* says so, with the real count beside the raw one, and the person can read the diff without them, or is told that the diff shown holds them.

## Why

A real test showed a change of three lines as `+1042 -1043`: the agent's commit turned a CRLF file into LF, and `git diff --ignore-space-at-eol` shows `+1 -2`. The person was given a whole file to read for three lines, and a change of line endings is itself something to see, so it is said rather than hidden.

## Plan

The contract, agreed with Agent Core: `ReviewFile` gains `addedIgnoringLineEndings: ?int` and `removedIgnoringLineEndings: ?int`, git's `--numstat --ignore-space-at-eol` over the same range, `-1` for a binary as `added` and `removed` are, absent from an older daemon; `Review` takes `ignoreLineEndings: ?bool`, which answers the diff without them.

- `lib/src/client/`: the two counts on `ReviewFile`, read field by field; `review` passes `ignoreLineEndings` only when asked.
- `lib/src/app/gate.dart`: a file is mostly line endings where both counts are there and the real change is far smaller than the raw one; the switch reads the review again with `ignoreLineEndings`.
- `lib/src/ui/gate_view.dart`: *What it touched* says "mostly line endings" with the real count beside the raw one; the review offers *Without line endings* only where the daemon serves it, and otherwise says that the diff shown holds them.
- Red first: a client test that both counts and their absence read right, and a widget test that a CRLF to LF file of three real lines shows both counts and the words.

## Acceptance

- A CRLF to LF commit touching three lines reads with both counts, and says line endings changed.
- A change that is not of line endings reads as today.

## Decided while building

- Both: the review says the change is mostly line endings with both counts, and offers the diff without them where the daemon serves it.
- From the reading: no wire test against the mock daemon for `ignoreLineEndings`, since the served contract of a real daemon was read to declare it and the scenarios hold what is sent and when; no test that the narrower diff renders, since its hunks go through the same unchanged reader as every diff.

## To be checked
