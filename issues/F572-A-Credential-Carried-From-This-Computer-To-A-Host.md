# F572 — A Credential Carried From This Computer To A Host

```json
{
  "$schema": "issue-1.json",
  "id": "F572",
  "title": "A Credential Carried From This Computer To A Host",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 17,
  "blockedBy": [],
  "covers": "Story ST362: a remote machine's provider row offers Import from this computer, a small dialog with this computer's vault entries and the local agents' own sign-in files side by side, and carries the one chosen to the host's vault, never shown, logged or put in a command line."
}
```

**Why this size.** The window's half: one dialog, its sources from porelo and the local readers, and the call that carries. porelo carries the value (Agent Core), and each agent's local sign-in file has a reader (Agent Smith).

**What must be true.** A person signs in once and carries that sign-in to each host from the window, without seeing or typing its value.

## Plan

The window's half of ST362. Agent Core files porelo's half (export from one vault, put into the other over the
machine's connection, porelo to porelo). Agent Smith files the readers of each local agent's own sign-in files, one
per agent adapter.

- A remote machine's provider row offers *Import from this computer…*.
- The dialog lists both kinds side by side. One is the entries of this computer's porelo vault for that provider.
  The other is the local agents' own sign-in files for it, for every provider available locally (Claude Code's,
  Codex's, Gemini's, pi's and omp's, as the local import finds them).
  - Each source shows what it is (kind, account if known, age or expiry if known), never its value.
  - A source that cannot be carried is greyed, with the reason.
- The person picks one, and porelo carries it to the host's vault, and into the agent's own file there where the
  agent needs one. The value is never shown, logged or put in a command line.

## Acceptance

- A guard for the dialog's two kinds and a greyed source; one that the carrying call names the source and never a value; a feature scenario against stand-ins. Each red first.
