# Frontend Requirements

The interface people use to work with a Sokar backend, as what must be true for a person using it.
One file per requirement, `F<nn>-Short-Title.md`, each with its acceptance criteria; the number is
identity, not order. Everything is built against `org.fuin.sokar.Tasks1` over the daemon's socket:
[Design](../doc/design.md) says what the interface is made of, [Backend API](../doc/Backend-API.md)
how it talks to a daemon, and [what the contract does not yet cover](../doc/Contract-Gaps.md) what
the backend has no method or field for yet.

Grouped by state, the group's heading naming it, as `AGENTS.md` says how an issue moves through
them; within a group the order is the priority. **Size** is how big what remains is, `—` for an
issue in Review; **Open questions**, in *Analyzed* only, counts what waits on the operator, the
issue's *Open questions*; what an agent finds out itself stands under *To be checked* and is not
counted. A finished issue is deleted, file and row together, once what outlives it is in `doc/` or
`AGENTS.md`; decisions are in [doc/decisions.md](../doc/decisions.md).

### Review

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f79"></a>[F79](F79-What-Walk-8-Found-In-The-Interface.md) | — | — | Tiles, *Needs you*, *Join* and talking read at a glance, an action's effect seen at once. |
| <a id="f71"></a>[F71](F71-The-Sign-In-Terminal-Shows-Where-Typing-Goes.md) | — | — | A terminal waiting for input shows where typing goes. |
| <a id="f68"></a>[F68](F68-A-Refusal-Says-What-To-Do-About-It.md) | — | — | A refusal says what to change, and where. Built but for an organisation's approval of a fine-grained token. |
| <a id="f69"></a>[F69](F69-The-New-Machine-Wizard-Offers-What-Is-Published.md) | — | — | The new-machine wizard offers what the package index has today, in today's words. |
| <a id="f101"></a>[F101](F101-What-The-Build-Of-A-Push-Did.md) | — | — | What the build of the work's last push did, on its tile and in its detail. |
| <a id="f100"></a>[F100](F100-A-File-Handed-To-A-Running-Task.md) | — | — | A file handed to a running task, taken back, and its record. |

### Implementing

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f102"></a>[F102](F102-A-Sokar-In-WSL-Reached-From-Windows.md) | M | — | The interface on Windows reaches a Sokar in WSL through `wsl.exe`, with no ssh and no open port. Stages 1 to 3 built and published; the MSIX installed on the runner, notifications and the test on Windows left. |

### Analyzed

| # | Size | Blocked by | What it covers | Open questions |
|---|---|---|---|---|
| <a id="f109"></a>[F109](F109-The-Interface-On-macOS-With-Sokar-In-A-Local-VM.md) | XL | — | The interface on macOS, with Sokar in a local Lima VM set up from the window, and remote machines over ssh. | — |
| <a id="f99"></a>[F99](F99-An-Attached-Agent-Shown-At-Rest-Or-Working.md) | S | `sokar` [B118](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b118) | A work tile says whether an attached agent is at rest or working. | — |
| <a id="f93"></a>[F93](F93-Connections-Rare-Actions-Out-Of-The-Way.md) | S | — | Connections' rare actions in its ⋮. | 1 |
| <a id="f91"></a>[F91](F91-One-Way-To-Show-Loading.md) | M | — | Every view shows the same way that it is reading. | 1 |
| <a id="f94"></a>[F94](F94-A-Projects-Keys-Told-In-One-Place.md) | M | — | A project's keys told in one place, the signing key checked against a branch rule. | 2 |
| <a id="f95"></a>[F95](F95-A-Waiting-Push-Fetched-Here.md) | M | — | A waiting push fetched here, into a clone the person chooses. | 2 |
| <a id="f96"></a>[F96](F96-Keys-A-Machine-No-Longer-Knows.md) | M | — | Clearing a machine also removes the forge keys it no longer knows. | 2 |
| <a id="f97"></a>[F97](F97-Forwarding-Measured-Against-GitHub.md) | M | — | Forwarding to a chosen branch measured against GitHub. | 3 |
| <a id="f105"></a>[F105](F105-A-Tasks-Terminal-In-The-Interface-As-Outside-It.md) | M | — | A task's terminal in the interface behaves as in a plain terminal. | 2 |
| <a id="f104"></a>[F104](F104-A-Project-Followed-From-A-File.md) | M | `sokar` [B160](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b160) | A project followed from a bundle or a directory; offline projects again. | — |
| <a id="f77"></a>[F77](F77-What-A-Piece-Of-Work-Did-Is-One-Page.md) | XL | — | What a piece of work did, on one page with one timeline. | 1 |
| <a id="f78"></a>[F78](F78-A-Waiting-Push-Is-Reviewed-As-At-A-Forge.md) | M | — | A waiting push read as a pull request. | 1 |
| <a id="f107"></a>[F107](F107-Code-Comments-In-The-Review.md) | L | `sokar` [B166](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b166), [B171](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b171) | Comments on lines in the review: written, read with their origin, held and released. | 2 |
| <a id="f108"></a>[F108](F108-A-Machine-Over-Ssh-From-Windows.md) | M | — | On Windows, a machine over ssh is reached through the relay, as a WSL distribution is. | — |
| <a id="f74"></a>[F74](F74-A-Waiting-Pushs-Tests-Run-In-A-Container-Of-Its-Own.md) | M | `sokar` [B95](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b95) | A waiting push's tests run in a container of their own on the machine. | 1 |
| <a id="f59"></a>[F59](F59-A-Project-From-A-Repository-Measured-Against-GitHub.md) | S | a GitHub token and test repositories from the operator | Making a project from a repository measured against GitHub. | 2 |
| <a id="f81"></a>[F81](F81-The-Setup-Script-Checked-By-Its-Signature.md) | M | `sokar` [B99](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b99) | The setup script verified by its signature before it runs. | — |
| <a id="f84"></a>[F84](F84-A-Signing-Key-Found-Or-Made-From-The-Window.md) | M | — | A signing key chosen from a file or made from the window. | 2 |
| <a id="f88"></a>[F88](F88-A-Nickname-For-Each-Agent.md) | M | `sokar` (`@label`, the agent card), `sokar-message-matrix` (the display name) | A nickname for each agent. | — |
| <a id="f64"></a>[F64](F64-The-Guided-Walk-As-A-Package-Of-Its-Own.md) | L | — | The guided walk as a package any Flutter app can use. | 2 |
| <a id="f75"></a>[F75](F75-One-Definition-For-A-UI-Test-And-A-Guided-Walk.md) | XL | `flutter-guided-walk`: a scenario that is also a walk | Each scenario is also a walk. | 1 |
| <a id="f72"></a>[F72](F72-Forges-Beyond-GitHub.md) | M | the operator: which forge next | Forges beyond GitHub. | 2 |
| <a id="f37"></a>[F37](F37-Reach-A-Machine-Without-An-ssh-Binary.md) | L | the operator: a mobile client | A machine reached without an `ssh` binary. | 3 |
| <a id="f52"></a>[F52](F52-Release-A-Devices-Key-Only-With-A-Touch-Or-A-PIN.md) | XL | — | A device's key released only with a touch or a PIN. | 1 |
| <a id="f62"></a>[F62](F62-An-Organisations-Policy-Is-Shown.md) | M | `sokar`'s part of `sokar-project` [PJ16](https://github.com/sokar-ai/sokar-project/blob/main/issues/README.md#pj16) | An organisation's policy shown. | — |
