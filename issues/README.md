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
| <a id="f137"></a>[F137](F137-The-Collection-Taken-Only-By-Its-Digest.md) | — | — | The collection installed on the host only by the digest the package expects, checked here and there. |

### Implementing

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f194"></a>[F194](F194-A-Signing-Key-That-Did-Not-Sign-The-Bundle-Refused.md) | M | — | A signing key that did not sign the commit put on the drive refused on "The drive", before a server is rented, naming both fingerprints, with the field opening on a key the machine pins. |

### Backlog

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f99"></a>[F99](F99-An-Attached-Agent-Shown-At-Rest-Or-Working.md) | S | `porelo` [B118](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b118) | A work tile says whether an attached agent is at rest or working. |
| <a id="f108"></a>[F108](F108-A-Machine-Over-Ssh-From-Windows.md) | M | — | On Windows, a machine over ssh is reached through the relay, as a WSL distribution is. |
| <a id="f117"></a>[F117](F117-What-Walk-8-Left-Unbuilt.md) | M | — | A tile's repository in its heading, a refused release said as an error that stays, the project file taken after one's own push. |
| <a id="f111"></a>[F111](F111-All-Of-A-Pieces-Logs-In-One-Timeline.md) | M | — | All of a piece's logs in one timeline, by time, filterable by source. |
| <a id="f147"></a>[F147](F147-Every-Repository-Of-Default-Offered-To-Start-In.md) | XS | — | Starting in default offers every repository; the first is no longer hidden as its own. |

### Analyzed

| # | Size | Blocked by | What it covers | Open questions |
|---|---|---|---|---|
| <a id="f148"></a>[F148](F148-An-Agent-For-Each-Repository-At-One-Click.md) | L | `porelo` [B298](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b298), [B299](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b299) | At one click, a task for each of a project's repositories that names an agent, repositories left out and `issue` and `phase` given before the start, agents signed in on the way. | 3 |
| <a id="f114"></a>[F114](F114-Windows-Notifications-From-The-MSIX.md) | M | — | Windows notifications from the MSIX's identity. | — |
| <a id="f115"></a>[F115](F115-A-Fine-Grained-Token-Waiting-For-An-Organisations-Approval.md) | S | the test organisation at GitHub from the operator | A fine-grained token waiting for an organisation's approval said as waiting. | — |
| <a id="f95"></a>[F95](F95-A-Waiting-Push-Fetched-Here.md) | M | `porelo` [B293](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b293) | A waiting push fetched here, into a clone the person chooses, with its source level, risk class, and checkout warning. | — |
| <a id="f78"></a>[F78](F78-A-Waiting-Push-Is-Reviewed-As-At-A-Forge.md) | M | `porelo` [B150](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b150), [B293](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b293) | A waiting push read as a pull request, with source level, per-file risk classes, Approve held until every C3 file is read, and bidi escaping. | — |
| <a id="f107"></a>[F107](F107-Code-Comments-In-The-Review.md) | L | [F78](README.md#f78), `porelo` [B166](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b166), [B172](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b172), [B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291) | Comments and findings on lines in the review in Porelo's SARIF 2.1.0 profile, with origin, source level, suggestions, and run completeness. | — |
| <a id="f74"></a>[F74](F74-A-Waiting-Pushs-Tests-Run-In-A-Container-Of-Its-Own.md) | M | `porelo` [B95](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b95), [B293](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b293) | A waiting push's tests run in a container of their own on the machine, pinned to the reviewed commit under its source-level and risk-class isolation. | — |
| <a id="f112"></a>[F112](F112-What-A-Piece-Of-Work-Did-In-Words.md) | L | `porelo` [B166](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b166), [B174](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b174), [B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291), [B293](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b293) | What a piece of work did, in words, at the top of its tile, with its SARIF check round, completeness, open findings and threads, and risk class. | — |

### Accepted

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f123"></a>[F123](F123-Where-A-Machine-And-A-Project-Stand-In-Their-Organisations-Tree.md) | — | `porelo` [B198](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b198) | Where a machine and a project stand in their organisation's tree, and which settings bind them. |
| <a id="f143"></a>[F143](F143-The-Agent-The-Machine-Found-Is-The-Default.md) | — | `porelo` [B225](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b225) | The agent the machine chooses started when none is picked, its source shown, the picker marking who is signed in, and an import offered. |
| <a id="f166"></a>[F166](F166-A-Host-Rented-Through-OpenTofu.md) | M | `porelo-host`'s OpenTofu module | `porelo-host up` and `down` renting and giving back through the OpenTofu module, its secrets only in `tofu`'s environment; `--given` kept. |

### Idea

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f138"></a>[F138](F138-A-Host-On-Fedora-From-The-Same-Command.md) | — | — | `porelo-host` bringing a Fedora host up and down as it does Ubuntu 26.04. |
| <a id="f139"></a>[F139](F139-OneDrive-As-The-Projects-Drive.md) | — | — | OneDrive as an alternative to Tresorit for a project's drive: the choice and the login at the stop. |
| <a id="f145"></a>[F145](F145-The-Hosts-Forge-Switched-On-With-Its-Repositories.md) | — | `porelo-host` [HO08](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho08) | The host's own forge switched on in the host dialog or on `porelo_host`, with the repositories that move there and where the central forge's token lies. |
| <a id="f146"></a>[F146](F146-The-Hosts-VM-Pool-Switched-On.md) | — | `porelo-host` [HO12](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho12) | The host's pool of small test VMs switched on on `porelo_host` and in the host dialog, with its systems and accounts. |
| <a id="f149"></a>[F149](F149-A-Panel-Plans-The-Release.md) | — | — | A panel that shows and edits a project's release plan by dragging issues into sprints and their functions, writing only the plan file. |
| <a id="f190"></a>[F190](F190-Approved-Work-Brought-To-The-Central-Forge.md) | — | — | Approved work on the host's Forgejo reviewed in SARIF 2.1.0 and brought to the central forge, bound to the reviewed commit, repository, and pull request. |
| <a id="f191"></a>[F191](F191-Held-And-Outgoing-Forge-Comments-Released.md) | — | — | Held inbound forge comments (`E0`, and `E1` under policy) released alone to a task, and outgoing forge comments released bound to the reviewed commit and pull request. |
| <a id="f192"></a>[F192](F192-A-Machine-That-Refuses-Every-Key-Said-So.md) | — | — | A machine refusing every offered key said so, with the key it expects. |
| <a id="f193"></a>[F193](F193-What-A-Walk-Left-Open-For-Keys-And-Tasks.md) | — | — | Key handling, one way to a running task and the proposed project model, built or decided against. |

### Estimated

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f93"></a>[F93](F93-Connections-Rare-Actions-Out-Of-The-Way.md) | S | — | Connections' rare actions in its ⋮. |
| <a id="f91"></a>[F91](F91-One-Way-To-Show-Loading.md) | M | — | Every view shows the same way that it is reading. |
| <a id="f94"></a>[F94](F94-A-Projects-Keys-Told-In-One-Place.md) | M | — | A project's keys told in one place, the signing key checked against a branch rule. |
| <a id="f96"></a>[F96](F96-Keys-A-Machine-No-Longer-Knows.md) | M | the test organisation and its token from the operator | Clearing a machine also removes the forge keys it no longer knows. |
| <a id="f97"></a>[F97](F97-Forwarding-Measured-Against-GitHub.md) | M | the test organisation and its token from the operator | Forwarding to a chosen branch measured against GitHub. |
| <a id="f105"></a>[F105](F105-A-Tasks-Terminal-In-The-Interface-As-Outside-It.md) | M | — | A task's terminal in the interface behaves as in a plain terminal. |
| <a id="f59"></a>[F59](F59-A-Project-From-A-Repository-Measured-Against-GitHub.md) | S | the test organisation, its token and signing key from the operator | Making a project from a repository measured against GitHub. |
| <a id="f84"></a>[F84](F84-A-Signing-Key-Found-Or-Made-From-The-Window.md) | M | — | A signing key chosen from a file or made from the window. |
| <a id="f64"></a>[F64](F64-The-Guided-Walk-As-A-Package-Of-Its-Own.md) | L | — | The guided walk as a package any Flutter app can use. |
| <a id="f75"></a>[F75](F75-One-Definition-For-A-UI-Test-And-A-Guided-Walk.md) | XL | `flutter-guided-walk`: a scenario that is also a walk | Each scenario tagged `@walk` is also a walk. |
| <a id="f72"></a>[F72](F72-Forges-Beyond-GitHub.md) | L | the operator's evaluation licence for Bitbucket Data Center | Forges beyond GitHub: Bitbucket Data Center first, measured against a test installation of its own. |
| <a id="f37"></a>[F37](F37-Reach-A-Machine-Without-An-ssh-Binary.md) | L | — | A machine reached without an `ssh` binary. |
| <a id="f52"></a>[F52](F52-Release-A-Devices-Key-Only-With-A-Touch-Or-A-PIN.md) | XL | — | A device's key released only behind a TPM2 PIN; a touch later. |
| <a id="f109"></a>[F109](F109-The-Interface-On-macOS-With-Porelo-In-A-Local-VM.md) | XL | `porelo-project` [PJ55](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj55), on Apple silicon | The interface on macOS, with Porelo in a local Lima VM set up from the window, and remote machines over ssh. |
| <a id="f104"></a>[F104](F104-A-Project-Followed-From-A-File.md) | M | `porelo` [B160](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b160) | A project followed from a bundle or a directory; offline projects again. |
| <a id="f81"></a>[F81](F81-The-Setup-Script-Checked-By-Its-Signature.md) | M | `porelo` [B99](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b99) | The setup script verified by its signature before it runs. |
| <a id="f88"></a>[F88](F88-A-Nickname-For-Each-Agent.md) | M | `porelo` (`@label`, the agent card, the label handed to the transport) | A nickname for each agent. |
| <a id="f62"></a>[F62](F62-An-Organisations-Policy-Is-Shown.md) | M | `porelo`'s part of `porelo-project` [PJ16](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj16) | An organisation's policy shown. |
| <a id="f142"></a>[F142](F142-The-Drafts-Offered-Before-The-First-Task-In-Default.md) | M | `porelo` [B221](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b221) | The machine's proposed tools and rules shown before the first task on a repository in `default`, and the choice passed back. | — |

### Finished

| # | Title | What was built |
|---|---|---|
| <a id="f177"></a>F177 | Every Navigation Entry Counts What Its List Shows | Navigation rail badge counts matching the exact number of rows displayed on each opened list, including servers in preparation and interrupted ones under *Machines* and all open rows under *Needs you*. |
| <a id="f178"></a>F178 | An Interrupted Run's Protocol Kept Across A Restart | Persistence of an interrupted server setup's protocol and wizard answers in settings across restarts until the server is given back, with one button named *Go on* for interrupted runs and *Try again* for failed runs. |
| <a id="f179"></a>F179 | An Interrupted Setup In Needs You And A Running One Found Again | Interrupted server setups surfaced in *Needs you* with *Go on*, clean termination of `porelo-host up` before SSH when leaving, and unattended background execution after SSH that is rediscovered as running upon restart. |
| <a id="f180"></a>F180 | One Host Command At A Time Per Project | An exclusive per-project file lock held by `porelo-host up` and `down` before contacting the cloud provider or host, refusing concurrent runs with step `lock` and exit code `75`. |
| <a id="f181"></a>F181 | One Setup Protocol That Stays Still While Read | A single setup protocol list keeping unmatched lines in place, grouping earlier attempts into a collapsed section at the end, providing *Copy the protocol*, and scrolling only when already at the bottom. |
| <a id="f182"></a>F182 | The VPN Interface Left Unmanaged By NetworkManager | The VPN setup step writing `/etc/NetworkManager/conf.d/porelo.conf` to mark the `porelo` interface unmanaged and reloading NetworkManager under the initial `sudo` prompt to prevent desktop connection failure notifications. |
| <a id="f183"></a>F183 | One VPN Action That Follows The Tunnel's State | A single server VPN tile and menu action reflecting the current tunnel state checked without root privileges via `ip link`, opening no terminal when the tunnel is already in the requested state. |
| <a id="f184"></a>F184 | The Room's Accounts Listed With Remove And New Password | The messages dialog listing every account in the project's room with *Remove*, confirmed and with the reasons an account is kept, and `"You are in as <name>"` with *New password* when already joined. |
| <a id="f185"></a>F185 | The VPN Taken Down When A Server Is Given Back | Teardown of the local WireGuard VPN tunnel as the final step of giving back a server before *Done.*, placing a *Take the VPN down* action into *Needs you* if the terminal step was cancelled. |
| <a id="f186"></a>F186 | The Scaleway Key Checked When Stored And In The Wizard | `porelo-host key set scaleway` and `--from-file` checking the key's UUID form, a quoted key taken, and Scaleway's offers endpoint before storing, a redirect named as one, and step 1 of the wizard checking the kept key. |
| <a id="f187"></a>F187 | Needs You As Compact Expandable Rows Without Pink Surfaces | Single-line expandable rows for *Needs you* and *Recently resolved* with inline primary resolution buttons, and removal of pink `errorContainer` surface fills everywhere except review diffs and dangerous confirmations. |
| <a id="f188"></a>F188 | One Expandable List Row For Every List | One shared fixed-height expandable list-row component across *Projects*, *Forges*, *Machines*, and *Needs you*, where tapping the row navigates to details and tapping the arrow expands status information in place. |
| <a id="f189"></a>F189 | The Server Page's Actions As A Grid Of Tiles | Multi-column `CommandTile` action grid on the server page with dedicated outlined icons per action, placing *Take this server down* at the end of the page as a separate red button. |
| <a id="f152"></a>F152 | Secrets For A Host Typed Only In A Terminal | An SSH terminal on the host opened at the host stop with the pinned host key and setup identity to run Tresorit's login and the vault initialization or unlock directly on the server without secrets entering interface forms or porelo-host standard input, resuming porelo-host up when complete. |
| <a id="f153"></a>F153 | A Forge's Token By The Provider's Own Login | Terminal prompts on this computer for `porelo-host key set` and on bound machines for `porelo vault put git.token` to store the person's forge token in the secret store and remote vaults without interface form fields, with deploy keys removed across the client. |
| <a id="f154"></a>F154 | A Host Stands In Machines While It Is Prepared | A host in preparation shown immediately under *Machines* with its plain-words step, estimated duration, protocol dialog and *Needs you* link at a stop, becoming a ready machine automatically when `porelo-host up` finishes. |
| <a id="f155"></a>F155 | A Host Taken Down From Machines | *Take this server down* in a host machine's menu and page running `porelo-host down` from the arguments kept at `up`, with a billing and reconnection warning on *Remove from this list* and the setup dialog keeping its last values. |
| <a id="f156"></a>F156 | The Host Dialog's Fields And Words | Tilde expansion for path fields via `Desk.expandHome`, file pickers beside paths, repository fields hidden until a tresor folder is chosen, auto-scrolling to the stop prompt, and plain-words explanations for WireGuard commands. |
| <a id="f157"></a>F157 | A Person's Terminal Steps Offered By The Interface | *Bring the VPN up* and *Take the VPN down* commands opening local terminal steps with the root commands filled in, VPN saving from the server menu across restarts, and *Join the project's room* opening *Messages* with the homeserver forward and mention-pill instructions. |
| <a id="f158"></a>F158 | A Needs-You Row Names Its Machine And Its Way Out | Every *Needs you* row naming its machine and offering its resolving action directly on the row, with resolved rows and read messages retained greyed under *Recently resolved* for a configurable duration. |
| <a id="f159"></a>F159 | Work Started From The Project Page | Visible *Start work here* buttons on each repository row and on the project page, with the start form opening with the chosen repository fixed as text beside a *Change* action. |
| <a id="f160"></a>F160 | The Interface's Terminals Paste As Linux Terminals Do | Shared `terminalShortcuts` supporting `Ctrl+Shift+V` and `Shift+Insert` alongside `Ctrl+V` across all interface terminals, with the paste shortcut named beneath the terminal. |
| <a id="f161"></a>F161 | A Start's Progress And Refusal In Words | Start progress and wait states shown in plain words through streamed `StartStep` replies, stopping with the exact cause on dependency failures and explaining a refused `porelo.yml` verbatim without starting anything. |
| <a id="f162"></a>F162 | The Host Flow Walked Against Stand-Ins | Stand-in `porelo-host` and `ssh` tools driving the full host flow in development builds against mock situations and mock daemons without renting a server, accompanied by guided walk 17. |
| <a id="f163"></a>F163 | The Collection Comes With Porelo-Host | The porelo-host collection tarball packaged beside the binary and used by default in `porelo-host up` with its digest checked, removing the collection chooser from release builds. |
| <a id="f164"></a>F164 | Putting A Project On A Server, Step By Step | A reusable multi-step `Wizard` frame in `lib/src/ui/wizard.dart` with *Step n of N* indicators, navigation, validation and summary, hosting *Put this project on a server* with Tresorit tresor and folder separated. |
| <a id="f165"></a>F165 | A Project's Commands As Tiles On Its Page | Grouped `CommandTile` widgets on the project page displaying project actions with icons and descriptions beside *Start work*, while retaining the `⋮` menu. |
| <a id="f167"></a>F167 | The Project Bundle Written By The Wizard | Automatic creation of `porelo-host/<project>.bundle` in the chosen tresor folder from the verified followed commit with derived host paths, public SSH key prefill from `.pub` files, and the target project named in the wizard summary. |
| <a id="f168"></a>F168 | The Locked-Vault Row Says Which Vault And Project | The locked-vault attention row naming the vault location and listing held-up projects with their last-used time, placing the unlock action first and offering previewed unfollow for unused projects. |
| <a id="f169"></a>F169 | A Server In Preparation Kept Across A Restart | Persisted preparation records restoring interrupted setups under *Machines* across restarts with *Go on* and *Take it down* actions, backed by a close guard warning that the server remains rented. |
| <a id="f170"></a>F170 | The Setup Protocol With Times And Words | Timestamped step lines recording local start times and durations in the host setup protocol, plain-words overrun notices when steps take longer than expected, and elimination of duplicate raw JSON lines. |
| <a id="f171"></a>F171 | The Stop Opens Its Own Small Dialog | `HostStopDialog` presenting only what the host needs and launching `porelo-host-stop` in an SSH terminal with the command line behind a *Details* toggle, retrying failed logins in place. |
| <a id="f172"></a>F172 | The VPN As The Setup's Last Step | Automated WireGuard VPN configuration as the final setup step via a temporary runtime file and sudo terminal, checking ping and latest handshake before declaring the host ready, and guarding against duplicate tunnels. |
| <a id="f173"></a>F173 | Action Tiles That Read As Buttons | Unified `CommandTile` and *Its work* action tiles styled as tonal card buttons with consistent dimensions, hover and press feedback, and token-based spacing. |
| <a id="f174"></a>F174 | The Project Room Joined From The Project | Joining the project room moved to the project page's *Messages and the project's room* tile, providing step-by-step Element instructions, lowercase name normalization, and an *Open Element* button. |
| <a id="f175"></a>F175 | A Running Task's Agent Said In Words | Unattended task views marking the transition to agent execution with activity states, last output line age, an explicit *Leave* button, and a restart offer when messages wait in the inbox. |
| <a id="f176"></a>F176 | Giving The Server Back Confirmed By Its Consequences | A destructive confirmation dialog for taking a server down explaining that the server is deleted and billing stopped while the vault and room history are lost, with a red *Give the server back* button across all entry points. |
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
