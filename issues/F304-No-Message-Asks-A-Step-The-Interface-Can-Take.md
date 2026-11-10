# F304 — No Message Asks A Step The Interface Can Take

```json
{
  "$schema": "issue-1.json",
  "id": "F304",
  "title": "No Message Asks A Step The Interface Can Take",
  "state": "Idea",
  "size": "M",
  "priority": "Medium",
  "rank": 16,
  "blockedBy": [],
  "covers": "No message tells the person to do a step the interface can take itself; actions read what they need and say so."
}
```

**Why this size.** every refusal and unavailable reason that sends the person to a read, refresh or retry the interface can
run itself, with their tests; no contract with another repository.

**How it stands.** Waits for the foo test.

**Severity.** High.

**What must be true.** No message tells the person to do a step the interface can do itself. Where an action needs a
fresh read (the registry, the project's verified access, the person's card, a host's state), the action runs that read
itself, shows that it does ("Reading the registry…"), and goes on; a message names only what the person alone can
decide or provide: a choice, a key in their agent, a confirmation, an operator's hand.

## Why

`PoreloOrganizationSource._ask` in `lib/src/app/porelo_organization_source.dart` handles an unknown forge host key
by offering `confirmForgeHost` and retrying once after confirmation. `trustOrganizationForge` in
`lib/src/ui/organization_access_dialogs.dart` supplies that dialog, so this case asks no terminal command.

Other messages still instruct a step: `lib/src/app/porelo_organization_source.dart` says "The project revision is
unknown. Read it before signing a change." and `lib/src/ui/organization_project_pages.dart` says to read the project
again before signing. Those messages do not meet the promise to run a needed read within the action.
`lib/src/ui/host_dialog.dart` instructs root SSH bootstrap in a separate terminal, `lib/src/app/run_here.dart`
suggests running a command in a terminal after a timeout, and `_NotReady` in `lib/src/ui/start_work_view.dart`
displays the daemon's readiness instructions, with fix and retry actions where supplied. The rule stands: each message
that sends the operator to a terminal becomes a finding of the foo test.
The plan's quoted registry, access-checkout and pending-change instructions have no matching strings in `lib/src`;
their cases remain below without changing the required behavior.

## The shape

- An action needing a fresh read reads, waits for a read that runs, or reads again after a failed one, itself; only a
  read that fails again is said, in its own words, with *Read again* as an action, not as an instruction.
- A message for a pending change offers the change's own *Retry* or *Resume* button rather than saying "Retry … first".
- A message that names what only the person can do stays: choosing a person, unlocking the signing agent, a decision.

## Plan

- Instruction cases to cover, searched with `git grep -hoE "'(Refresh|Read|Retry) [^']+\.'" -- lib/src`, among them:
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
