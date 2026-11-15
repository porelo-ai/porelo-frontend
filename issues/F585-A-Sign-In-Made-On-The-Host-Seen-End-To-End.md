# F585 — A Sign-In Made On The Host Seen End To End

```json
{
  "$schema": "issue-1.json",
  "id": "F585",
  "title": "A Sign-In Made On The Host Seen End To End",
  "state": "Idea",
  "size": "S",
  "priority": "High",
  "rank": 17,
  "blockedBy": ["F584"],
  "covers": "Story ST364: signing an agent in on a host from Import from this computer is held by a feature scenario on the stand-in machines, a rotating source and an API key side by side, and checked once against porelo with Core's host sign-in."
}
```

**Why this size.** A scenario and its steps on the feature world's stand-ins, the mock daemon's answers for the new
fields, and one live check.

**What must be true.** The whole way, from the provider row's button to the agent's row after the host's own
sign-in, holds as one, and an API key beside it is still carried.

## Plan

- **The mock daemon** (`test/features/support/`, the stand-in `PoreloBackend`) answers the fields Agent Core shapes
  for [F584](README.md#f584): a source that rotates, the host login's link or code and its states, and
  `SealCredential` refusing a rotating source.
- **A scenario** in `test/features/carrying_a_credential.feature`: a host row's *Import from this computer…* shows a
  provider login as *Made on the host* and an API key as carried; *Sign in on the host* shows the code, the login ends
  stored, and the agent's row says *Signed in on the host*; the API key is carried in the same dialog. Red first by
  taking the rotating mark out.
- **Live, once**, against porelo with Core's change on a host this window reaches: the dialog's link or code is the
  host's, the browser here confirms it, and the host's vault holds the agent's sign-in; said in *Built*.

## Acceptance

- The scenario red first and green; the live check written down with the porelo commit it ran against.
