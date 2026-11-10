# F366 — Preparing A Machine Says What It Waits For

```json
{
  "$schema": "issue-1.json",
  "id": "F366",
  "title": "Preparing A Machine Says What It Waits For",
  "state": "Review",
  "size": "M",
  "priority": "Medium",
  "rank": 54,
  "blockedBy": [],
  "covers": "*Prepare a machine* says beside its button what it waits for, and a stopped login shows its words and exit code, naming root still closed."
}
```

**Why this size.** words beside the button in four states, the login's output and exit code kept, and a measurement on a real window.

**What must be true.** In *Prepare a machine*, a person always reads what the dialog waits for and why a step stopped. In the foo test *Prepare the machine* stayed grey for a long time with nothing saying why, and the operator nearly closed the dialog. Then it went live before its required `sudo` command had run, and the run stopped on `ssh` with an empty reason, "the provider or the host could not be reached", for a server that answers.

**Decided:** the button is not held for the `sudo` step. The run's first line is the check, with the words above.

## The empty reason

The cause was found in the foo test: `ssh root@…` answered "Please login as the user "ubuntu" rather than the user "root".". That is a cloud image's line in root's `authorized_keys`: the key is accepted, it prints to standard output, waits 10 s and exits non-zero, which is cloud-init's behaviour as remembered, not read.

- `OpenSsh.run` keeps standard error only. The call in `HostRun._rented` passes no `onLine`, so the words are dropped, and the exit code is not kept either.
- `_unreachable` then says the host could not be reached. Any exit but ssh's own 255 means it was reached, so this is false.
- The window keeps `words: ""`, and nothing elsewhere holds the reason.

**The shape:**

- This step keeps standard output and the exit code as well, and they reach the person.
- An exit other than 255 never says "could not be reached".
- This exact case is named: "root is still closed: run the command above", with the command shown again. Nothing changed on the machine, and it says that too.
- No refusal is ever shown with an empty reason: the window says what it does know.

## The required command

*Prepare the machine* is live though the `sudo` command has not run, and nothing checks it. Skipping it costs a stop, with nothing changed on the machine.

**The shape:** the steps stand in their order, as in the issue on a host key fetched too early, and the run's first ssh line is the check, with the words above. A check of its own before the button is not needed while that stop is clear and safe.

## The grey button

*Prepare the machine* waits on four things. By reading:

| It waits for | What says so today |
|---|---|
| The re-read of the identity and the organization | A line at the top of the dialog's scrolling body |
| A running key fetch, up to about 5 s | A line under the fetch button, in that body |
| A key at all | Nothing, unless the fetch failed |
| The tick "I compared this fingerprint" | Nothing |

**The long wait is not explained.** `porelo org --json` took 1.8 s, twice, on the operator's computer with no agent, and the identity read is not timed. So what held the button in the foo test is not known, and it may be the tick or the words scrolled out of sight.

"read 21 minutes ago" on the page behind is that page's own older read, as the dialog's read does not update it.

**The shape:** the words stand beside the button, where they stay in sight, and say which of these it waits for now. The dialog's fresh read also updates the page behind.

## Plan

1. The `ssh` step keeps standard output and the exit code. Only 255 says "could not be reached"; a cloud image closing root says "root is still closed", and the dialog shows the command again.
2. The dialog's words stand beside *Prepare the machine*, once, and say which of the four it waits for.
3. Waiting for the morning: the time to a live button on a real window, and the dialog's read updating the page behind.

## Acceptance

- A login that succeeds and exits non-zero with words on standard output shows those words and the exit code. Seen to fail first.
- Root still closed names the command to run; "could not be reached" appears only for ssh's own failure.
- With *Prepare the machine* grey, the dialog says why in text beside the button, in each of the four states.
- The time from opening the dialog to a live button is measured on a real window, naming what took it.

## To be checked

- Whether the identity read waits on the agent, and how long.
- The same empty reason on the host's other steps, which use the same call.
