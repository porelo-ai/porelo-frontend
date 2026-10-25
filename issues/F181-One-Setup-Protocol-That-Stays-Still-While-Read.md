# F181 — One Setup Protocol That Stays Still While Read

**Status:** Analyzed.
**Size:** S - `HostSession` in `lib/src/app/host_session.dart` and `HostDialog` in `lib/src/ui/host_dialog.dart`.

**What must be true.** The setup dialog shows one protocol list and no *Full protocol* drawer.
Earlier attempts stand as a collapsed group at the end (`"Earlier attempt, HH:MM–HH:MM"`), any
unmatched `porelo-host` line appears as its own row where it arrived, and *Copy the protocol* copies
the whole text at once. While the person has scrolled up to read, new rows added below never move the
view or the buttons; the list follows new rows only while scrolled to the end.

## Plan

- **Where it is today.**
  - `HostDialog._progress` (`lib/src/ui/host_dialog.dart`) renders `session.history` as step rows at
    the top and a collapsible `ExpansionTile` (`key: Key('host-full-protocol')`, title `'Full
    protocol'`) at the bottom containing `SelectableText(session.protocol.join('\n'))`.
  - `HostSession` (`lib/src/app/host_session.dart`) clears `_history` at the start of every `_run`,
    while appending both step lines and `_ProtocolWords` into `_protocol`. Because the step list and
    *Full protocol* show the same run in two places, a person looking for why an earlier attempt
    failed must open *Full protocol* and read raw lines without durations.
  - `DialogScroll` (`lib/src/ui/dialog_scroll.dart`) wraps the whole dialog content, and
    `HostDialog._scrollDown` (`lib/src/ui/host_dialog.dart`) calls `Scrollable.ensureVisible` when
    entering a waiting stop; as rows grow or expand, the content shifts while the person is reading
    or reaching for a button.
- **Steps.**
  1. In `HostSession` (`lib/src/app/host_session.dart`), keep each prior attempt of the same setup as
     a structured attempt record (its start and end local times `HH:MM–HH:MM` and its ordered entries)
     instead of discarding `_history` into a flat string list, and record any unmatched stderr line
     from `porelo-host` (`_ProtocolWords` with `unmatched: true`) in the attempt's entry list at the
     point it arrived.
  2. In `HostDialog._progress` (`lib/src/ui/host_dialog.dart`), remove the *Full protocol*
     `ExpansionTile` (`Key('host-full-protocol')`). Render the current attempt's entries (steps and
     any unmatched `porelo-host` lines in arrival order) in one list, followed by a collapsed section
     at the end for each earlier attempt labeled `"Earlier attempt, HH:MM–HH:MM"`. When there are no
     unmatched lines, render no extra row.
  3. Add a *Copy the protocol* button (`OutlinedButton.icon` or `TextButton.icon` calling
     `Clipboard.setData(ClipboardData(text: ...))`) that copies the full formatted protocol (including
     earlier attempts and unmatched lines) in one click.
  4. Give the protocol list in `HostDialog` its own `ScrollController` that checks whether
     `position.pixels >= position.maxScrollExtent - threshold` before a new entry is added and scrolls
     to the new bottom only when the list was already at the end, keeping the action bar outside the
     scrolling list so new rows never move what the person is about to click.
- **Tests, their harm, red first.**
  - *Harm:* dropping an unmatched stderr line from `porelo-host` when *Full protocol* is removed
    hides an unexpected failure message that did not parse as a JSON step.
  - In `test/host_dialog_test.dart`, feed `HostSession` a plain non-JSON stderr line between two step
    lines across two attempts, and assert that the unmatched line appears as its own entry in the
    protocol list between those steps and in the text copied by *Copy the protocol*, and that the
    first attempt is retained under its `"Earlier attempt, ..."` group when the second attempt starts.
    Break the unmatched-line insertion in `HostSession._line` first and watch the test fail.
  - Words, colors, and layout get no test.

## Acceptance

- The setup dialog has no *Full protocol* section; every step and any unmatched `porelo-host` line
  appear in one protocol list in the order they arrived, with no row added when there are no
  unmatched lines.
- After a retry or resume, earlier runs appear as a collapsed `"Earlier attempt, HH:MM–HH:MM"` group
  at the end of the list.
- Clicking *Copy the protocol* copies the entire protocol text to the clipboard.
- When scrolled up in the protocol list, new steps arriving below do not jump the scroll position or
  move the dialog's buttons; when scrolled to the bottom, the list follows new steps as they arrive.
