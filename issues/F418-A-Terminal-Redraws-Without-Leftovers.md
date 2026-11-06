# F418 — A Terminal Redraws Without Leftovers

**Status:** Accepted (operator, 2026-11-06).
**Size:** S - the escape sequence the vendored terminal mishandles found from a recording of the agent's output, fixed
in `packages/xterm`, and the recording kept as the test.

**What must be true.** What a program redraws in a task's terminal shows as it does in another terminal: no character
of an earlier line is left at the start of a line the program rewrote.

## Why

The operator's walk on the rehearsal VM (2026-11-06): Claude Code's detailed transcript (Ctrl+O) inside tmux showed
stray characters at line starts - `N"decision"`, `I"messageId"`, `F"name"`, `/"detectors"`, `="findings"`,
`i"metadata"` - leftovers of earlier lines the redraw did not clear.

One character, always in the first column, before an indented line: the shape of a line the program clears or
indents by a sequence the vendored `packages/xterm` handles otherwise than tmux expects (erase or insert of
characters, a cursor move by column, or a tab), while the rest of the line is rewritten.

The operator's screenshot (same day) also shows three rows of dots (`.....`) below the agent's prompt that belong to
no output: the same leftovers, or a program's own fill drawn where a clear was expected; the recording tells which.

## Plan

- **To be checked first:** the raw output that draws it, recorded in the task (`script -q -c 'tmux attach' out.raw`,
  or tmux's `pipe-pane`), with the transcript opened once; the sequences before a leftover line name the one handled
  wrongly.
- Fix it in `packages/xterm` (its escape handler or buffer), with the upstream's behaviour as reference.
- **The test that goes red first:** the recorded bytes replayed into a `Terminal` of the same size leave no leftover
  in the first column of those lines. It guards a person reading an agent's transcript that says what it did not.

## Found and built

- No recording was taken; the cause is read from tmux's `tty.c` (`tty_clear_line`): a run of cleared cells at a
  line's start is cleared by moving the cursor onto its last cell and sending EL 1 (`CSI 1 K`), which erases up to
  the cursor *inclusive* (xterm, ECMA-48). The vendored `Buffer.eraseLineToCursor` stopped before the cursor, so the
  last cell of every cleared indent kept what stood there: exactly one character directly before the indented text
  (`N"decision"`). ED 1 (`CSI 1 J`) shares it and is fixed with it.
- Red first, `test/ui/terminal_redraw_test.dart`: `Expected: '  "decision"'  Actual: ' o"decision"'`.
- The rows of dots were not reproduced; the same cleared-start path is the likely source, unconfirmed.
- Also seen and left as they were, since tmux positions the cursor absolutely before each of them: HT with no stop
  left enters pending wrap where xterm stops in the last column; ECH, ICH, DCH, IL, DL, SU, SD take a parameter 0 as
  0, not 1; BS and CUB from the pending-wrap column were not checked against xterm.
