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
| <a id="f204"></a>[F204](F204-The-Build-Runs-On-The-Local-Forge-As-On-The-Central-One.md) | — | — | The build green on the host's Forgejo and the central forge on the same commit, its machine asked for by kind and its registry a variable. |
| <a id="f348"></a>[F348](F348-A-Start-With-No-Terminal.md) | M | Core's answer of a host's keys | One person starts an organization, a machine and a project with no terminal. |
| <a id="f346"></a>[F346](F346-Do-You-Work-Alone.md) | S | Core's way to take the value | Creating a project asks "Do you work alone?"; yes writes `review: optional`, and it stays changeable. |
| <a id="f350"></a>[F350](F350-A-Project-Filled-From-A-Checkout.md) | M | — | A project is filled from a checkout in the window: the folder, the draft with its sources, the signature. |
| <a id="f345"></a>[F345](F345-Make-My-Card-Only-Asks-To-Sign.md) | M | Core's answer of what it found | *Make my card…* shows one line and *Sign*, and asks only what it did not find or found twice. |
| <a id="f347"></a>[F347](F347-A-Card-Renewed-With-One-Click.md) | M | Core's renewal with the same key | A card's end is said before and after it, and renewing is one click. |
| <a id="f335"></a>[F335](F335-One-Row-Per-Machine.md) | — | — | *Organization* lists the machines available, *Machines* a person's own after *Connect*, each once, and "host" gone from the interface's words. |
| <a id="f330"></a>[F330](F330-A-Project-Page-Says-It-Is-Reading.md) | — | — | A project's page showing at once that it is reading, and what. |
| <a id="f331"></a>[F331](F331-A-Long-Change-Shows-That-It-Runs.md) | — | — | A long change, such as opening a project, showing that it runs and where a failure will be said. |
| <a id="f339"></a>[F339](F339-Refresh-Reads-What-Is-Shown.md) | — | — | The rail's *Refresh* reaching the page shown, and a host page's own button named for what more it does. |
| <a id="f343"></a>[F343](F343-A-Hosts-List-Says-What-The-Host-Still-Holds.md) | — | — | A host's list keeping a project being taken off until the host has let it go, and saying why if held. |
| <a id="f338"></a>[F338](F338-The-Words-Of-The-Project-List.md) | — | — | The project list's words saying what each row states and each button does. |
| <a id="f341"></a>[F341](F341-What-The-Token-Is-For.md) | — | — | The words asking for a token naming its forge, what the host does with it, its rights, and that it is not kept. |
| <a id="f336"></a>[F336](F336-A-Hosts-Page-Reads-As-A-Way-To-Work.md) | — | [F335](#f335) | A host's page saying what the connection is and what ending it does, and leading to work. |
| <a id="f340"></a>[F340](F340-Commits-Not-Yet-At-The-Forge.md) | — | — | A project's row and page saying how many approved commits have not reached the forge, with the action and who may do it. |
| <a id="f342"></a>[F342](F342-A-Project-Is-Put-On-A-Machine-From-The-Organizations-Projects.md) | — | — | A machine's admin puts a project on it from the organization's projects, and the machine's list is read only. |
| <a id="f329"></a>[F329](F329-One-Menu-On-Each-Row-Of-The-Organization-Page.md) | — | — | Only a ⋮ on each row of the organization's, machine's and project's pages, with *Connect* visible while not connected. |
| <a id="f344"></a>[F344](F344-The-Look-Of-A-Page-With-Lists.md) | — | — | Sections visibly apart, a filter behind a magnifier, and sorting, with three proposals drawn. |
| <a id="f334"></a>[F334](F334-A-Host-Row-That-Keeps-Its-Words.md) | — | — | A machine's row keeping one steady line while a host refuses, and never talking of a forward. |
| <a id="f337"></a>[F337](F337-A-Rail-Entry-Leads-To-Its-List.md) | S | — | A rail entry always landing on the first page that entry opens. |
| <a id="f332"></a>[F332](F332-A-Server-Dialog-Opens-At-Once.md) | — | — | *Prepare a server…* opening its dialog at the click, and a second click opening no second one. |
| <a id="f333"></a>[F333](F333-A-Server-Run-Says-What-It-Is.md) | — | — | The server run's dialog naming at once what runs and that it takes minutes, its row never ending in nothing, and *Close* usable. |
| <a id="f325"></a>[F325](F325-Going-Back-To-The-Machines-Agent.md) | — | — | A picked agent handed back to the machine's choice in the start form. |
| <a id="f326"></a>[F326](F326-Operations-Run-Beside-Work-Running.md) | — | — | The status line's count of operations not read as work running. |
| <a id="f327"></a>[F327](F327-What-Closing-The-Window-Leaves-Running.md) | — | — | *Close Porelo?* saying what is true of the work it lists. |
| <a id="f319"></a>[F319](F319-Confirmed-Membership-Purge-Before-Give-Back.md) | S | — | Giving a server back shows who still holds a role on it and removes the accounts of those a person confirmed; walked by no sprint yet. |
| <a id="f322"></a>[F322](F322-Leftovers-Of-The-Organization-Walk.md) | S | — | Small things a walk of the organization's pages found: raw JSON, a mark while a change runs, a stale refusal, words. |
| <a id="f108"></a>[F108](F108-A-Machine-Over-Ssh-From-Windows.md) | — | — | On Windows, a machine over ssh is reached through the relay, as a WSL distribution is; a host is [F351](README.md#f351). |
| <a id="f118"></a>[F118](F118-An-Upstream-That-Cannot-Be-Read-Said-Before-A-Start.md) | — | — | An upstream that cannot be read said before a start, with what fixes it. |
| <a id="f192"></a>[F192](F192-A-Machine-That-Refuses-Every-Key-Said-So.md) | — | — | A machine refusing every offered key said so, with the key it expects. |
| <a id="f223"></a>[F223](F223-A-Ready-Server-Runs-Its-Setup-Again.md) | S | — | A ready rented server offers Run its setup again, which runs `up` in the interface's own run, a stop in it completed from Needs you. |
| <a id="f224"></a>[F224](F224-Porelo-Host-Says-Which-Server-Is-Rented-Now.md) | S | — | A read-only `porelo-host find` says which server carries the project's tag now, or that none does. |
| <a id="f263"></a>[F263](F263-The-Give-Back-Confirmation-Says-What-Is-Lost.md) | — | — | *Take the server down?* shows the name and what is lost, no public values, a steady layout. |
| <a id="f264"></a>[F264](F264-A-Server-With-No-Project-Given-Back.md) | S | — | A server rented with no project given back; the VPN taken down only after the give-back was confirmed. |
| <a id="f316"></a>[F316](F316-An-Owner-Accepts-A-Lost-Keys-New-Card.md) | — | — | An owner puts a person's new card in place of a lost key from their row under *People*. |
| <a id="f320"></a>[F320](F320-A-First-Organization-Without-Hand-Work.md) | M | — | A forge's ssh host key confirmed in the interface, so a first organization needs no hand work. |
| <a id="f323"></a>[F323](F323-Refuse-An-Organization-A-Host-Cannot-Follow.md) | — | — | An organization a host cannot follow refused before the host is prepared. |

### Rework

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f137"></a>[F137](F137-The-Collection-Taken-Only-By-Its-Digest.md) | — | — | The collection installed on the host only by the digest the package expects, checked here and there. |

### Implementing

| # | Size | Blocked by | What it covers |
|---|---|---|---|

### Backlog

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f99"></a>[F99](F99-An-Attached-Agent-Shown-At-Rest-Or-Working.md) | S | — | A work tile says whether an attached agent is at rest or working. |
| <a id="f117"></a>[F117](F117-What-Walk-8-Left-Unbuilt.md) | M | — | A tile's repository in its heading, a refused release said as an error that stays. |
| <a id="f111"></a>[F111](F111-All-Of-A-Pieces-Logs-In-One-Timeline.md) | M | — | All of a piece's logs in one timeline, by time, filterable by source. |
| <a id="f147"></a>[F147](F147-Every-Repository-Of-Default-Offered-To-Start-In.md) | XS | — | Starting in default offers every repository; the first is no longer hidden as its own. |

### Analyzed

| # | Size | Blocked by | What it covers | Open questions |
|---|---|---|---|---|
| <a id="f219"></a>[F219](F219-An-Interface-Ended-Without-Asking-Leaves-No-Forward-Behind.md) | S | — | The ssh forwards this interface raised ended with it also when it ends without asking, and one left over found again by its socket at the next start. | — |
| <a id="f114"></a>[F114](F114-Windows-Notifications-From-The-MSIX.md) | M | — | Windows notifications from the MSIX's identity. | — |
| <a id="f115"></a>[F115](F115-A-Fine-Grained-Token-Waiting-For-An-Organisations-Approval.md) | S | the test organisation at GitHub from the operator | A fine-grained token waiting for an organisation's approval said as waiting. | — |
| <a id="f95"></a>[F95](F95-A-Waiting-Push-Fetched-Here.md) | M | — | A waiting push fetched here, into a clone the person chooses, with its source level, risk class, and checkout warning. | — |
| <a id="f78"></a>[F78](F78-A-Waiting-Push-Is-Reviewed-As-At-A-Forge.md) | S | — | A waiting push decided without an IDE: source level, highest risk class, files in risk order with their class, *Let it through…* or *Turn it away*, a second ask for `C3` files; the code read in IntelliJ. | — |
| <a id="f107"></a>[F107](F107-Code-Comments-In-The-Review.md) | M | [F78](README.md#f78) | Per waiting push the open finding and thread counts and each check's completeness, anything but complete never shown as clean; comments read and written in IntelliJ. | — |
| <a id="f74"></a>[F74](F74-A-Waiting-Pushs-Tests-Run-In-A-Container-Of-Its-Own.md) | M | — | A waiting push's tests run in a container of their own on the machine, pinned to the reviewed commit under its source-level and risk-class isolation. | — |
| <a id="f112"></a>[F112](F112-What-A-Piece-Of-Work-Did-In-Words.md) | M | — | What a piece of work did, in words, at its top: last answer, commits as a list with their highest risk class, what waits with its checks, messages, firewall stops; no diff. | — |
| <a id="f190"></a>[F190](F190-Approved-Work-Brought-To-The-Central-Forge.md) | M | — | A host pull request's state and approval, and approved work brought on to the central forge bound to commit, repository and pull request, with level, class and checks in one line. | — |
| <a id="f191"></a>[F191](F191-Held-And-Outgoing-Forge-Comments-Released.md) | M | — | Held inbound forge comments and outgoing ones in *Needs you*, each released, dismissed, sent or refused alone, a person's own from IntelliJ too, bound to commit and pull request. | — |

### Accepted

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f123"></a>[F123](F123-Where-A-Machine-And-A-Project-Stand-In-Their-Organisations-Tree.md) | — | — | Where a machine and a project stand in their organisation's tree, and which settings bind them. |
| <a id="f166"></a>[F166](F166-A-Host-Rented-Through-OpenTofu.md) | M | — | `porelo-host up` and `down` renting and giving back through the OpenTofu module, its secrets only in `tofu`'s environment; `--given` kept. |

### Idea

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f351"></a>[F351](F351-A-Host-Reached-From-Windows.md) | — | — | A host reached from Windows, measured first, probably by WSL's ssh. |
| <a id="f352"></a>[F352](F352-A-Rental-State-Kept-Beyond-One-Computer.md) | — | — | OpenTofu's state in the organization's repository or at the provider. |
| <a id="f353"></a>[F353](F353-The-Page-With-The-Work-Cards-Redesigned.md) | — | — | The redesign of *Work* and *Needs you*: a list and one tab per running agent, reviews under *Needs you*, one count; design accepted, built after the foo test, with [F306](README.md#f306) in it. |
| <a id="f349"></a>[F349](F349-A-Way-Without-Administration-Rights.md) | — | — | A person creates the repository and enters each deploy key by hand, so their token needs no Administration. |
| <a id="f328"></a>[F328](F328-Letters-Doubled-In-A-Slow-Window.md) | — | — | A key pressed once reaching a console once, however slowly the window answers. |
| <a id="f324"></a>[F324](F324-Removing-A-Project-On-Windows.md) | — | — | A local project removed from the interface on Windows, where it runs in a WSL distribution. |
| <a id="f321"></a>[F321](F321-Send-The-Terminal-Input-Fix-Upstream.md) | S | — | The terminal input fix offered upstream, and this repository's copy of `xterm` dropped once a release holds it. |
| <a id="f318"></a>[F318](F318-An-Owner-Makes-An-Admin-A-Developer.md) | — | — | An Organization Admin turns a project's admin into a developer with an entry on the organization page. |
| <a id="f317"></a>[F317](F317-A-Homeservers-Token-Reaches-The-Host.md) | — | — | A homeserver's registration token comes along with `porelo host unlock` through Core, and lies in the host's vault. |
| <a id="f308"></a>[F308](F308-The-Needs-You-Header-Counts-What-It-Lists.md) | — | — | The *Needs you* header, the rail's badge and the rows agree on what needs the person. |
| <a id="f306"></a>[F306](F306-A-Work-Card-Whose-Terminal-Has-Ended.md) | — | — | A *Work* card whose terminal ended says so in words, without an empty black terminal bar. |
| <a id="f307"></a>[F307](F307-Push-And-Pull-Show-Their-Progress-In-The-Interface.md) | — | — | Push and pull on a card host show each repository's answer in the interface, the terminal only for the master password. |
| <a id="f304"></a>[F304](F304-No-Message-Asks-A-Step-The-Interface-Can-Take.md) | M | — | No message tells the person to do a step the interface can take itself; actions read what they need and say so. |
| <a id="f303"></a>[F303](F303-Menus-Beside-What-They-Act-On.md) | M | — | Each ⋮ menu placed with the row, section or title it acts on. |
| <a id="f302"></a>[F302](F302-Refresh-Shows-What-It-Did.md) | S | — | Refresh shows that it runs and ends with what it read or what failed. |
| <a id="f300"></a>[F300](F300-One-Project-One-Entry-Across-Machines.md) | M | — | One project read as one entry under Projects, with the machines it is on under it. |
| <a id="f296"></a>[F296](F296-Card-Endpoints-Per-Login.md) | M | — | Card endpoints per login, so two instances of one account each hold a tunnel to one host; a master this person left ended on raise. |
| <a id="f295"></a>[F295](F295-No-Ask-Line-Naming-The-Viewer.md) | S | — | No refusal ends with "Ask <name>" when the named person is the one at this interface. |
| <a id="f293"></a>[F293](F293-Host-Deliveries-Hardened.md) | M | — | Host deliveries hardened: git in a clean environment, commands without the login shell or a deliberate exception. |
| <a id="f292"></a>[F292](F292-A-Lock-Confirmed-By-Each-Host.md) | M | — | *Lock* and *Let back in* shown as under way on each host until `org status` there confirms them; adding counts as done once signed. |
| <a id="f290"></a>[F290](F290-The-Host-Functions-From-A-Windows-Desktop.md) | M | — | Connect and Prepare from a Windows desktop: one ssh per host card with loopback TCP ends, the daemon through the relay, no master. |
| <a id="f288"></a>[F288](F288-Small-Leftovers-Of-The-One-Click-Flow.md) | — | — | The small edge cases left over from the one-click flow gathered in one place for the operator to place: address forms, test gaps, texts. |
| <a id="f284"></a>[F284](F284-The-Subagent-Number-Chosen-When-Starting.md) | — | — | How many subagents the agent may run at once, chosen when starting, with the number that applies and Core's refusal said before anything is made. |
| <a id="f282"></a>[F282](F282-The-Providers-Usage-In-A-Status-Line.md) | — | — | A status line with one traffic light for the providers' usage, a popup per provider, and a *Needs you* warning past a set threshold. |
| <a id="f236"></a>[F236](F236-Root-Reached-On-A-Rented-Server.md) | — | — | Root allowed in the rental's cloud-config; a "Please login as" answer refused at once, naming the user. |
| <a id="f238"></a>[F238](F238-A-Server-With-No-Project-Is-Not-Silent.md) | — | — | A server prepared with no project not raised as *Not answering*; its row says "No project yet". |
| <a id="f240"></a>[F240](F240-The-Walk-Hand-Over-Carries-Porelo-Host.md) | — | — | The walk hand-over ships `porelo-host` and the start script points the interface at it; a missing local program said without the container sentence. |
| <a id="f242"></a>[F242](F242-A-File-Chooser-Beside-Every-Path-Field.md) | — | — | A *Choose…* button and the known default beside the KeePassXC database fields. |
| <a id="f239"></a>[F239](F239-Known-Values-Offered-In-The-Wizards.md) | — | — | Known values offered: the organization's repository address and the KeePassXC database. |
| <a id="f262"></a>[F262](F262-Lock-And-Purge-Say-What-They-Do.md) | — | — | A project member's *Lock* says what it does. |
| <a id="f265"></a>[F265](F265-The-Server-Page-Shows-What-It-Holds.md) | — | [F266](README.md#f266) | A server's page shows its own state, its projects and its persons with their state; actions chosen from the rows. |
| <a id="f266"></a>[F266](F266-The-Project-Screen-Shows-Its-Persons.md) | — | — | A project's screen shows its server and its persons with their state; actions chosen from the rows. |
| <a id="f207"></a>[F207](F207-A-Tasks-Branch-At-The-Forge-Named-By-The-Projects-Scheme.md) | — | — | A task's branch at the forge from the project's scheme, shown, named at the start and approved to by default. |
| <a id="f205"></a>[F205](F205-The-Hosts-Setup-Commands-Run-By-Their-Paths.md) | — | — | Every command `porelo-host` runs on the host over ssh, and through `sudo` above all, named by its absolute path. |
| <a id="f138"></a>[F138](F138-A-Host-On-Fedora-From-The-Same-Command.md) | — | — | `porelo-host` bringing a Fedora host up and down as it does Ubuntu 26.04. |
| <a id="f146"></a>[F146](F146-The-Hosts-VM-Pool-Switched-On.md) | — | — | The host's pool of small test VMs switched on on `porelo_host` and in the host dialog, with its systems and accounts. |
| <a id="f149"></a>[F149](F149-A-Panel-Plans-The-Release.md) | — | — | A panel that shows and edits a project's release plan by dragging issues into sprints and their functions, writing only the plan file. |
| <a id="f193"></a>[F193](F193-What-A-Walk-Left-Open-For-Keys-And-Tasks.md) | — | — | Key handling, one way to a running task and the proposed project model, built or decided against. |
| <a id="f200"></a>[F200](F200-KeePassXC-Shipped-On-Windows-And-macOS.md) | — | — | KeePassXC's signed build shipped with the interface on Windows and macOS, with its license and source offer, for the person's secrets file. |
| <a id="f203"></a>[F203](F203-This-Repository-Worked-In-A-Porelo-Task.md) | — | — | This repository's agent working in an attended Porelo task on the host, its build green on the host's Forgejo, reached in the room, with a way back. |
| <a id="f354"></a>[F354](F354-The-Integration-Leg-On-A-Machine-Of-The-Hosts-Pool.md) | — | — | The Build's integration leg on a host's Forgejo against a machine its pool lends by kind. |
| <a id="f355"></a>[F355](F355-One-Order-For-A-New-Person.md) | — | — | One order in the window for a person starting from a GitHub organization, with or without a key, each step showing its state, so *Create it* is reached only when it can work. |

### Estimated

| # | Size | Blocked by | What it covers |
|---|---|---|---|
| <a id="f145"></a>[F145](F145-The-Hosts-Forge-Switched-Off-In-The-Server-Setup.md) | S | — | *Set up a forge on the server* in the server setup dialog, on by default; switched off, the host's inventory says `porelo_host_forge: false`. |
| <a id="f93"></a>[F93](F93-Connections-Rare-Actions-Out-Of-The-Way.md) | S | — | Connections' rare actions in its ⋮. |
| <a id="f91"></a>[F91](F91-One-Way-To-Show-Loading.md) | M | — | Every view shows the same way that it is reading. |
| <a id="f94"></a>[F94](F94-A-Projects-Keys-Told-In-One-Place.md) | M | — | A project's keys told in one place, the signing key checked against a branch rule. |
| <a id="f97"></a>[F97](F97-Forwarding-Measured-Against-GitHub.md) | M | the test organisation and its token from the operator | Forwarding to a chosen branch measured against GitHub. |
| <a id="f105"></a>[F105](F105-A-Tasks-Terminal-In-The-Interface-As-Outside-It.md) | M | — | A task's terminal in the interface behaves as in a plain terminal. |
| <a id="f59"></a>[F59](F59-A-Project-From-A-Repository-Measured-Against-GitHub.md) | S | the test organisation, its token and signing key from the operator | Making a project from a repository measured against GitHub. |
| <a id="f72"></a>[F72](F72-Forges-Beyond-GitHub.md) | L | the operator's evaluation licence for Bitbucket Data Center | Forges beyond GitHub: Bitbucket Data Center first, measured against a test installation of its own. |
| <a id="f37"></a>[F37](F37-Reach-A-Machine-Without-An-ssh-Binary.md) | L | — | A machine reached without an `ssh` binary. |
| <a id="f52"></a>[F52](F52-Release-A-Devices-Key-Only-With-A-Touch-Or-A-PIN.md) | XL | — | A device's key released only behind a TPM2 PIN; a touch later. |
| <a id="f109"></a>[F109](F109-The-Interface-On-macOS-With-Porelo-In-A-Local-VM.md) | XL | — | The interface on macOS, with Porelo in a local Lima VM set up from the window, and remote machines over ssh. |
| <a id="f104"></a>[F104](F104-An-Offline-Project-Shown-With-Its-Way.md) | M | — | An offline project shown, with the way to make one by hand named. |
| <a id="f81"></a>[F81](F81-The-Setup-Script-Checked-By-Its-Signature.md) | M | — | The setup script verified by its signature before it runs. |
| <a id="f88"></a>[F88](F88-A-Nickname-For-Each-Agent.md) | M | — | A nickname for each agent. |
| <a id="f62"></a>[F62](F62-An-Organisations-Policy-Is-Shown.md) | M | — | An organisation's policy shown. |
| <a id="f142"></a>[F142](F142-The-Drafts-Offered-Before-The-First-Task-In-Default.md) | M | — | The machine's proposed tools and rules shown before the first task on a repository in `default`, and the choice passed back. | — |

### Finished

| # | Title | What was built |
|---|---|---|
| <a id="f222"></a>F222 | A Refused Unlock Asks Again In Its Terminal | A wrong vault passphrase asked again in the same terminal, up to three times, before the terminal ends. |
| <a id="f291"></a>F291 | A Host Card With A Name Or An IPv6 Address Read | A host whose card names a host name or an IPv6 address written, raised, read back after a restart and given as a server, as one at an IPv4 address. |
| <a id="f315"></a>F315 | Saved Settings Dropped Once And Said | Settings from before the organization put aside at the first start, without a migration, and said once in one sentence. |
| <a id="f314"></a>F314 | The Calls Behind The Organization Pages | The organization's, project's and host's pages and *Connect* over Porelo's commands, *Forges* cut to forge access, and "registry" gone from what a person reads. |
| <a id="f313"></a>F313 | Connect Once Per Host | *Machines* lists the hosts of a person's projects and those they administer, with one connection per host from the organization's card. |
| <a id="f312"></a>F312 | A Host Page For Its Host Admins | A host's page with the projects it carries and their state on the host, its host admins, its address and *Refresh*, and a person's own connection. |
| <a id="f311"></a>F311 | Register, Join And The Developers Dialog Taken Out | *Register*, a project's *Join* and the developers dialog removed: a person who belongs to a project finds it ready. |
| <a id="f310"></a>F310 | A Project Page For Its Admin And Its Members | *Projects* lists a person's projects once with their host, and a project's page holds its address, repositories and members, changed by its admins alone. |
| <a id="f309"></a>F309 | The Organization Page | *Organization* in the rail with its people, projects, hosts and owners, each person seeing only the actions of their roles. |
| <a id="f143"></a>F143 | The Agent The Machine Found Is The Default | The start form sends no agent until one is picked, says which agent the machine chooses and why, marks in its list who is signed in, and offers an agent found on the machine for import into the vault. |
| <a id="f268"></a>F268 | One Key And One Card Per Person | One Ed25519 key and one card per person made by Core and kept in the KeePassXC file, the card filed in the registry, a changed or lost key handled. Tested in sprint 6m: passed. |
| <a id="f269"></a>F269 | The Registry Read For Every List | The registry kept in a private checkout and read through Core for every list of persons, hosts, admins and projects. Tested in sprint 6m: passed. |
| <a id="f270"></a>F270 | One SSH Tunnel Per Host From Its Card | One ssh connection per host written from its card, carrying the forge, Git, Matrix and the daemon, with the host key pinned. Tested in sprint 6m: passed. |
| <a id="f271"></a>F271 | A Host Admin Admits From The Registry | A host admin from the registry prepares a server, files its card and admits project admins from the registry's persons. Tested in sprint 6m: passed. |
| <a id="f272"></a>F272 | A Project Admin Registers And Adds From The Registry | A project admin registers the project on an admitting host and adds developers picked from the registry. Tested in sprint 6m: passed. |
| <a id="f273"></a>F273 | A Developer Joins At One Click | *Join* at one click for a person named in a project's access file: the project followed and the card tunnel up. Tested in sprint 6m: passed. |
| <a id="f274"></a>F274 | Push And Pull With The Central Forge Started By A Person | *Push the approved main…* and *Take the central state…* on a card host, the central token fed from the secrets file to the host's command alone. Tested in sprint 6m: passed. |
| <a id="f275"></a>F275 | The Sign-In Says Its Flow | The sign-in terminal says whether to paste a code or confirm on the device page. Tested in sprint 6m: passed. |
| <a id="f276"></a>F276 | The VPN, The CA And Per-Machine Keys Taken Out | The VPN, the host CA, per-machine keys and the project signing key taken out; hosts kept from before named as such. Tested in sprint 6m: passed. |
| <a id="f277"></a>F277 | Commits Signed With The Person's Key | Commits the interface makes signed with the person's key through the agent and checked against Core's signers. Tested in sprint 6m: passed. |
| <a id="f278"></a>F278 | The Machines, Projects And Forges Pages | The *Machines*, *Projects* and *Forges* pages as lists of rows with ⋮ and a page per item. Tested in sprint 6m: passed. |
| <a id="f280"></a>F280 | A Lost Or Stolen Key Replaced | A lost or stolen key replaced by an admin, or with the offline backup key where there is a single admin. Tested in sprint 6m: passed. |
| <a id="f208"></a>F208 | Roles Given At The Start Of The Interface | Roles given at the start (`--roles`), each command shown only for its role; normal work alone without it. Tested by walk 23. |
| <a id="f209"></a>F209 | The VPN Kept Per Host, Several Up At Once | The VPN kept per host with its own network, interface, hosts lines and CA, several up at once, a colliding network refused. Tested by walk 23. |
| <a id="f210"></a>F210 | The Secrets File Grouped By Host And By Project | The secrets file's entries under `hosts/<host>/` and `projects/<project>/`, today's moved once. Tested by walk 23. |
| <a id="f211"></a>F211 | A Server Prepared With No Project | A server prepared by its host admin with no project, a project registered for its admin, project admins admitted by hand. Tested by walk 23. |
| <a id="f212"></a>F212 | The Forge's CA One Per Host | One lasting CA per host, constrained to its names and network, signing its forge and homeserver, trusted per host; the lasting forge password, split off from [F202](README.md#f202). Tested by walk 23. |
| <a id="f213"></a>F213 | A Project Brought Onto A Prepared Host | A project brought onto a prepared host by its admin in their own account, its `host:` block and Matrix settings signed into its private `access.yml`. Tested by walk 23. |
| <a id="f214"></a>F214 | The Setup Files And The Stop Split By Act | The setup files in the person's own home and the stop fed by act: root takes only the VPN key and the forge's certificate. Tested by walk 23. |
| <a id="f215"></a>F215 | The Developers Of A Project Kept In Its Access File | The project's developers kept in its signed access file, read access to it granted through GitHub's API, each developer's state read from host and forge. Tested by walk 23. |
| <a id="f216"></a>F216 | A Developer Joins A Project On Its Host | A developer joins from the signed access file with nothing handed over: verified by a local Porelo, own VPN, CA by its fingerprint, the join in their own account. Tested by walk 23. |
| <a id="f232"></a>F232 | The Project Admin's Own VPN For A Bring | The bring on a project admin's own machine brings its VPN to the host up from the pasted values, its address and its copied keys, and trusts the host's CA by `ca_sha256` before it brings. Tested by walk 23. |
| <a id="f231"></a>F231 | A Link Only The Task Can Reach Is Not Offered For The Browser | A link a task's program prints to an address only its container reaches shown below its terminal as only reachable inside the task, with no browser button. |
| <a id="f230"></a>F230 | Text Selected With The Mouse In A Task's Terminal | Shift+drag selecting in a task's terminal without reaching the program, said in the hint below it, and the program's own copy (OSC 52) put on the clipboard while a read of it is never answered. |
| <a id="f229"></a>F229 | A Restarted Task Says So In Its Terminal | A task's terminal says above its screen when the task was started, and its tile *started HH:MM*. |
| <a id="f217"></a>F217 | The Laptop's Homeserver Published For The Host While Its VPN Is Up | The laptop's homeserver published on its VPN address while a host's VPN is up and closed at the give-back, the host's registration token fed at its stop, and the laptop's hosts line shown to add by hand. |
| <a id="f202"></a>F202 | The Forge's Certificate Signed On This Desktop | The forge's certificate signed at the host's stop by one lasting CA kept in `secrets.kdbx`, the CA trusted on this desktop by the VPN's root step, and a warning before it ends. |
| <a id="f201"></a>F201 | The Person's Own Drive Mounted In Their Account | The drive taken out of the host's setup, and an optional step of the machine setup that installs Tresorit from its signed installer, signs in and syncs a tresor in the user's own account. |
| <a id="f199"></a>F199 | A Host's Stop Fed From The File Without Typing | A host's stop fed from `secrets.kdbx` on one pipe, the master password typed once, and the central forge's token sent after `up` asks for it. |
| <a id="f197"></a>F197 | The Host's Files Uploaded Over Its Own Ssh | The host's `machine.yml` and bundle uploaded by `porelo-host up` over the host's own ssh into `/etc/porelo-host/setup/`, digest-checked there, the desktop's copy in the interface's own folder. |
| <a id="f196"></a>F196 | The Public Ssh Key Follows Its Private One | The public ssh key filled from the private one as `<private>.pub` whenever that exists, and a public key of another pair refused at the field, asked of `ssh-keygen -l`. |
| <a id="f195"></a>F195 | The Signing Key Checked As It Is Chosen | The signing key on the host dialog checked against the verified commit as soon as the field changes, with a check mark or an error icon and no stale answer. |
| <a id="f228"></a>F228 | A Long Step Of The Machine Wizard Shows Its Progress | The machine wizard's Install Tresorit in phases with the megabytes fetched and sent, a failure naming its phase, and the setup script's last line. |
| <a id="f227"></a>F227 | Take This Server Down As A Tile | Take this server down drawn as a red tile among the server page's tiles, its confirmation unchanged. |
| <a id="f226"></a>F226 | A Setup Run Again Shows In Its Server's Row | A setup run again on a ready server shown in its row with step, time left and protocol; taking it down, forgetting it, putting the project on a server and running it again unavailable meanwhile. |
| <a id="f225"></a>F225 | A Line To Add By Hand Copied As Its Whole Command | The homeserver dialog gives the one command that adds this computer's hosts line, exact-line checked, in a box with a copy button. |
| <a id="f198"></a>F198 | A Host's Secrets Kept Once In The Person's KeePass File | A host's secrets kept once in the person's `secrets.kdbx` under one master password, its `shared` and `hosts/<project>` groups, made and opened from server setup's own step in a terminal of the interface, with keepassxc-cli checked first. |
| <a id="f148"></a>F148 | An Agent For Each Repository, At One Click | At one click, an attended task for each of a project's repositories that names an agent, a repository left out before the start, a stopped one brought back, agents signed in on the way, and one that runs not offered again. |
| <a id="f194"></a>F194 | A Signing Key That Did Not Sign The Bundle Refused | Server setup checks the verified commit against the chosen public key for signing commits on *The drive*, before a server is rented, refusing a key that did not sign it with both fingerprints, naming swapped key fields, and opening the field on a key the project's machine pins. |
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
| <a id="f221"></a>F221 | A Host's Vault Unlocked From The Secrets File | Replaced by the host vault opened by the person's key: no value of a secrets file is fed to a host's vault. |
| <a id="f244"></a>F244 | A Bring Reads A Private Repository With The Follow's Credential | Replaced by a host that carries its projects and follows them by itself: no bundle of a private repository is made here for a bring. |
| <a id="f245"></a>F245 | The Forge Password Kept Only Once The Forge Took It | No forge password is typed or kept here any more: a forge is reached with a person's key and token. |
| <a id="f246"></a>F246 | The Host Collection Where Every Account Finds It | No account runs a bring or a join from the host's collection any more: a host follows its projects by itself. |
| <a id="f250"></a>F250 | Pasted Host Values Taken As Meant | No host values are pasted any more: machines and projects are chosen from the organization's lists. |
| <a id="f251"></a>F251 | Firefox Reads The Policy The VPN Wrote | The interface sets up no VPN any more: a machine is reached over SSH. |
| <a id="f253"></a>F253 | The Host's Sync Answer Read As Written | The dialog that read that answer is gone: a host follows its projects by itself. |
| <a id="f257"></a>F257 | Follow It Never Ends Without An Answer | The *Follow a project* dialog is gone: a project is put on a machine from the organization's projects, [F342](README.md#f342). |
| <a id="f260"></a>F260 | The Join Log Without Ansible's Noise | The join's Ansible run is gone: a host follows its projects by itself. |
| <a id="f261"></a>F261 | The Take-Off Checks Its Secrets Entries First | The take-off feeds no such entries any more: taking Porelo off goes by the organization's card. |
| <a id="f64"></a>F64 | The Guided Walk as a Package of Its Own | Replaced by `flutter-guided-walk`, the package of its own this app already depends on. |
| <a id="f279"></a>F279 | The Steps Of One-Click Joining | Replaced by the rebuilt flow from the organization's pages: guided walks and their steps are not kept in this repository. |
| <a id="f218"></a>F218 | The Walks Walked Headless On The Central Test Machines | Guided walks are not kept in this repository. |
| <a id="f75"></a>F75 | One Definition For A UI Test And A Guided Walk | Guided walks are not kept in this repository. |
| <a id="f286"></a>F286 | A Recovery Hold Never Stuck And Its Commit Its Own | Superseded by [F289](README.md#f289): one recovery run at a time with named states and one hold owner replaces this fix of the earlier design. |
| <a id="f285"></a>F285 | A Recovery Run Ended, Pushed And On Its Own Base | Superseded by [F289](README.md#f289): one recovery run at a time with named states and one hold owner replaces this fix of the earlier design. |
| <a id="f283"></a>F283 | A Recovery Request Never Locked, Lost Or Misfiled | Superseded by [F289](README.md#f289): one recovery run at a time with named states and one hold owner replaces this fix of the earlier design. |
| <a id="f281"></a>F281 | A Kept Recovery Commit Finished, Not Made Again | Superseded by [F289](README.md#f289): one recovery run at a time with named states and one hold owner replaces this fix of the earlier design. |
| <a id="f258"></a>F258 | The Join's Secrets File Prepared By The Dialog | Replaced by one-click joining from signed state: No secrets file is prepared for a join with one-click joining: the join is one click, the vault unlocks by the person's key. |
| <a id="f256"></a>F256 | Another Machine Of The Same Developer Added By Choice | Replaced by one-click joining from signed state: Laptops go with one-click joining: a person reaches the host with their one key from any machine. |
| <a id="f255"></a>F255 | A Laptop Refusal Shown In The Dialog | Replaced by one-click joining from signed state: Laptops and their addresses go with one-click joining; developers are added by a pick from the registry. |
| <a id="f254"></a>F254 | A Laptop Address The Host Does Not Use | Replaced by one-click joining from signed state: No VPN addresses with one-click joining. |
| <a id="f249"></a>F249 | The Restored Identity Filled On A Recorded Host | Replaced by one-click joining from signed state: No identity file is chosen with one-click joining: the person's one key is served by their agent. |
| <a id="f243"></a>F243 | One Sudo Prompt To Connect And Trust A Host | Replaced by one-click joining from signed state: No VPN and no CA with one-click joining: there is no sudo prompt to connect a host. |
| <a id="f237"></a>F237 | A Kept CA For Another Network Said Before Renting | Replaced by one-click joining from signed state: The CA goes with one-click joining; nothing is kept for another network. |
| <a id="f220"></a>F220 | A Message In Needs You Checks Again Whether It Still Holds | The recheck exists: a machine that does not answer is asked again every 2 s (`FleetModel`'s retry), and the VPN rows by the periodic refresh; no row was seen staying after its cause was gone. |
| <a id="f139"></a>F139 | OneDrive As The Project's Drive | The host has no drive any more; a user's own drive is [F201](README.md#f201), where OneDrive may come later as an idea of its own. |
| <a id="f150"></a>F150 | The Person's Tunnel Brought Up From The Interface | Merged into [F157](README.md#f157), which brings the VPN up and down from the interface. |
| <a id="f84"></a>F84 | A Signing Key Found Or Made From The Window | Replaced by the person's one key, made and kept in KeePassXC: no signing key is chosen from a file. |
| <a id="f96"></a>F96 | Keys A Machine No Longer Knows, Found By Their Title | Replaced by per-person cards: the interface makes and removes no deploy key at the forge, and clearing a machine only asks its daemon. |
| <a id="f206"></a>F206 | The Host Walk Shows Today's Setup | Replaced by walks kept outside this repository: no walk or stand-in is kept here. |
| <a id="f234"></a>F234 | No Back Once The Server Is Being Prepared | Replaced by `HostDialog`, which has no *Back* once a run stands. |
| <a id="f235"></a>F235 | Leaving The Server Wizard While Machines Shows It | Replaced by `HostDialog`, which closes at once while the run goes on and *Machines* shows it. |
| <a id="f241"></a>F241 | A Project Followed From A Connected Forge | Replaced by the organization's pages: a project comes to a machine from the organization, and *Follow a project* is gone. |
| <a id="f247"></a>F247 | The Bring And Join Log Copied At One Click | Replaced by the rebuilt flow: the bring and join dialogs are gone, and a machine's protocol can be selected. |
| <a id="f248"></a>F248 | A Bring Replaces Its Own Earlier Upload | Replaced by the machine file root alone keeps: the upload per bring or join and its setup folder are gone. |
| <a id="f252"></a>F252 | A Published Access Change Reaches The Host | Replaced by hosts following the organization: a member change is committed there, with no bundle to upload. |
| <a id="f259"></a>F259 | A Grant To Someone Who Already Reads | Replaced by the organization's pages: no dialog grants read access any more, and nothing calls `grantRead`. |
| <a id="f267"></a>F267 | A Project Taken Off From Its Own Menu | Replaced by *Take it off the machine…* on the project's row for that machine's admins. |
| <a id="f287"></a>F287 | A Join Confirmed By What The Host Follows | Replaced by *Connect* per machine: a project is no longer joined. |
| <a id="f289"></a>F289 | A Key Recovered In One Run With Named States | Replaced by Core's `porelo identity revoke --lost` and its backup-key flows, behind `ReplaceLostKeyDialog`. |
| <a id="f294"></a>F294 | A Registry Host Listed For Its Host Admin | Replaced by the organization's list, where every machine stands for its admin ([F335](README.md#f335)). |
| <a id="f297"></a>F297 | Register's Progress With Its Steps And Usual Time | Replaced by a machine's preparation with its own steps: *Register the project* and its signed host action are gone. |
| <a id="f298"></a>F298 | No "null" In A Project Row | Done: a project row adds nothing where its tunnel has nothing to say. |
| <a id="f299"></a>F299 | A Registry Row With The Host's Confirmed State | Replaced by the organization's pages: the registry rows and their confirmed state are gone. |
| <a id="f301"></a>F301 | Persons Of A Project In One Place | Done on the organization's project page: its members stand in one section with *Add*. |
| <a id="f305"></a>F305 | No Join For A Project Already On The Host | Replaced by *Connect* and *Disconnect* per machine: a project offers no *Join*. |
| <a id="f233"></a>F233 | The Server Type And Zone Chosen When Renting | Replaced by `HostDialog` for a machine that exists: `porelo-host up` refuses renting, so no type or zone is chosen. |
