# F383 — The Terminal Stays Dark

```json
{
  "$schema": "issue-1.json",
  "id": "F383",
  "title": "The Terminal Stays Dark",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 39,
  "blockedBy": [],
  "covers": "A terminal stays dark in the light theme, and answers a program asking for its colours."
}
```

**Why this size.** sized at the move of the issues' data into their heads, from the change built: a terminal kept dark in the light theme.

**What must be true.** In the light theme a terminal stays dark and looks as it does in a console. The tab's head and the page around it follow the theme; the terminal does not. A program asking for the colours hears them, so an agent's own theme picks dark, and tmux's status line reads.

## Why

Light was badly readable: pale text on white, and tmux's status line dark on green. An agent chooses its colours for a dark terminal, or asks, and nothing answered.

## Acceptance

- A session has the dark colours in both themes. Seen to fail first.
- `OSC 10` and `OSC 11` with `?` are answered. Seen to fail first.
- Black on green, tmux's default status line, passes the contrast check.

## Decided while building

- **An agent's log follows the terminal,** as the two stand side by side under *Running*; the bars around both follow the window.
- **Only the two queries are answered:** a program setting the colours is still ignored.

## Open questions

## To be checked

- A logged-in agent in the window, whether it picks dark. Inside the container's tmux, through a real attach, a shell's `OSC 10` and `OSC 11` were answered with these colours, and tmux's status line is black on green.
