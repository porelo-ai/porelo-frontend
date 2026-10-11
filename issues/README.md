# Frontend Requirements

The interface people use to work with a Sokar backend, as what must be true for a person using it.
One file per requirement, `F<nn>-Short-Title.md`, each with its acceptance criteria; the number is
identity, not order. Everything is built against `org.fuin.sokar.Tasks1` over the daemon's socket:
[Design](../doc/design.md) says what the interface is made of, [Backend API](../doc/Backend-API.md)
how it talks to a daemon, and [what the contract does not yet cover](../doc/Contract-Gaps.md) what
the backend has no method or field for yet.

**Now** serves the MVP: one person, one machine, one agent, from installing Sokar to reviewed work
pushed, all from the interface, for someone who has never used Sokar. **Soon** follows right after
it, **Later** is the rest. Each table is in the order to do the work; **Size** is how big what
remains is, `—` for an issue built and waiting only for its walk; **Open questions** counts the
issue's *To be checked*. A finished issue is deleted, file and row together, once what outlives it
is in `doc/` or `AGENTS.md`; decisions are in [doc/decisions.md](../doc/decisions.md).

### Now

| # | Status | Size | Blocked by | What it covers | Open questions |
|---|---|---|---|---|---|
| [F79](F79-What-Walk-8-Found-In-The-Interface.md) | built, to be walked | — | — | Tiles, *Needs you*, *Join* and talking read at a glance, an action's effect seen at once. | 0 |
| [F71](F71-The-Sign-In-Terminal-Shows-Where-Typing-Goes.md) | built, to be walked | — | — | A terminal waiting for input shows where typing goes. | 1 |
| [F68](F68-A-Refusal-Says-What-To-Do-About-It.md) | mostly built, to be walked | — | — | A refusal says what to change, and where. | 0 |
| [F69](F69-The-New-Machine-Wizard-Offers-What-Is-Published.md) | built, to be walked | — | — | The new-machine wizard offers what the package index has today, in today's words. | 1 |

### Soon

| # | Status | Size | Blocked by | What it covers | Open questions |
|---|---|---|---|---|---|
| [F101](F101-What-The-Build-Of-A-Push-Did.md) | built, to be walked | — | `sokar` B37 on `main` | What the build of the work's last push did, on its tile and in its detail. | 0 |
| [F100](F100-A-File-Handed-To-A-Running-Task.md) | built, to be walked | — | `sokar` B39 on `main` | A file handed to a running task, taken back, and its record. | 1 |
| [F99](F99-An-Attached-Agent-Shown-At-Rest-Or-Working.md) | blocked | S | `sokar` B118 | A work tile says whether an attached agent is at rest or working. | 1 |
| [F93](F93-Connections-Rare-Actions-Out-Of-The-Way.md) | open | S | — | Connections' rare actions in its ⋮. | 2 |
| [F91](F91-One-Way-To-Show-Loading.md) | open | M | — | Every view shows the same way that it is reading. | 2 |
| [F94](F94-A-Projects-Keys-Told-In-One-Place.md) | open | M | — | A project's keys told in one place, the signing key checked against a branch rule. | 3 |
| [F95](F95-A-Waiting-Push-Fetched-Here.md) | open | M | — | A waiting push fetched here, into a clone the person chooses. | 3 |
| [F96](F96-Keys-A-Machine-No-Longer-Knows.md) | open | M | — | Clearing a machine also removes the forge keys it no longer knows. | 3 |
| [F97](F97-Forwarding-Measured-Against-GitHub.md) | open | M | — | Forwarding to a chosen branch measured against GitHub. | 3 |
| [F105](F105-A-Tasks-Terminal-In-The-Interface-As-Outside-It.md) | open | M | — | A task's terminal in the interface behaves as in a plain terminal. | 2 |
| [F104](F104-A-Project-Followed-From-A-File.md) | blocked | M | `sokar` B160 | A project followed from a bundle or a directory; offline projects again. | 2 |
| [F77](F77-What-A-Piece-Of-Work-Did-Is-One-Page.md) | open | XL | — | What a piece of work did, on one page with one timeline. | 4 |
| [F78](F78-A-Waiting-Push-Is-Reviewed-As-At-A-Forge.md) | open | M | — | A waiting push read as a pull request. | 3 |
| [F107](F107-Code-Comments-In-The-Review.md) | blocked | L | `sokar` B166, B171 | Comments on lines in the review: written, read with their origin, held and released. | 3 |
| [F108](F108-A-Machine-Over-Ssh-From-Windows.md) | open | M | — | On Windows, a machine over ssh is reached through the relay, as a WSL distribution is. | 2 |
| [F74](F74-A-Waiting-Pushs-Tests-Run-In-A-Container-Of-Its-Own.md) | blocked | M | `sokar` B95 | A waiting push's tests run in a container of their own on the machine. | 3 |
| [F59](F59-A-Project-From-A-Repository-Measured-Against-GitHub.md) | blocked | S | a GitHub token and test repositories from the operator | Making a project from a repository measured against GitHub. | 3 |
| [F81](F81-The-Setup-Script-Checked-By-Its-Signature.md) | blocked | M | `sokar` B99 | The setup script verified by its signature before it runs. | 4 |
| [F84](F84-A-Signing-Key-Found-Or-Made-From-The-Window.md) | open | M | — | A signing key chosen from a file or made from the window. | 5 |

### Later

| # | Status | Size | Blocked by | What it covers | Open questions |
|---|---|---|---|---|---|
| [F88](F88-A-Nickname-For-Each-Agent.md) | blocked | M | `sokar` (`@label`, the agent card), `sokar-message-matrix` (the display name) | A nickname for each agent. | 2 |
| [F64](F64-The-Guided-Walk-As-A-Package-Of-Its-Own.md) | package of its own built, the rest open | L | — | The guided walk as a package any Flutter app can use. | 3 |
| [F75](F75-One-Definition-For-A-UI-Test-And-A-Guided-Walk.md) | blocked | XL | `flutter-guided-walk`: a scenario that is also a walk | Each scenario is also a walk. | 4 |
| [F72](F72-Forges-Beyond-GitHub.md) | blocked | M | the operator: which forge next | Forges beyond GitHub. | 3 |
| [F37](F37-Reach-A-Machine-Without-An-ssh-Binary.md) | blocked | L | the operator: a mobile client | A machine reached without an `ssh` binary. | 5 |
| [F52](F52-Release-A-Devices-Key-Only-With-A-Touch-Or-A-PIN.md) | open | XL | — | A device's key released only with a touch or a PIN. | 4 |
| [F102](F102-A-Sokar-In-WSL-Reached-From-Windows.md) | open | M | — | The interface on Windows reaches a Sokar in WSL through `wsl.exe`, with no ssh and no open port. | 2 |
| [F62](F62-An-Organisations-Policy-Is-Shown.md) | blocked | M | `sokar`'s part of `sokar-project` PJ16 | An organisation's policy shown. | 1 |
