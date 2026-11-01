# F304 — No Message Asks A Step The Interface Can Take

**Status:** Idea.
**Severity:** high.
**Size:** M - every refusal and unavailable reason that sends the person to a read, refresh or retry the interface can
run itself, with their tests; no contract with another repository.

**What must be true.** No message tells the person to do a step the interface can do itself. Where an action needs a
fresh read (the registry, the project's verified access, the person's card, a host's state), the action runs that read
itself, shows that it does ("Reading the registry…"), and goes on; a message names only what the person alone can
decide or provide: a choice, a key in their agent, a confirmation, an operator's hand.

## Why

Seen in the sprint 6m walk (2026-11-01). Adding a developer refused with "Refresh the verified registry before
changing this project. Read the verified project admission first." while a periodic registry read ran. michi:
"Toll, dass mich die Oberfläche anweist etwas zu tun was sie selber machen kann...". Commit b8fa381e and 5090e9e5 fixed
it for a project's person changes; the same pattern remains elsewhere.

## The shape

- An action needing a fresh read reads, waits for a read that runs, or reads again after a failed one, itself; only a
  read that fails again is said, in its own words, with *Read again* as an action, not as an instruction.
- A message for a pending change offers the change's own *Retry* or *Resume* button rather than saying "Retry … first".
- A message that names what only the person can do stays: choosing a person, unlocking the signing agent, a decision.

## Plan

- Today's instances, found with `grep -rhoE "'(Refresh|Read|Retry) [^']+\.'" lib/src`, among them:
  - "Refresh the registry before replacing a key.", "… before making a backup key.", "… before changing a host.",
    "Refresh the registry, then verify the signers again." (key recovery, backup key, host access);
  - "Refresh the selected project person before changing access.", "Refresh the verified access state before making a
    change.", "Refresh the project before replacing a key." (project access, key replacement);
  - "Read your own key and card first.", "Read the project’s verified access first.", "Read the host and central
    state before retrying an unconfirmed transfer.", "Open and verify the access checkout first.";
  - "Retry the pending project change first." and "… before making another." (project access).
- Each becomes a read the action runs, or a button offered beside the message.
- **Red first:** per instance, a test where the stale state is fixable by a read: the action ends without the message.

## Acceptance

- `grep` for those instructions finds none that names a read or refresh the interface can run.
- Every action that reads first shows that it reads.
