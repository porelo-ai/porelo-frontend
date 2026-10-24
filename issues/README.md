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
| <a id="f118"></a>[F118](F118-An-Upstream-That-Cannot-Be-Read-Said-Before-A-Start.md) | — | — | An upstream that cannot be read said before a start, with what fixes it. |

### Implementing

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f162"></a>[F162](F162-The-Host-Flow-Walked-Against-Stand-Ins.md) | M | — | The host flow walked in a development build against a stand-in `porelo-host`, a host reached through a stand-in `ssh` and the mock daemon, and stand-in terminal steps. |
| <a id="f160"></a>[F160](F160-The-Interfaces-Terminals-Paste-As-Linux-Terminals-Do.md) | S | — | The interface's terminals pasting on `Ctrl+Shift+V` and `Shift+Insert` as well as `Ctrl+V`, with the shortcut named beside the terminal. |
| <a id="f152"></a>[F152](F152-Secrets-For-A-Host-Typed-Only-In-A-Terminal.md) | M | — | The drive login and vault passphrase at the host stop typed into an ssh terminal on the host, never into a form of the interface. |
| <a id="f156"></a>[F156](F156-The-Host-Dialogs-Fields-And-Words.md) | S | — | Expanding `~` in host dialog paths, hiding repository fields until the tresor folder is chosen, scrolling to a stop, and explaining the VPN file and `/etc/wireguard` commands in plain words. |

### Backlog

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f161"></a>[F161](F161-A-Starts-Progress-And-Refusal-In-Words.md) | M | `porelo` [B268](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b268) | Task start showing its step and what it waits on in plain words, stopping with the cause when a dependency fails, and explaining a refused `porelo.yml`. |
| <a id="f155"></a>[F155](F155-A-Host-Taken-Down-From-Machines.md) | S | — | Taking a host down from *Machines* using its stored record, a billing and reconnection warning with take-down beside *Remove from this list*, and the setup dialog keeping its last values. |
| <a id="f157"></a>[F157](F157-A-Persons-Terminal-Steps-Offered-By-The-Interface.md) | M | — | Local terminals opened with the command filled in for the WireGuard setup, `porelo talk join`, and the room's homeserver ssh tunnel, with the client details and mention-pill hint. |
| <a id="f154"></a>[F154](F154-A-Host-Stands-In-Machines-While-It-Is-Prepared.md) | M | `porelo-host` [HO21](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho21) | A host being prepared shown at once in *Machines* as *In preparation* with its plain-words step, time left, protocol and *Needs you* link, and added by itself when ready. |
| <a id="f153"></a>[F153](F153-A-Forges-Token-By-The-Providers-Own-Login.md) | L | ships with `porelo` [B269](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b269) | A forge reached by its own login, the person's token kept in each machine's vault, and deploy keys gone. |
| <a id="f99"></a>[F99](F99-An-Attached-Agent-Shown-At-Rest-Or-Working.md) | S | `porelo` [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118) | A work tile says whether an attached agent is at rest or working. |
| <a id="f108"></a>[F108](F108-A-Machine-Over-Ssh-From-Windows.md) | M | — | On Windows, a machine over ssh is reached through the relay, as a WSL distribution is. |
| <a id="f117"></a>[F117](F117-What-Walk-8-Left-Unbuilt.md) | M | — | A tile's repository in its heading, a refused release said as an error that stays, the project file taken after one's own push. |
| <a id="f111"></a>[F111](F111-All-Of-A-Pieces-Logs-In-One-Timeline.md) | M | — | All of a piece's logs in one timeline, by time, filterable by source. |
| <a id="f147"></a>[F147](F147-Every-Repository-Of-Default-Offered-To-Start-In.md) | XS | — | Starting in default offers every repository; the first is no longer hidden as its own. |

### Analyzed

| # | Size | Blocked by | What it covers | Open questions |
|---|---|---|---|---|
| <a id="f164"></a>[F164](F164-Putting-A-Project-On-A-Server-Step-By-Step.md) | L | — | Putting a project on a server as a wizard of explained steps with an indicator, back and next, and a summary, on a wizard frame other wizards use too; the drive named as Tresorit, its tresor and folder apart. | — |
| <a id="f137"></a>[F137](F137-The-Collection-Taken-Only-By-Its-Digest.md) | S | porelo-host's release of the tarball and its `SHA256SUMS` | The collection installed on the host only by the digest the package expects, checked here and there. | — |
| <a id="f114"></a>[F114](F114-Windows-Notifications-From-The-MSIX.md) | M | — | Windows notifications from the MSIX's identity. | — |
| <a id="f115"></a>[F115](F115-A-Fine-Grained-Token-Waiting-For-An-Organisations-Approval.md) | S | the test organisation at GitHub from the operator | A fine-grained token waiting for an organisation's approval said as waiting. | — |

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
| <a id="f109"></a>[F109](F109-The-Interface-On-macOS-With-Porelo-In-A-Local-VM.md) | XL | `porelo-project` [PJ55](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj55), on Apple silicon | The interface on macOS, with Porelo in a local Lima VM set up from the window, and remote machines over ssh. |
| <a id="f104"></a>[F104](F104-A-Project-Followed-From-A-File.md) | M | `porelo` [B160](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b160) | A project followed from a bundle or a directory; offline projects again. |
| <a id="f112"></a>[F112](F112-What-A-Piece-Of-Work-Did-In-Words.md) | L | `porelo` [B174](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b174) | What a piece of work did, in words, at the top of its tile. |
| <a id="f81"></a>[F81](F81-The-Setup-Script-Checked-By-Its-Signature.md) | M | `porelo` [B99](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b99) | The setup script verified by its signature before it runs. |
| <a id="f88"></a>[F88](F88-A-Nickname-For-Each-Agent.md) | M | `porelo` (`@label`, the agent card, the label handed to the transport) | A nickname for each agent. |
| <a id="f62"></a>[F62](F62-An-Organisations-Policy-Is-Shown.md) | M | `porelo`'s part of `porelo-project` [PJ16](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj16) | An organisation's policy shown. |
| <a id="f142"></a>[F142](F142-The-Drafts-Offered-Before-The-First-Task-In-Default.md) | M | `porelo` [B221](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b221) | The machine's proposed tools and rules shown before the first task on a repository in `default`, and the choice passed back. | — |

### Accepted

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f123"></a>[F123](F123-Where-A-Machine-And-A-Project-Stand-In-Their-Organisations-Tree.md) | — | `porelo` [B198](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b198) | Where a machine and a project stand in their organisation's tree, and which settings bind them. |
| <a id="f143"></a>[F143](F143-The-Agent-The-Machine-Found-Is-The-Default.md) | — | `porelo` [B225](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b225) | The agent the machine chooses started when none is picked, its source shown, the picker marking who is signed in, and an import offered. |
| <a id="f148"></a>[F148](F148-An-Agent-For-Each-Repository-At-One-Click.md) | — | — | At one click, a task for each of a project's repositories that names an agent, repositories left out and `issue` and `phase` given before the start, agents signed in on the way. |
| <a id="f163"></a>[F163](F163-The-Collection-Comes-With-Porelo-Host.md) | — | `porelo-host` [HO13](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho13) | The porelo-host collection brought by `porelo-host` from its own release, never chosen in the dialog outside a development build. |
| <a id="f158"></a>[F158](F158-A-Needs-You-Row-Names-Its-Machine-And-Its-Way-Out.md) | — | — | Every *Needs you* row naming its machine, offering the action that resolves it, and staying readable as *Resolved* instead of vanishing. |
| <a id="f159"></a>[F159](F159-Work-Started-From-The-Project-Page.md) | — | — | Visible start buttons on the project page and each repository row, with a chosen repository shown as text and a *Change* link in the start form. |
| <a id="f165"></a>[F165](F165-A-Projects-Commands-As-Tiles-On-Its-Page.md) | — | — | A project's commands as tiles on its page, not only in its ⋮. |

### Idea

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f138"></a>[F138](F138-A-Host-On-Fedora-From-The-Same-Command.md) | — | — | `porelo-host` bringing a Fedora host up and down as it does Ubuntu 26.04. |
| <a id="f139"></a>[F139](F139-OneDrive-As-The-Projects-Drive.md) | — | — | OneDrive as an alternative to Tresorit for a project's drive: the choice and the login at the stop. |
| <a id="f145"></a>[F145](F145-The-Hosts-Forge-Switched-On-With-Its-Repositories.md) | — | `porelo-host` [HO08](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho08) | The host's own forge switched on in the host dialog or on `porelo_host`, with the repositories that move there and where the central forge's token lies. |
| <a id="f146"></a>[F146](F146-The-Hosts-VM-Pool-Switched-On.md) | — | `porelo-host` [HO12](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho12) | The host's pool of small test VMs switched on on `porelo_host` and in the host dialog, with its systems and accounts. |
| <a id="f149"></a>[F149](F149-A-Panel-Plans-The-Release.md) | — | — | A panel that shows and edits a project's release plan by dragging issues into sprints and their functions, writing only the plan file. |

### Finished

| # | Title | What was built |
|---|---|---|
| <a id="f110"></a>F110 | An Unattended Run Ends With A Line | A line under `TileConsole` on `TaskTile` for unattended work whose agent ended, saying whether it finished or stopped before its end, whether work waits at the gate or changed files remain outside it, and where to go next. |
| <a id="f113"></a>F113 | The MSIX Installed And Started In The Build | `tool/windows-install-check.ps1` in the Windows workflows, refusing a copy of the MSIX re-signed with a throwaway certificate before trusting `porelo-msix.cer`, installing the MSIX, starting the app through its package identity, and removing both afterwards. |
| <a id="f116"></a>F116 | A Refused Ssh Login Explained When Connecting Again | `Tunnel` explaining a refused SSH reconnect through `whySshRefused` and showing it beside the machine on `MachinesPage`, with `ssh -G` naming the configured identity file or saying that none is named for the host. |
| <a id="f130"></a>F130 | The Leased Leg Taken From A Run That Proved The Same Tree | A step before the leased integration job that asks `porelo-release proven-legs` on a branch push and skips leasing when a run in the last 24 hours already proved the same tree, naming that run in the summary while tags and dispatches still run the leg. |
| <a id="f133"></a>F133 | A Provider's Key In The System's Secret Store | `SecretStore` in `packages/porelo_host/` over Secret Service on Linux and Credential Manager on Windows, with `porelo-host key set` and `key forget` reading the key on standard input and failing with 65 when no keyring is open. |
| <a id="f136"></a>F136 | Publish Without A Downloaded Client | Package, Windows and standalone `porelo-host` uploads and the Artifactory probe in `.github/workflows/` sent by `curl` with SHA-1 and SHA-256 headers and the token on standard input, with `jfrog/setup-jfrog-cli` removed. |
| <a id="f144"></a>F144 | Start Again Without The Now Flag | `PoreloBackend.startAgain` and `PoreloClient.start` sending `Start` without the ignored `now` parameter. |
| <a id="f135"></a>F135 | The Interface Brings A Host Up And Down | `HostSession` and `HostDialog` for *Put this project on a server…*, running the shipped `porelo-host` by path with read-only arguments once started, answering the drive and vault stop on standard input, and adding or removing the project's `host` machine on a finished `up` or `down`. |
| <a id="f140"></a>F140 | The Host's Files Written Into The Person's Drive | `porelo-host/machine.yml`, optional key copies and the host's WireGuard key staged and published without replacement into the project's chosen local Tresorit folder, the person's private WireGuard key kept in the system secret store under `wireguard-<project>`, and an explicit `wg-quick` export after a finished `up`. |
| <a id="f141"></a>F141 | An Agent Signed In When A Task Needs It On The Host | The completed `up` done line naming `address`, `account` and `socket`, agent sign-in on a `host` machine run at task start through the machine sign-in terminal and its reply forward, and `pinnedHostSshOptions` leading every SSH path to the host while refusing on-screen host-key trust. |
| <a id="f151"></a>F151 | A Stop's Survivors Read In Either Form | `Stopped` reading `surviving` as a numeric count or a list of survivor names and treating absent or malformed values as an unknown count, with `stopWords` naming any surviving helpers and reporting `"not reported"` when unknown. |
| <a id="f131"></a>F131 | A Host Brought Up And Down By One Command | The pure-Dart package `packages/porelo_host/` and `porelo-host up` and `down`, which rent or find a host, run the collection's plays on it over ssh with its host key pinned, stop with 75 for the drive and the vault, resume with the answers on standard input, and give the host back after the down play. |
| <a id="f132"></a>F132 | A Host Rented From Scaleway Elastic Metal | `ScalewayElasticMetal` against Scaleway's Elastic Metal and IAM APIs, checking that the person's ssh key is registered before renting, passing a generated ed25519 host key through cloud-init and the server's tag, and finding or giving back a server by the project's tag alone. |
| <a id="f134"></a>F134 | The Host Command Built And Shipped For Linux And Windows | `porelo-host` compiled with the package's version and shipped at `/usr/lib/porelo-frontend/porelo-host` in the Linux packages and beside the interface in the Windows ZIP and MSIX, checked in every install proof. |
| <a id="f129"></a>F129 | The Integration Leg Set Up On Fedora Too | One shell function that fetches the leg's Porelo packages as `.deb` from the index or as `.rpm` through the machine's own source, so the leg runs whole on Fedora as on Ubuntu. |
| <a id="f128"></a>F128 | The Leased Machine Trusted By The Key Its Lease Names | The leased leg trusts its rented machine only by the host key its lease names, with no keyscan, and stops on a lease that names none. |
| <a id="f119"></a>F119 | The Code Changed Since The Skills Reading Read Against Them | 860 files read against the sixteen skills, thirty findings with their sites, built as [F124](README.md#f124) to [F127](README.md#f127). |
| <a id="f127"></a>F127 | The Tests Cleared Of The Reading's Findings | Integration teardowns that run whatever failed and leave the test machine clean, settled waits in place of fixed sleeps, and the weak tests repaired or removed. |
| <a id="f126"></a>F126 | The Frame, The Tools And The Workflows Cleared Of The Reading's Findings | Disposals and quiet models after a dialog closes, dialogs that scroll on a short window, the integration leg refusing a lease without user or socket, the MSIX signed from the certificate store, and every colour in the tokens. |
| <a id="f125"></a>F125 | The Client And The App Cleared Of The Reading's Findings | GitHub Enterprise asked under its API path, a forge that answers wrongly or not at all said as refusing within thirty seconds, tolerant reads of the daemon's answers, and `porelo/frontend.json` keeping keys it does not know. |
| <a id="f124"></a>F124 | The Dart Code In One Format | The Dart at 120 columns as `dart format` writes it, the YAML, features and scripts in the shared style, each checked in the build, and the reformatting kept out of `git blame`. |
| <a id="f122"></a>F122 | The Interface Called Porelo Control Tower | The name *Porelo Control Tower* wherever a person reads it - the window's title on Linux and Windows, the menu entry, the about dialog, the Windows file properties and the MSIX - held to one constant by a test, with `porelo-frontend` kept as the technical name. |
| <a id="f121"></a>F121 | The Interface In Porelo's Look | The website's palette, corners and logo in a full colour scheme per brightness, the state colours and the terminal's palette to match, and a test that holds every text and mark to WCAG AA in light and dark. |
| <a id="f79"></a>F79 | What Walk 8 Found In The Interface | Tiles headed by their work with a mark per state, *Needs you* saying who wrote a held message and what came of a decision, talking that offers the project's other tasks and says who a peer is, *Join*'s fields named as clients name them, and fresh state at once after one's own action. |
| <a id="f71"></a>F71 | The Sign-In Terminal Shows Where Typing Goes | The sign-in and passphrase terminals show the cursor while they wait, whatever their program hides; a work's terminal keeps its program's. |
| <a id="f68"></a>F68 | A Refusal Says What To Do About It | A refused token names the right it lacks and where it is given, disabled deploy keys are said as the organisation's setting, a refused ssh login says why, and an unknown host key is offered to be trusted at a start. |
| <a id="f69"></a>F69 | The New-Machine Wizard Offers What Is Published | The wizard lists the package index's offer in its own words, the homeserver as a choice of its own, says before anything runs when a choice leaves the machine unable to talk, shows `porelo doctor`'s answer, and holds the vault step until the vault exists. |
| <a id="f101"></a>F101 | What The Build Of A Push Did | A work's tile and detail show the build of its last push - verdict, every job and its log in the task - and why when the machine cannot read it. |
| <a id="f100"></a>F100 | A File Handed To A Running Task | A file handed to a running task in parts, resumed where the machine says, refused above its limit before a byte is read, taken back with a second decision, and its record read after the task is gone. |
| <a id="f120"></a>F120 | The Interface Renamed Porelo | The interface renamed Porelo in one scripted commit: its Dart package, binary, desktop and MSIX ids, settings, packages and the daemon's contract, installed afresh, and a test that holds every tracked file to the new name. |
| <a id="f102"></a>F102 | A Porelo In WSL Reached From Windows | The interface on Windows, as a ZIP and an MSIX signed by `CN=porelo.ai`, reaching a Porelo in a WSL distribution through `wsl.exe` with no ssh and no open port, and setting Porelo up there; checked on GitHub's Windows runner, untested on a Windows machine. |

### Rejected

| # | Title | Why |
|---|---|---|
| <a id="f150"></a>F150 | The Person's Tunnel Brought Up From The Interface | Merged into [F157](README.md#f157), which brings the VPN up and down from the interface. |
