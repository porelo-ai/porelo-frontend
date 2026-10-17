# Frontend Requirements

The interface people use to work with a Porelo backend, as what must be true for a person using it.
One file per requirement, `F<nn>-Short-Title.md`, each with its acceptance criteria; the number is
identity, not order. Everything is built against `org.fuin.porelo.Tasks1` over the daemon's socket:
[Design](../doc/design.md) says what the interface is made of, [Backend API](../doc/Backend-API.md)
how it talks to a daemon, and [what the contract does not yet cover](../doc/Contract-Gaps.md) what
the backend has no method or field for yet.

Grouped by state, the group's heading naming it, as `AGENTS.md` says how an issue moves through
them; within a group the order is the priority. **Size** is how big what remains is, `—` for an
issue in Review or not yet analyzed; **Open questions**, in *Analyzed* only, counts what waits on the operator, the
issue's *Open questions*; what an agent finds out itself stands under *To be checked* and is not
counted. A finished issue's file is deleted once what outlives it is in `doc/` or `AGENTS.md`;
its row stays under *Finished*, with one sentence of what was built; decisions are in [doc/decisions.md](../doc/decisions.md).

### Review

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f121"></a>[F121](F121-The-Interface-In-Porelos-Look.md) | M | — | The interface in the look of Porelo's website, with a light mode beside the dark one, and the logo as its icon. |
| <a id="f120"></a>[F120](F120-The-Interface-Renamed-Porelo.md) | M | — | The interface renamed Porelo: its package, binary, desktop ids, settings, packages and the daemon's contract. |
| <a id="f79"></a>[F79](F79-What-Walk-8-Found-In-The-Interface.md) | — | — | Tiles, *Needs you*, *Join* and talking read at a glance, an action's effect seen at once. |
| <a id="f71"></a>[F71](F71-The-Sign-In-Terminal-Shows-Where-Typing-Goes.md) | — | — | A terminal waiting for input shows where typing goes. |
| <a id="f68"></a>[F68](F68-A-Refusal-Says-What-To-Do-About-It.md) | — | — | A refusal says what to change, and where. |
| <a id="f69"></a>[F69](F69-The-New-Machine-Wizard-Offers-What-Is-Published.md) | — | — | The new-machine wizard offers what the package index has today, in today's words. |
| <a id="f101"></a>[F101](F101-What-The-Build-Of-A-Push-Did.md) | — | — | What the build of the work's last push did, on its tile and in its detail. |
| <a id="f100"></a>[F100](F100-A-File-Handed-To-A-Running-Task.md) | — | — | A file handed to a running task, taken back, and its record. |

### Implementing

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f122"></a>[F122](F122-The-Interface-Called-Porelo-Control-Tower.md) | XS | — | The interface called Porelo Control Tower wherever a person reads its name. |

### Backlog

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f118"></a>[F118](F118-An-Upstream-That-Cannot-Be-Read-Said-Before-A-Start.md) | S | — | An upstream that cannot be read said before a start, with what fixes it. |

### Analyzed

| # | Size | Blocked by | What it covers | Open questions |
|---|---|---|---|---|
| <a id="f113"></a>[F113](F113-The-MSIX-Installed-And-Started-In-The-Build.md) | S | — | The MSIX installed and started in the Build's Windows job. | — |
| <a id="f114"></a>[F114](F114-Windows-Notifications-From-The-MSIX.md) | M | — | Windows notifications from the MSIX's identity. | — |
| <a id="f115"></a>[F115](F115-A-Fine-Grained-Token-Waiting-For-An-Organisations-Approval.md) | S | the test organisation at GitHub from the operator | A fine-grained token waiting for an organisation's approval said as waiting. | — |
| <a id="f116"></a>[F116](F116-A-Refused-Ssh-Login-Explained-When-Connecting-Again.md) | S | — | A refused ssh login explained when a machine is connected again, with the key it would take. | — |
| <a id="f117"></a>[F117](F117-What-Walk-8-Left-Unbuilt.md) | M | — | A tile's repository in its heading, a refused release said as an error that stays, the project file taken after one's own push. | — |
| <a id="f119"></a>[F119](F119-The-Code-Changed-Since-The-Skills-Reading-Read-Against-Them.md) | L | — | The code changed since the last skills reading read against the sixteen skills, their versions recorded. | — |

| <a id="f93"></a>[F93](F93-Connections-Rare-Actions-Out-Of-The-Way.md) | S | — | Connections' rare actions in its ⋮. |
| <a id="f91"></a>[F91](F91-One-Way-To-Show-Loading.md) | M | — | Every view shows the same way that it is reading. |
| <a id="f94"></a>[F94](F94-A-Projects-Keys-Told-In-One-Place.md) | M | — | A project's keys told in one place, the signing key checked against a branch rule. |
| <a id="f95"></a>[F95](F95-A-Waiting-Push-Fetched-Here.md) | M | — | A waiting push fetched here, into a clone the person chooses. |
| <a id="f96"></a>[F96](F96-Keys-A-Machine-No-Longer-Knows.md) | M | the test organisation and its token from the operator | Clearing a machine also removes the forge keys it no longer knows. |
| <a id="f97"></a>[F97](F97-Forwarding-Measured-Against-GitHub.md) | M | the test organisation and its token from the operator | Forwarding to a chosen branch measured against GitHub. |
| <a id="f105"></a>[F105](F105-A-Tasks-Terminal-In-The-Interface-As-Outside-It.md) | M | — | A task's terminal in the interface behaves as in a plain terminal. |
| <a id="f78"></a>[F78](F78-A-Waiting-Push-Is-Reviewed-As-At-A-Forge.md) | M | — | A waiting push read as a pull request. |
| <a id="f107"></a>[F107](F107-Code-Comments-In-The-Review.md) | L | `porelo` [B166](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b166), [B171](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b171), [F78](README.md#f78) | Comments on lines in the review: written, read with their origin, held and released. |
| <a id="f74"></a>[F74](F74-A-Waiting-Pushs-Tests-Run-In-A-Container-Of-Its-Own.md) | M | `porelo` [B95](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b95) | A waiting push's tests run in a container of their own on the machine. |
| <a id="f59"></a>[F59](F59-A-Project-From-A-Repository-Measured-Against-GitHub.md) | S | the test organisation, its token and signing key from the operator | Making a project from a repository measured against GitHub. |
| <a id="f84"></a>[F84](F84-A-Signing-Key-Found-Or-Made-From-The-Window.md) | M | — | A signing key chosen from a file or made from the window. |
| <a id="f64"></a>[F64](F64-The-Guided-Walk-As-A-Package-Of-Its-Own.md) | L | — | The guided walk as a package any Flutter app can use. |
| <a id="f75"></a>[F75](F75-One-Definition-For-A-UI-Test-And-A-Guided-Walk.md) | XL | `flutter-guided-walk`: a scenario that is also a walk | Each scenario tagged `@walk` is also a walk. |
| <a id="f72"></a>[F72](F72-Forges-Beyond-GitHub.md) | L | the operator's evaluation licence for Bitbucket Data Center | Forges beyond GitHub: Bitbucket Data Center first, measured against a test installation of its own. |
| <a id="f37"></a>[F37](F37-Reach-A-Machine-Without-An-ssh-Binary.md) | L | — | A machine reached without an `ssh` binary. |
| <a id="f52"></a>[F52](F52-Release-A-Devices-Key-Only-With-A-Touch-Or-A-PIN.md) | XL | — | A device's key released only behind a TPM2 PIN; a touch later. |
| <a id="f109"></a>[F109](F109-The-Interface-On-macOS-With-Porelo-In-A-Local-VM.md) | XL | — | The interface on macOS, with Porelo in a local Lima VM set up from the window, and remote machines over ssh. |
| <a id="f99"></a>[F99](F99-An-Attached-Agent-Shown-At-Rest-Or-Working.md) | S | `porelo` [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118) | A work tile says whether an attached agent is at rest or working. |
| <a id="f104"></a>[F104](F104-A-Project-Followed-From-A-File.md) | M | `porelo` [B160](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b160) | A project followed from a bundle or a directory; offline projects again. |
| <a id="f110"></a>[F110](F110-An-Unattended-Run-Ends-With-A-Line.md) | S | — | An unattended run ends with a line: finished, and where to go next. |
| <a id="f111"></a>[F111](F111-All-Of-A-Pieces-Logs-In-One-Timeline.md) | M | — | All of a piece's logs in one timeline, by time, filterable by source. |
| <a id="f112"></a>[F112](F112-What-A-Piece-Of-Work-Did-In-Words.md) | L | `porelo` [B174](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b174) | What a piece of work did, in words, at the top of its tile. |
| <a id="f108"></a>[F108](F108-A-Machine-Over-Ssh-From-Windows.md) | M | — | On Windows, a machine over ssh is reached through the relay, as a WSL distribution is. |
| <a id="f81"></a>[F81](F81-The-Setup-Script-Checked-By-Its-Signature.md) | M | `porelo` [B99](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b99) | The setup script verified by its signature before it runs. |
| <a id="f88"></a>[F88](F88-A-Nickname-For-Each-Agent.md) | M | `porelo` (`@label`, the agent card, the label handed to the transport) | A nickname for each agent. |
| <a id="f62"></a>[F62](F62-An-Organisations-Policy-Is-Shown.md) | M | `porelo`'s part of `porelo-project` [PJ16](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj16) | An organisation's policy shown. |

### Finished

| # | Title | What was built |
|---|---|---|
| <a id="f102"></a>F102 | A Porelo In WSL Reached From Windows | The interface on Windows, as a ZIP and an MSIX signed by `CN=porelo.ai`, reaching a Porelo in a WSL distribution through `wsl.exe` with no ssh and no open port, and setting Porelo up there; checked on GitHub's Windows runner, untested on a Windows machine. |
