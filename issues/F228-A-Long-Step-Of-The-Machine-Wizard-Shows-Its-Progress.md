# F228 — A Long Step Of The Machine Wizard Shows Its Progress

**Status:** Analyzed; placed with the bug fixes after the operator's tests of sprints 6 to 6i.
**Size:** S - *Install Tresorit for <user>* in phases with bytes and total, *Run Porelo's setup script* with its last
line, and their tests; about 2 hours.

**What must be true.** While *Install Tresorit for <user>* runs (step *Your own drive* of the machine wizard), the step
shows which phase it is in and how far it is, instead of one spinner and one sentence:

1. *Fetching Tresorit's installer: 23 of 140 MB* (the total from the answer's length, else the bytes alone);
2. *Sending it to <user> on the machine: 61 of 140 MB*;
3. *Checking its signature on the machine…*;
4. *Installing and starting it…*.

A phase that fails says which one. The same holds for the wizard's other wait that takes minutes, *Running Porelo's
setup script as root…*: below it, the script's last line of output, as the server's protocol shows its step.

## Why

Seen in the operator's round (walk 20, 6g-B.2): after *Install Tresorit for drive* there was only a spinner and
"Fetching Tresorit's installer and checking it on the machine…" for over a minute. The operator wants to see the bytes
transferred while the installer downloads, and the check as a phase of its own. On the machine the install had ended
well (`tresorit-daemon` running as `drive`); nothing showed that it was still moving.

## Where it runs, read from the code

- The installer (~140 MB) is fetched **on this desktop**, in `SetupRun._fetchOverHttps` (`setup_run.dart`), which reads
  the answer's stream into a buffer: its length and each chunk are there to count.
- It is then sent to the work user over ssh as base64 on standard input (`MachineSetup.sendToUser`): the bytes written
  to that pipe are there to count.
- The check and the install run on the machine as the work user (`TresoritInstaller.checkScript`, then the install);
  they are phases with a name, without a measure.
- `prepare()` runs Porelo's setup script as root over ssh with its output collected at the end; its lines can be
  passed on as they come.

## Other long waits in the interface

| Wait | Shows today | State |
|---|---|---|
| A server's setup (`porelo-host up`) | its protocol, step, time left | shows progress |
| *Run its setup again* | nothing in the row | [F226](README.md#f226) |
| The wizard's *Install Tresorit*, *Running Porelo's setup script* | one sentence | **this issue** |
| The wizard's other steps (keys, root login, doctor, vault, sign-in, sync) | one sentence | take seconds, as they are |
| Long CLI verbs of the transports (`setup`, `publish`) | their end line | Matrix's own finding, not this interface |

## Plan

- `SetupRun`: `doing` gains an optional `progress` (`phase`, `done`, `total`), set by `_fetchOverHttps` per chunk and by
  `sendToUser` per block it writes (it writes the base64 in blocks instead of at once); `notifyListeners` at most four
  times a second.
- The wizard's busy line shows the phase and *n of m MB* where `progress` is set; `prepare()` passes the script's last
  line.
- **Red first:** with a stand-in fetch that yields three chunks of a known total and a stand-in send, the step shows
  *Fetching … 1 of 3 MB*, then *Sending … *, then *Checking …*; a refused check names the checking phase.

## Acceptance

- During *Install Tresorit*, the step shows the phase and the megabytes moved, and the total where Tresorit gives it.
- During *Running Porelo's setup script*, its last line is shown.
