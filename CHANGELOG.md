# Changelog

All notable changes to this project are recorded here.

The format is [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- `porelo-host up` checks the collection's SHA-256 again on the host, right before `ansible-galaxy` installs it, and refuses a tarball changed there after the copy; both refusals name the digest found and the one expected.

### Changed

- The window now reads the planning part as the daemon serves it.
- Where a host cannot say how its copy of a repository stands against central, the repository's row says why in words, never the daemon's token.
- A project whose host waits for the person's token says so wherever it is shown, is never called carried there, starts no work, and offers *Give it my … token…* to that host.
- While a host waits for the token for one repository of a project, the repositories it has taken still read carried and start work, on the machine's and the organization's pages alike; only the repository that waits offers the token.
- A task's menu offers *Open its project’s room*, and the project's page a button *Open the project’s room*.
- The footer's refresh and actions counts name the machine they count, and a refresh that lost contact says so.
- *Join* in a project's messages that invites a Matrix account the person has already says to accept the invitation in their client, with no password shown or offered anew.
- *Put it on the machine* stays open until the organization answers: a refusal is said there, and a placing taken always goes on in its own dialog to its end.
- A machine's page of a project lists the repositories it carries first and folds the others under *Not carried here*, with their count; the host's `not-carried` reads as "not carried here".
- A saved story move on *Planning* counts as made once the machine moves the story's least advanced issues, as the machine chooses them, rather than staying pending with *The machine did not confirm this destination* when the card shows the story ahead of its issues.

### Added

- *Needs you* names each pull request open on the forge of a host that carries a project, as "pull request 1 of foo-1 waits for your approval and merge", with its head commit's makers through the trailer check and *Open the pull request*, which opens it on the host's forge; the row closes when the host says it was merged or closed, stays as possibly out of date while the host is asked again, and a missing forge token or a refused read is said in words, the store command to copy.
- A task whose agent said its work is done is shown as done in *Work* and under *Needs you*, never as running, and no running count counts it.
- The mock daemon's situation `pull-request` has one pull request waiting on the host's forge, merged with `m`, and a task that said done.
- Planning stories can be dragged to pending states, undone individually, and saved atomically with revision checks and daemon refusals.
- Story issue rows stage individual state changes in the same pending batch and atomic Save as story moves, retain applicable moves after a revision conflict, and display daemon refusals beside the affected issue.

- Planning cards and issue rows open live story and issue details with breadcrumbs, web links, reader findings and sub-agents.
- Stories can start and stop work from the planning board, choosing a watched machine, main agents, proposed participants and reading limits; *With you* opens the returned task, and ended work and stopped readings offer decisions in *Needs you*.

- *Planning* shows a project’s stories by workflow phase, with live updates, priority and search filters, folding, issue progress and reading rounds; a stopped reading leads to *Needs you*.

- *Set up a machine* offers *Run it for me* for the bootstrap line: on your press it runs the line on the server as the first login, trusting only the SSH host key you compared, and tries root's login right after; where sudo wants your password it says so, and the terminal stays the way.
- *Open its forge* on an organization's machine row and its machine page opens the host's forge in your browser while connected, and says why it is unavailable otherwise.
- *Put it on a machine…* offers the whole project, chosen to begin with, or some of its repositories; a repository already on a machine is named with it and not offered. A machine's page lists the repositories it carries of a project carried in part, each with *Take it off this machine…*, whose question says the machine deletes its read key for it and takes that key off the central forge. Needs a porelo whose `org host carry` takes `--repository`.
- A project's own page offers *Put it on a machine…* and *Take it off the machine…* to whoever administers the machine, with the same dialog, words and follow afterwards as its row on *Organization*.
- *My forges* also lists, and counts, the forges the machine shown already holds a credential for in its git connections, saying where each comes from (its vault, a file, a variable or the ssh agent) and whether it is there now, beside a forge set up here for the same host rather than twice, marks the Porelo organization's forge, and asks for no token for one the machine holds.
- *New work* in Default shows what a repository's `porelo.yml` sets that this machine has not allowed yet, only what is new, changed or removed, and allows exactly that with one press before it asks again whether the work can start; a file changed after it was shown is not allowed. In an organization's project, a `porelo.yml` changed without a signature is said with its file and commit, and nothing here allows it.
- *Image settings* and what a project may reach list what a repository's `porelo.yml` took away from its project's settings, and what took it away.
- Before the first task on a repository in Default with no settings of its own yet, the window shows what the machine proposes - what it found, the hosts it opens, the settings - and a yes keeps them on this machine only and allows them; a no starts with Porelo's own settings, and closing the question starts nothing.
- A first start from a checkout names the file it writes, and where the machine keeps the repository in Default, the work starts on the checkout's repository there rather than as a project of its own.
- *Image settings* in *Work*, on an opened row and on *Running*, shows what a task's image was built with and where each thing comes from.
- *New work* on this computer can start from a checkout there, asking the same question as a first start in a terminal before it writes `project.yml`, with what the plugins say of the checkout above it and beside each thing found; on another machine it says that nothing is detected there.
- Work started from a checkout on this computer starts from the branch that checkout is on, for the repository it is a checkout of; once started, the work says which branch it started from and why: the checkout's, the project's base branch or the repository's default. A detached checkout names none, and a machine whose Porelo takes no branch is not told one.
- A checkout's `project.yml` that is not taken is a warning in *New work*: why, what to write, and that this start uses Default and not that file.
- A file in a review that changed mostly at its line ends, such as CRLF to LF, says so with the count without them beside git's own, and the diff can be read without them where the machine can leave them out.
- A forward refused for its ssh key says in the review what happened and which key was used, lists the account's keys from its ssh-agent and its files, tries one alone without pushing anything, keeps one for that address and forwards again, and opens what only a terminal can do in a terminal on the machine once you start it.
- *New work* asks the machine whether the task's agent is signed in there, and where it is not, says so and offers *Sign in*: it starts the machine's own login, or finds the one running, and opens a terminal on that machine attached to it, where you follow the link and paste the code; nothing starts until the machine says the agent is signed in and that work can start, and closing the dialog leaves the sign-in running. Where the machine already holds a sign-in of the agent, it offers to use that one first, and a sign-in of its own only as a second choice. *Start an agent for each repository* asks once for every agent and signs the missing ones in one after another before it starts any. Where the machine cannot say whether the agent is signed in, its answer to whether work can start decides, and no sign-in is offered. A repository the machine does not carry is never offered to start in, also from a job, *Continue* or *Restart*, nor started from its row or among the agents for each repository. Needs a porelo that serves `AgentSignIns`; with an older one the start goes as before.
- *New work* shows the model the task will run, as the machine names it for the provider it uses, and lets you change it; *Continue*, *Restart* and *Recreate* keep the task's own. A task's row and its terminal's header name the model and where it came from, and a task is shown by the name it was given at its start. *Start an agent for each repository* sends none, so each task takes its repository's default. Needs a porelo that serves `ProviderModels` and the task's model; with an older one the field stays empty and the machine takes the provider's default.
- A project opened from a machine says of each repository whether the machine carries it, how it stands against central and how much of its work runs, as the machine's own Porelo says, also for a person who is no Machine Admin; a repository the machine does not carry offers no start. Ahead with no count says the count is not reported, a central state not reported yet is never at central, and one of a later Porelo is shown as it comes. Needs a porelo whose repositories carry these.

### Changed

- A waiting push's review also reads each commit's whole message for a Co-Authored-By outside the trailer lines, and where the machine does not report the message, says the check cannot be made instead of passing it. Needs a porelo whose `Review` and `Pending` carry `message`.
- Joining a project's room on a host running its own homeserver sends you to Element instead of a join the host would refuse: where Element is installed here, *Open Element signed in to this host* starts it with the host's homeserver set and its SSO sign-in first, by default as a separate instance with its own profile for that host; otherwise *Install Element* and the way by hand, with the homeserver to copy. Elsewhere, the room of an organization's project on a host carrying it offers only the logins it admits to join as, and says where the organization is not read yet or could not be read; Element that cannot be started says why.
- *Agents & providers* shows an unfolded agent's facts as label and value in two aligned columns, the hosts it needs and those it is refused as chips with their note under them, and what it fetches with its sha256 shortened and a button that copies it whole.
- A waiting push's review opens with its commit and names the author, committer and trailer lines of each of its commits where the machine reports them, with a chip that says whether a commit holds exactly one Assisted-by and no Co-Authored-By, or what is wrong; where the machine does not report them it says so, and the check is never shown as passed; the fetch into your own clone follows the files. Needs a porelo whose `Review` lists `commits` or whose `Pending` names the author.
- A work tile names each workflow of its commit's build with its own verdict, and says a pass over the workflows that have run so far, never as the whole build: one that passed alone is named as a workflow, a workflow that failed, timed out or could not start is named in the headline, every one skipped reads *No workflow ran*, and a pass given without its workflows is said as the machine's word, not as green.
- Where the machine lists a build's runs, a work tile shows one line per run with its own verdict, also while it is queued or running, names every failed run, and says passed only when the machine says success and every run succeeded; no runs beside a success reads *No workflow ran*. Needs a porelo whose `Build` carries `runs`.
- A machine an organization's card names has one head: its path, name and state, its Porelo and when it last answered, with *Open its forge* as a button beside *Disconnect*; where the forge gives no answer through this computer's forward the page says so, and *Open its forge* raises the forward anew before opening. Its managing leaf is *Machine Admins*, their list with *Add a Machine Admin* and *Make a backup key* alone, while this computer keeps *Managing this machine*. A project opened from a machine shows each of its repositories there, carried, not carried or held, its state at central and the tasks running in it, with the project's own page as one link and no list of that machine again. *New work* on a machine that carries one project besides Default opens in it, with *change* for another.
- An organization's machine row shows its state before the machine's name, and its buttons right-aligned inside the row, wrapping together when narrow.
- A machine's Prepare protocol keeps its last line in view until you scroll up, says with *Following* whether it follows, and follows again at the end or when *Following* is turned on.
- Right after Prepare, while the machine has not yet made your account on its first follow, the side bar and the machine's row say that they wait for it to admit you instead of showing a refusal; a turn-away after five minutes is a refusal again.
- *Give it my token…* while putting a project on a machine turns into *Handing the token over…* until the machine was asked whether it took it, does not come back once given, and the dialog then says *Done*.
- A task's terminal sends the mouse wheel to the program as wheel reports when it asked for mouse reports, so tmux scrolls its history; where the window scrolls its own lines, new output leaves the view where you read and *Jump to latest* goes back to the end.
- Leaf pages distinguish unread lists from empty ones, keep their names on phones, retain a back link to the list they came from, and show the state actually read beside each item without adding controls to read-only rows.
- *Work* and *Needs you* keep their totals consistent with the side bar through filtering, unread machines, refused connections and lost contact, and count waiting notices even before a work list arrives.
- *Work* and *Needs you* use the leaf page head and state chips, with *New work* above the List/Running switch and a Needs you total matching its badge above separate group cards; Running keeps room for its terminal on phones and tablets and across view changes, with filtering and sorting in List only.
- Forge and project pages have clear page heads, visible filters and state chips; each organization section keeps its own head and controls for retrying failed reads while displaying provisional changes, with distinct role and status words and setup actions kept in reach.
- Each machine’s Tasks, Projects, Vault, Credentials, Agents & providers, Health, and management open as pages from its side bar, keeping their data and actions on that machine, with the vault's contents in view and action results on the same page.
- A machine's Tasks page names its path and title; leaf paths start right under the title bar with even spacing, long state chips end in an ellipsis, filters show their whole hint where there is room, counts of one read in the singular, and the side bar's entries start right of their parents' names, one row height each; from tablet width up the organization's button stands left of the title bar's actions.
- A machine's Vault, Health, Credentials and Agents & providers are pages in the list look, with no panel to close: entries as rows with a state chip, the vault's never showing a value. *Managing this machine* names the machine once with its state, shows Connection, Vault, Work and Health as tiles, gives each action that cannot run now its reason beside it, and keeps *Stop everything* and *Clear this machine…* apart in a danger zone. *Declare a provider…* is gone: a sign-in is imported and a key added as a connection.
- The side bar folds into machines and organizations with facts and actions on their parent pages, stays beside the page on tablets, keeps a stop for every machine in the title bar, retains machine actions and page explanations, and keeps machine setup and organization return paths on the right page.
- A refused organization change says when this computer's Porelo-Vault is shut, which Porelo reads your forge token from, and offers *Open this computer's Porelo-Vault* beside the refusal.
- *Give it my … token* while a project is put on a machine gives the token this computer's Porelo-Vault declares in one press; only where it declares none does the token's page open.
- *Start work* says how long each mode runs: a shell driven by hand has no time limit; an unattended run asks *Minutes it may run*, 30 unless you change it, and a run still going then is ended, keeping what it made.
- Setting up a server as a machine is a wizard of one question per page, each page opening only once its answer holds: the machine, the server's address answering SSH, its SSH host key fetched when you ask and compared on the server, an address your `known_hosts` holds with another key said so, root's login handed over in a terminal on the server until root answers with your card key, and the check. Its last page, also behind *Give it your token…*, names each source of a forge token with what it answered.
- Putting some of a project's repositories on a machine lists full names and project keys with searchable checkboxes. *All* and *None* affect the visible choices; repositories carried elsewhere stay listed with their machine and cannot be selected.
- Forwarding a waiting push names its destination and prefills the task's forge branch or its last confirmed forward, kept separately for each machine, project, repository and task.
- A machine shows how each taken repository stands with central and requires a separate decision to give it back while any work is ahead, central has moved on, or its safety cannot be confirmed.
- Where a setting can come from a repository's own `porelo.yml`, the window names it beside `project.yml`: an image setting's source, what a project may reach and what one repository adds to it or takes away, the credentials a start is given, and Default on another machine.
- Adding, changing or removing a project's repository, changing its review policy and filling a project from a checkout no longer sign a change: Porelo changes no project file that exists, so the dialog shows the entry it says to write, the file it goes in, and a button to copy it, and a project admin commits it.
- The waits-on-you note under *Running* shows a question's time left, updates while it counts down, and says when time is up or the machine gives no deadline.
- Taking Porelo off a machine says what the machine says stays on it, such as the firewall and the command that takes it off, whole and copyable. A rental given back says nothing of a machine now gone.
- *Work* keeps only the *List*/*Running* switch at its top: *New work* stands in the card's title row, and its search opens from a magnifier, as on the other pages. *Needs you* has no title or rule of its own. A row of work says its state in a few words, with the sentence when opened.
- Rows of a list stand on white in the light theme, under a paler head. The *Follow* switch is smaller, a terminal's text stands further from its edges, and only `✻ Finished` is green among an agent's star lines.
- *My projects* lists only the organization's projects the person holds a role in, and the side bar counts the same; *Default* and a project a start in a checkout copied stand under *All projects on your machines*.
- The page of every project on your machines is titled *Projects on my machines* beside an organization, and its back link says *My projects*.
- Preparing a host asks in plain words whether it has a forge of its own and whether it runs VMs in its jobs, says what each costs, and installs what was chosen; a CPU that cannot run VMs says so before anything is installed.
- Every page has an `i` beside its title that opens its explanation, which stands open only the first time the page is opened; *Organization*'s head is one line, with a warning in it where there is one.
- A terminal stays dark in the light theme, as in a console, and answers a program asking for its colours; the tab's head and the page around it follow the theme.
- An opened row in *Work* shows only the work's status and its way on: the block of the terminal's last lines is gone, as *Running* has them.
- Work starts in the *Default* project again. A start on this computer asks for no certificate, as the command line does, and on a host the person's agent certifies a task of no project with the first key it holds.
- A grey button says why in words, with no hover: a row's button on the line under its title, *Push approved main* and *Connect* in a row of *My projects*, *Start again* under it, *Join* and *New password* in the messages dialog.
- Work with no terminal open says so, rather than that its session ended: a machine says the same of one never opened. A row waiting on a person says that first. A terminal the machine refused keeps what it said, whatever a later look finds.
- What a machine can run is no longer kept from the look before: a check that fails says so, and a late answer from a machine left behind is dropped.
- A machine first gone to takes the page only when it lacks something, so a click on a row of its work opens the row. Asking what it can run stays one action away.
- The bottom line counts *Actions*: what was asked here, so that "0 running" does not read as a claim about running work.
- A start this computer would not certify says that no agent ran. Any other start that ended says its code, without naming an agent that may never have run.
- Creating a Porelo organization can ask first what that needs at the address, and says each need with what to do.
- A grey command on a list's head says why under the head, not only behind a hover. Creating a Porelo organization at an https address says, before it is filed, that no machine can follow it.
- The side bar and its pages say *My projects*, *My machines* and *My forges*, and each number counts that page's rows. Creating a Porelo organization lists its forge under *My forges*, asking for nothing.
- A project with no Git repository yet says so on its row under *Organization*, with *Create the project's Git repository* for its Project Admin and a row under *Needs you*, and it stands under *Projects* only once it exists. Whoever names themselves as Project Admin creates it in the same step. The window asks `porelo project create-repository` rather than `project open`.
- *Prepare a machine* checks the machine first, where the collection carried with it holds a check: *Check this machine* lists every finding at once with what was found, what was asked and what to do, and changes nothing there. *Prepare the machine* is offered only once it passes, a changed choice, address or key runs it again, and a check that gave no answer offers nothing. `porelo-host check` does the same on the command line.
- A machine waiting for its first token has a row under *Needs you* for its Machine Admin, leading to its page, in place of one saying it cannot be reached.
- A repository with no central address says so on its project's page, because a machine takes nothing from it, and its Project Admin can name one from its menu.
- The window says *Porelo organization* wherever a forge's organization could be meant too, and the help says what it is: it lives in a repository inside the GitHub organization, or your forge's. The navigation item stays *Organization*.
- A foldable list with nothing in it starts folded and folds when emptied, and opens with its first row, so a page shows what holds something; a fold you chose stays, and the actions on a list's head stay usable.
- The project every machine has is named *Default* everywhere, where the window said "without a project"; a project in the organization may not be named so.
- *Prepare the machine* offers only the listed machines of which you are a Machine Admin, names the command to compare a host key with, and asks for the key again before it starts: one changed since it was compared starts nothing. A refused key says what happened and offers to enter another.
- *Prepare a machine* says what it waits for beside its button, and a login that answers and exits non-zero shows its words and its code. A machine whose root is still closed names the command to run.
- *Connect* on a machine waiting for its first token names that step and leads to it, and the row and the machine's page say one thing. A connection the machine closes before login says to wait a minute.
- A repository added before a project has a machine is filed with its central address, so a machine takes it when it comes.
- *Work* is one list, *All work*, with a search over name, project and machine and a sort, starting by state; the machine and project filters and the groups are gone. A row unfolds to its repository, way of working, start, tokens used, commits at the gate and last lines, leads on from there, and decides nothing.
- *Work* > *Running* has a tab per running agent and is the one place terminals are: Ctrl+PgUp and Ctrl+PgDn go to the next agent, leaving a tab or the page leaves its session while the agent runs on, and coming back shows the same tab. An unattended agent shows its log there, marked with headings, errors and results, with a *Follow* switch.
- A running task whose terminal has ended says so in its tab and its row and offers *Open a new terminal*, or *Read its log* where none can be opened, in place of a black bar.
- Consoles of work follow the window's light or dark.
- *Needs you* stands its rows in cards, *Decide soon* and *Reviews* first, and counts every row, work at the gate too: its header and the rail's badge say one number.
- Work that ended with a failure, or left files that never reached the gate, is a row of *Needs you* until its log is opened or it is put away; a question's row also offers *See its terminal*.
- What came of an answered question goes under *Recently resolved* with its words and no longer counts in *Needs you*. A question that ran out with nobody answering counts until you say you have seen it, past a restart.
- *Put it on a machine…* follows the machine in one dialog: it connects, offers the token if the machine waits for one, and says when the project is carried or why not. The token this computer keeps goes to the machine after your word, on standard input, with no terminal, and a press that gives none says why beside the button.
- Work started from the window on a host starts: what the host asks to certify is checked here and signed by your agent on this computer, which never leaves it. A key missing from the agent is named by its fingerprint at the start. A certified task can be certified for another week from its menu, and says so within a day of its certificate's end.
- A machine's *Start work* names the project it carries and starts there, asks which among several, and says why beside the button when it cannot; a project the machine carries is taken at a person's first start.
- A project on a machine's page says it is being put on, and a project the machine refused or carries with a reason says why, in place of the host's bare word.
- A project or repository on a machine names that machine's own forge for its tasks, by the port on the machine's card.
- A project's page shows the review policy Porelo names for the project and for each of its repositories.
- A machine's row under *Organization* offers taking Porelo off to its admin on any computer, going by the organization's card,
  and says what is missing where it cannot. The dialog names the projects still on the machine and what is safe.
- A project and a repository of one name are refused here, with another name offered.
- A person the organization names as neither admin of a machine is told so instead of being offered taking it down, and a
  machine's refusal of their key reads as that.
- An answer that names the Organization Admins in any other form than a list cannot be said, and no longer reads as the owners' rule.
- *Make my card…* proposes public identity values and their sources, asks only unresolved questions, and offers *Sign* or manual entry.
- Cards due for renewal show a warning and *Renew my card* on the card and Organization pages, with the same operation kept for a retry.
- Opening a project asks whether you work alone; review can be required or made optional from its Project Admin's menu.
- Organization and Project Admins can preview a checkout's proposed settings and warnings, then sign it into a project.
- Organization creation and project opening hand a missing forge token from the system secret store to the local vault
  on standard input, ask for a missing token in the existing dialog, and offer vault opening first. Unknown forge SSH
  keys can be compared and trusted in the window. Machine preparation fetches a host key for explicit comparison and
  offers only the card's selected agent key over SSH, avoiding the server's authentication attempt limit.
- *Prepare a machine…* follows the organization: an Organization Admin or a Machine Admin sees it, as does a person with no
  organization yet, and `--roles` is gone. The dialog no longer asks the collection, which the build knows.
- *Create another organization…* stands beside *Choose another organization…*, and says the first stays on its forge.
- Interface wording uses machines and named admin roles, distinguishes taking Porelo off from returning a saved rental, and explains SSH connections in plain words.
- Project rows offer a direct connection to their machine and say where to work; the machines link includes all projects.
- Machine setup explains which forge token it needs, its one-time use, required repository rights, and that it is not kept.
- Clearer words: a command's refusal in a terminal, a file in the way at *Connect*, a wrong *SSH host key* paste, a busy
  port held by another window, why *Connect* stopped, a project on a host with no address, and no `--id` in a refusal. A
  refusal below the fold of the host dialog scrolls into view, and the lost-key plan offers only its own *Cancel*.
- A central forge off ssh port 22 is found in `known_hosts` under the name ssh writes for it, so its key reaches the host.
- The dialog asking for an organization's address says that an organization lives on a forge outside every host.
- The organization's pages show a mark while a change is being asked for; a refusal in a dialog goes once what it answered
  is changed; *the organization has moved on* says what to do next; and the list under *Projects* and a person's row say
  *developer*, as the project's own page does. A terminal no longer leaves Core's JSON answer on the screen after a
  backup key or a host's token went well.

- *Prepare a server…* is judged on the organization: who may is read from `porelo org --json` for that very host,
  again before anything happens, and a `stale` answer prepares nothing. `up` takes a machine file whose `organization`
  part holds the settings, the central forge's own keys from the person's `known_hosts` and a pin of every admin key,
  backup keys included; no forge key or a row with no key stops before a server is touched. A host's real address, port,
  key and services go on its card with `porelo org host change`, and an `up` that stops or a card refused gives back
  what was rented and says so. It takes the key on the accepted card, not the login alone, and hands the pin of that
  moment to a setup taken up again; a forge key your `known_hosts` revokes, by wildcard too, stops it. A host admin
  whose card is not trusted yet stops it by name, until it is asked again. A first card with a new key says before it starts that the key must
  reach the forge first, and that the first run makes no card.

- `porelo-host up` of a server refuses without `--machine-file`, and places that file for root alone, checked by its
  digest, before the host is set up. A host that names no forge now completes; the service ports it reports are kept
  apart from the person's local forwards.

- A test instance takes its forge token from `PORELO_FORGE_TOKEN`, for the one forge `PORELO_FORGE_TOKEN_FORGE` names,
  and the central token a terminal hands to a host from `PORELO_CENTRAL_TOKEN`, asking nothing.

- A host's page shows a host admin what the host's last fetch refused, in the host's words, to judge: it stays on what
  it took before, and that can be a removal or a commit nobody allowed.

### Removed

- The interface's own organization checkout and its reads: the repository setting, the private checkout, the bundle
  and access contracts behind them, the host's former signed publication and its returned-host memory. The
  `--roles project-admin` role is gone: a project admin is whoever the organization says.

### Fixed

- *This machine*, saved at a socket that has since moved, is listed once at its socket now; it was listed twice and the side bar did not draw.
- Saving planning moves waits for the latest issue details when a save reply and watch update arrive together.

- Planning falls back to a live board after leaving a detail, keeps the last details after a failed refresh, and shows task-link refusal reasons and a watch retry in place.

- Planning details retain their source and board position, preserve successful reads when another part fails, and explain unavailable task links.

- Machine sections keep actions, vault reads, and overlays on their named machine when the current selection changes, release forgotten-machine observations, and safely cancel reads after a page closes.
- Machine navigation keeps connection and setup recovery actions, organization host management and card creation reachable, restores only valid saved places, and keeps tools and unread counts tied to the machine shown.
- *Take Porelo off this machine…* removes the machine from the organization's list once it is confirmed down, as its question says; where the organization refuses, the dialog says so and the row keeps *Remove the machine…*.
- *Set up a machine* is one dialog again, not a card floating in a larger empty frame.
- A machine's row stops saying it waits for a first token once the machine took the token, without *Refresh*.
- The fetch line on a gate review, for a machine reached through this window's own ssh config, carries that config (`GIT_SSH_COMMAND='ssh -F …'`), so it runs as shown in your own shell; a forward says the branch the machine confirmed, and its pull request where one was opened.
- The token a machine declares for the organization's repository is found again when Porelo answers its address as `host:path` without a user, as it now does.
- *Give it my token…* on a machine's page offers the token this machine's vault declares for the Porelo organization's forge, named by its declaration, and has Porelo hand it to the machine; the window never reads it. *Give another…* keeps the other ways. Needs a porelo with `org host refresh`.
- A project file naming each repository's forge as `central:` is read so, and one still naming `upstream:` as before.
- *Start work* restricts its choice to the machine's repositories however it is opened (from a project, a job or the command bar), never shows a repository it no longer offers, chooses the only one left, and says when the machine could not be asked.
- *Fetch now* tells the fetch's own answer, including a project that waits for a token; the page is busy while a token is given; the folded repositories not on a machine follow the ones that are, and only for a carried project.
- Forwarding or dropping a push no longer leaves an empty pane when other repositories of the project could not be read, and a repository named like a word of git's message groups with the others refused for the same reason.
- *My forges* reads the machine's vault when it opens, so the forges the machine holds are listed before any machine page was visited.
- A refusal to put a project on a machine or take it off, asked from the project's page, stands on that page.
- A double click in a task terminal releases the button it pressed, so the next drag starts where it was pressed.
- Work started by hand opens on its new terminal without opening the one left meanwhile again, or showing it ended for a moment.
- *Start work* on an organization's machine offers only the repositories it has taken, saying under the choice why the others are not offered, such as that they name no central address; where the machine cannot be asked, it says so and offers every one.
- A carried project on a machine's page names the repositories on the machine first, and gathers the others into one line per reason with how many, opened on demand to name them, where it said the same long reason once per repository.
- A choice from a list of more than eight, such as *Start work*'s repository or the machine or person a project or a role goes to, opens a small dialog whose field narrows the list as one types, and Enter takes the only one left; a short list stays a drop-down.
- *Waiting at the gate* says that it reads, and how many repositories, while it does; the repositories it could not read stand one line per reason, opened on demand, in a box a few lines high that scrolls, so the pushes that wait and their forward stay on screen below it.
- Work started with the agent or a shell lands on its tab with a new terminal open in it, as *Open a new terminal* does, rather than saying no terminal is open where the start's own one ended with it.
- A terminal clearing the start of a line, as tmux does before an indented line, clears the cell under the cursor too, so no character of an earlier line stays before the indented text.
- A plain drag in a task's terminal goes to tmux whole, its press, each move and its release, so tmux selects past the screen's edge instead of being left a press with no release; Shift+drag still selects in the window.
- Under a terminal the window no longer offers a link that still holds a variable or a template, such as `$VERSION` or `${…}`, nor lists one only the task reaches; a login's terminal still offers its own.
- A machine's page lists its projects once, the machine's own and the organization's, each saying where it comes from, with *Managing this machine* after the list, where two lists of projects stood with the managing between them.
- A machine's page that offers no *Start work* says what stands in its way, and an organization's machine says "This window reaches its Porelo" where it said only "Connected", which read as the connection work starts through.
- On a machine's page, *Start work*, *Fetch now*, *Connect*, *Disconnect* and *Give it my token…* show from the press to the answer that they work, with a small ring and what they wait for, send nothing on a second press, and say their answer under the button pressed, where a refusal used to stand at the page's head out of sight.
- A project being put on a machine says "Putting it on <machine>…", and one taken off "Taking it off <machine>…", where it said "Adding…" and "Removing…".
- Every list section on every page folds and unfolds and stays as it was left, the repositories and members of a project page and the projects and Machine Admins of a machine's page among them.
- A machine this computer is preparing says so on the organization's page and its own page - its state, since when, its address - and offers its protocol rather than a second start; a preparation's row shows a small mark of its state, under *My machines* too.
- *Prepare a server* shows the line to run before setup in its own box, in a console font, with a copy button, and says it runs on the server under the provider's first login, not on this computer; the same for the line shown again when a run stopped on it.
- On Windows the organization pages, identity and key recovery, a forge's key check, forge tokens in the vault and certifying a task again run Porelo's command line in the WSL distribution that is this computer, through `wsl.exe`, with Windows paths named as the distribution reaches them; before, each said Porelo's command line could not be started.
- On Windows *This computer* is the WSL distribution `wsl.exe` marks as the default, reached through `wsl.exe`, instead of an entry naming a Linux socket that Windows cannot open; one added by hand before is taken as it, and with none found it says how to add one.
- The mouse wheel scrolls a task's terminal on Linux again: it reached tmux as Shift+wheel, which tmux binds to nothing.
- What *Certify it for another week* says, that it worked or why not, stays on the line rather than giving way to *Refreshed*.
- *Start work in default* offers every repository default holds, and *Start work on it* beside the first one opens the dialog with it chosen.
- A machine that refuses connections is tried again after 30 seconds, then longer up to five minutes, not every two seconds, which kept sshd refusing the address; a machine back by itself may take that long to reconnect, and *Connect* still tries at once.
- A machine's row under *Organization* offers taking Porelo off once, not twice.
- A checkout's draft is read as Core answers it: a value with no line no longer makes the whole draft unreadable, and its
  lists read as words, not JSON. Two keys to choose from are offered as a choice.
- Rail *Refresh* rereads the page shown; a machine's *Fetch now* says what it does and when the machine last answered.
- A machine's read-only project list keeps projects being taken off visible, with any reason the machine holds them.
- A project's page says it is reading its address, repositories, and members while it waits.
- List changes close onto provisional rows with persistent refusals and retry menus; other changes show progress, through the reads afterward.
- A machine row keeps its connection refusal during automatic retries; the first attempt says *Connecting…*.
- Rail entries return to their first page. *Work* in the rail shows all work; links from detail pages keep their scope.
- *Prepare a server…* opens its one dialog at the click, which says it is reading and shows a refusal in place. A
  preparation says what it is doing and that it can take minutes, keeps *Close* usable, and continues with its machine
  row after the dialog closes. A row with no step has no trailing separator.
- The start form offers *The machine chooses* so a picked agent can be cleared, and shows that choice when no agent
  was picked.
- The status line counts running and finished operations separately, keeping the failed count visible.
- *Close Porelo?* says that listed work keeps running on its machine, including the local machine, and mentions server
  preparations only when there are any.

- *Replace a lost key…* reads Core's real plan and no longer sends an option `identity revoke` does not have: both
  stopped every replacement. It no longer tells the person to have their card revoked first, which leaves nothing to
  replace.
- *Change my key* and *Add me* send the key chosen; they sent the first of the list whatever the field showed.
  *Change my key* no longer offers the key the card already has.
- An organization owner can now accept a person's new card, *Accept a new card…*, seeing the key it names first. No
  page offered `org person replace`, so no lost key could be replaced.
- *Add an organization owner* offers only people who are not one. The last owner and the last host admin are offered
  no removal that can only fail. Owners and host admins with a backup key say so.
- The organization's explanation stays closed while the window is open, and the rail's *Projects* counts what its page
  lists.

- Typing fast into a terminal no longer sends letters twice over: a key pressed before the engine took the last reset
  sent everything so far again. Dead keys, such as a German keyboard's backtick, still compose. It takes a patched copy
  of `xterm` in `packages/xterm`, whose `PATCHED.md` says what differs.

- *Refresh* in the rail reads the organization again; it only forgot what it kept, so a change made elsewhere stayed
  unseen until a write was refused. A person's or project's count reads the same everywhere, admins included.

- *Prepare a server…* keeps its fields where they are as the words about the name change, with room for a floating
  label, and its list of steps stays at its newest unless the person scrolled up. A machine the person gave no longer
  reads as being rented.

- A host nobody has connected to yet reads *Not connected yet* under *Needs you* and *Machines*, not *Not answering*.
  A refused connection says that a host makes the account only after reading the organization. Putting a project on a
  host says how the token is given: connect, then the host's page offers it.

- A person who starts work without picking an agent gets the one the machine chooses, as the command line chooses it, and
  the form says which it is and why; Claude Code is no longer filled in first. The picker puts agents found signed in
  first and marks each, and an agent that cannot say never reads as signed out. A sign-in the machine found but the vault
  lacks is offered for copying in a terminal there. Nothing starts while the machine's answer about the choice is still out.

- *Needs you* finds a message held for a person even when the machine's stream of events has ended or says nothing: the
  list is asked for when the page opens and at each refresh, and a stream that ended is listened to again.

- Giving a server back shows its membership holders before confirmation and purges only their named accounts
  before the down play. A failed purge keeps the server; a refused play reads the holders again for a new
  confirmation. With an unreadable status nothing is purged, and the ordinary give-back stays.

- A server can be given by host name or IPv6 address, as a host card allows, and not only by IPv4: *Prepare a server…*
  takes it, its pinned host key says it is that machine, the card keeps the address given, and it reads back after a
  restart. A server with no IPv4 default route still cannot be prepared, and a host vault at an IPv6 address or on
  another port is not opened from here; the interface says so.

- A project followed on a card host offers *Push the approved main…* and *Take the central state…* in its menu again;
  each runs in a terminal where the person types the secrets file's master password, and the central forge token goes
  from the file to the host's own command without passing through the interface. Without a secrets file both say to
  choose one first.

- The central push and pull send the token as the bare line the host's `porelo-host-push` reads, instead of a
  `forge-central-token <encoded>` line it took for the token. The terminal no longer shows the interface's own
  markers.

- A GitHub token named for a test instance is read for GitHub alone, never handed to another forge. A local
  command that does not read its input is still ended at its limit; a copy to a host whose ssh holds its output open
  answers, and an ended copy is asked to stop before it is killed. A key check, a token read or a registry call ended
  at its limit says so instead of staying "Checking…". A second push or pull of the same project waits for the first;
  a machine setup ended at its limit says so among its lines.

- A local command the interface runs (Porelo's command line, KeePassXC's, git) that gives no answer within five
  minutes is ended and refused with a sentence naming it and what to check, instead of leaving the window waiting
  without end; so is a copy to a host over ssh after five minutes, and a command on a machine being set up after
  twenty.

- Adding a developer, or letting one back in, is confirmed when the host's sync answers the change's access commit
  without naming the person as added, because an earlier sync of the same commit took them in already, as long as it
  neither refused nor dropped them; Retry no longer stays with "The host did not confirm this project membership
  change".

- A host card's ssh master left by an earlier run of the interface for the same login, such as before a restart, is
  ended when the host is raised again, also while its configuration file is there, instead of refusing the host with
  "an endpoint already exists and was left alone". A master configured for another login, another instance's live
  tunnel, and one a tunnel of this run holds are still left alone.

- A person change waiting for a registry read that does not end stops after 90 seconds with words and frees the
  project, keeping its receipt for Retry, instead of holding "An earlier change for this project has not ended yet"
  for good.

- A project's person change and the developers dialog read the registry again themselves where its last read failed
  or none was accepted, instead of telling the person to refresh it; the dialog shows "Reading the registry…" or
  "Reading the project from Core…" with a progress bar while it reads, and *Read again* where a read failed.

- Adding, locking or removing a project's developer while the interface reads the registry again (every minute by
  default) waits for that read to end instead of being refused with "Refresh the verified registry before changing
  this project", and the person picked in the developers dialog is no longer cleared while the read runs.

- A project's ⋮ offers *Project settings: Developers…* again, where a project admin adds, locks, lets back in and
  removes developers. It had been taken off the menus in favour of the registry's person lists, which offer no such
  change yet, so *Add a developer* was reachable nowhere.

- A project whose access file names its homeserver as a socket on its host (`unix:/run/porelo-matrix/client.sock`,
  behind the host's gate) can be joined again instead of showing "its homeserver is not an https base URL this
  interface reaches". The interface reaches such a homeserver through the host card's fixed Matrix port, never by that
  address; a relative socket path or one with `..` is still refused.

- Retry on a filed project registration whose project moved on since no longer stays refused with "The pending
  project selection differs from the verified state". While Core still names the person, with that key, as a signing
  project admin on that host, the host gets the project and access as they are now, and the registration is recorded
  at those commits; the filed commits are never sent again, so a host already running newer ones is not put back.

- A host tunnel's ssh master left running after its configuration was removed is ended when the host is raised
  again, with the endpoints it left, instead of refusing the host for good with "an endpoint already exists". A
  master whose configuration is there is still left alone.

- A host whose tunnel port is busy names the program and pid holding it, such as a tunnel started by hand, and how
  to end it, instead of only that the port is busy.

- A project under *Projects you may join* that Core refused says Core's reason, such as an access file that names
  no project repository, instead of only that its access file cannot be read.

- *Register the project* says what it does while it runs: checking the project with Core, opening the connection
  to the host, registering there. Before, it said only that a change for the project was still running.
  Each step ends with words once it takes longer than three minutes, and *Close* always works; what a step
  finishes is kept.

- *Register the project* and the other project access reads verify against the keys this computer pins, which
  Core's follow names by fingerprint: each key is taken from the registry card that holds it. Before, every read
  failed with "Core verification is incomplete or unsupported".

- *Follow a project by its address* takes the project's signers from the registry: the keys of the project
  admins it names for that project, from cards it trusts. Before, following by address was never possible.

- *Register the project* writes the first access file into an access repository that holds no commit yet,
  instead of refusing it, and takes that first commit only when it has no parent. A failed first filing can be
  retried, and adding a person before the project is registered is refused in words.

- Workspace commits and merges are pushed only when signed by the chosen key.

- A developer joins a project at one click from Core's verified admission, shown as "in project P on host X".
  The join asks Core again, follows with Core's signers through the host's tunnel, and saves only what
  the host confirmed. An access repository that cannot be read names who may grant it.

- A project change whose server was given back before it was recorded is forgotten, so Retry ends
  cleanly instead of repeating "The server was given back".

- Existing-server preparation runs the checked collection over pinned, agent-only SSH as root,
  retains callback refusal words, and saves the dialog's public settings for retry and card publication.
  Teardown excludes disk identities, checks given-host pins, and isolates concurrent pins. Malformed
  stops refuse completion, given-host login refusals stop immediately, duplicate names preserve recovery,
  and copy and command errors retain their cause.

- Host administration retains confirmed card and applied-revision state when replacing stale changes,
  preserves returned-host deletion during publication retries, and migrates older delivery records.
  Preparation reads SSH-only host results on private networks, carries optional forge job limits and
  local forward choices, shows root bootstrap instructions for a separate terminal, and refuses root stops.

- Project registration resolves receipts before checking a stale Machine. All filed access actions use
  their exact Core-authorized revision for publication and delivery; permanent refusals retain their
  reason and offer Discard, while temporary failures retain Retry.

- Project access adapts Core's person-based verification and idempotent access commands,
  initializes first registration, and rereads stale access without automatically retrying an edit.

- Project change receipts resolve uncertain filing by request ID, retain exact signed revisions,
  and offer scoped discard when superseded. Registration pins pending requests to the approved state,
  delivers again after confirmation, and permits newer access or identity revisions. Refusals name
  project admins for developers and host admins for missing host admission.

- Project access rejects stale memberships, wrong-project reads and unapproved-key unlocks,
  clears obsolete unsigned requests, and pins registration through its final authorization read.
  Registration retries retain local host recording and avoid duplicate signed changes; picker and
  command availability follows registry and mutation state, with explicit permitted contacts.

- Host administration recovers unpublished ready cards, changed selections and lost intake staging,
  delivers verified newer registry state without rolling back host access, and refuses unassigned hosts,
  purged memberships and refused-card unlocks. Confirmed returns retain visible deletion recovery,
  disable stale admin actions and permit name reuse after deletion; publication status tracks the host card.
- Host-card retries leave trial-only masters unretained, waiting drops finish old-master teardown
  before later probes start, and card registration keeps its fixed ports until explicit drop.
  Queued replacements read the current machine list when they run.

- Shared host-card trial cleanup preserves concurrent watchers, waits for teardown before reconnecting,
  and releases unused imported cards' service port reservations.
- Central transfers disable terminal echo before spawning the child and through SSH, forward only
  marked public output, and record submission only when SSH is about to start. Cancellation and
  failed local checks remain retryable once the source ends; deadlines kill the owned child and
  drain buffered output before release. Pending sources block replay and reconciliation, including
  before a late submission notification. Transfers explicitly enforce pinned,
  noninteractive SSH. Stored central review commands retain current refusals, disposed review
  controllers cannot act, programming errors in reads propagate, and overlapping backup syncs
  preserve each result without changing the open listing's state.

- Explicit central transfers read the local secrets file only in the terminal and send the agreed
  encoded stdin line. Local refusals remain retryable, while lost results and Dart errors block
  replay until reconciliation. Early SSH pipe closure preserves host refusals, CRLF echoes are
  redacted, and joined-host refreshes require an explicit target kind. Central review commands
  recheck availability and notify menus when writes settle.

- Host-card tunnels reject aliases to the local signing agent and unsafe stored config paths, keep
  ownership and port reservations separate across hosts and trials, and complete shutdown after
  socket races or failed starts. Scoped IPv6 addresses retain their literal zone, and reached hosts
  keep daemon failures separate from key availability.
- Host account commands enforce the card pin even outside its SSH alias. Teardown keeps the provider's
  pinned endpoint and requested login; forced give-back works without local SSH configuration.
- Provider terminals refuse unreachable accounts and use the desktop's OpenSSH. Rental migration keeps
  original provider tags for already-named hosts and preserves malformed legacy recovery records.

- Legacy rental migration keeps the original provider tag and recovery explanation. One-click SSH uses
  the host configuration without an empty identity, and failed teardown offers a loss-confirmed give-back.
- Supported provider sign-ins retain their terminal flow. Following can resolve verified project-admin
  signers after edits and discards stale answers; project take-off explains its pending registry support.

### Removed

- The registry's pages: its section on a forge's page with *Refresh*, *File my card*, *Choose another registry…* and
  *Create the registry…*, the admission rows on Projects and Machines, the persons on a machine's and a project's page,
  and *Take this project off the server*. The organization's, project's and host's pages do what they did; taking a
  project off its host is on the host's page.
- *Replacing another person's key in a list* (`owners.yml`, a host's or a project's access file) and the project scope of
  a backup key are gone with the commands behind them; so are `identity publish`, `identity status` and filing a card
  from *My key and card…*. A change whose answer was lost is asked again under the same ID.
- *Follow a project*, by hand and from *Needs you*, *Check it now*, and making a project from a repository on a machine:
  a project comes from the organization. *Stop following* is now *Remove this project*, offered only for a project
  registered on this machine alone; a project's forge is found by the address Porelo answers for it.

- *Register the project*, *Add a developer* and the *Project settings: Developers…* dialog with it: a project is
  added on the organization's page and a person on the project's page.
- A project's *Join*: a person who belongs to a project finds it ready on a connected host.
- Retired VPN and local trust installers, host-secret stops, copied laptop keys, project-key setup inputs,
  and the associated walks. Old rentals remain visible for confirmed give-back or setup again without
  reusing obsolete credentials. Signed-state setup and joining require the served replacement adapters.

### Added

- A change of key left pending can be gone on with after a restart, where it is listed: *Try again* asks under its own
  ID and for the key Porelo names for it, and makes no second key; *Use another key…* starts again with a key of your
  agent or a new one, under a new ID. A change that has reached the organization says so in Porelo's words and offers
  neither again. A pending change with no key named offers no *Try again*, and says so. A
  pending rotation does not hold up replacing a lost key, which replaces it.

- Replacing a lost key shows your new card, with the plan's words, and offers to copy or save it. Nothing is filed
  and nothing here accepts it: you hand it to an organization owner outside Porelo. An answer with no card says so.

- *Store its token in this machine's vault…* on a forge's row or page, under *Forges*, opens a terminal on the selected
  machine for `porelo vault put git.token.<host>`, for opening a project and for Git transfers. The token is typed in
  that terminal and never in a form of the interface. It says why when the machine does not answer, or when the
  forge's address is no plain host name.

- *Replace a lost key…* stands in your own row under *People* on the Organization page, shows what it does first, and
  can use your backup key for a place you hold; *Make a backup key…* stands in your row under *Organization owners* and
  on a host's page for its admin. Each runs in a terminal, so its passphrase stays there.

- *Organization* in the rail: what the organization is and where it is kept, its people, projects, hosts and owners,
  each with the actions of the person's own roles in its row, and *Add me*, *Add a project* and *Add a host*.
- Saved settings from before the organization model are put aside as `frontend.json.dropped`, not migrated, and the
  interface says so once, in one sentence. Secrets in the system store and a person's secrets file are not touched.
- The organization's page says when what it shows is the last state read, and what the store warns of. *Add me* asks
  for the login, name and email of the card.
- A computer reading no organization offers *Choose the organization…*, *Create the organization…*, which fills an empty
  repository the person made on their forge, and *Make my card…*, which creating one needs. A host's service can be
  taken off its card by emptying its port.
- A connected host admin reads on the host's page what the host itself says: how far each project has come, why one
  is held, and "locked, account deleted on <day>", with no action beside it. When something waits for their central
  token, *Give it the token…* feeds it in a terminal; putting a project on asks the host to fetch at once.
- *Machines*, where this computer reads an organization, lists the hosts carrying one's projects with one *Connect* each;
  a host's page holds the projects it carries, its host admins, *Refresh* and one's own connection.
- *Projects* says when a person is locked in a project, and lists a project of this computer alone beside the
  organization's.
- *Projects*, where this computer reads an organization, lists a person's own projects with the host carrying each; a
  project's page holds its repositories and members, changed by its project admins and read by its members, and opens
  the project on its host, where work starts.

- Project registration and person management use verified registry admission, project-scoped card eligibility,
  and active admin signers. Signed access changes retain durable publication and delivery receipts across
  restarts; add, remove, lock and let-back-in require exact host revision and membership confirmation.
  The registry picker and project commands use injectable Core and host adapters until their contracts are served.
- Host administration has registry-backed app operations for trusted-person admission, host-scoped locking,
  readmission and separately confirmed account deletion. Checked SSH completion cards and confirmed provider
  returns retain publication recovery independently; registry delivery resumes the same signed revision and
  requires the intended host, revision and membership result before confirming it. Signing and host intake
  remain injectable until their implementations are available.
- App-level central push, pull, pull-request and review actions capture the person's selection,
  refuse duplicate or uncertain writes, and use explicit vault and forge adapter boundaries.
  Host-card commands use the owned SSH connection and redact echoed stdin credentials. Joined-host
  refresh and backup checks require a host-only forge adapter instead of reaching central upstream.

- The organisation's registry repository is kept as one credential-free address and fetched into a private
  checkout with the person's own Git access, never prompting. Core's registry read of it is the one source
  for persons, hosts, admins and projects; a refused fetch, an incomplete answer or a refused commit keeps
  the last accepted state and says why, and a refused card can never be picked for a change.
- Verified host cards can publish pinned public-only SSH configurations and share one supervised
  connection for fixed forge, Git-over-HTTP, Matrix and daemon forwards. Port conflicts are refused,
  agent forwarding is disabled, and host transport state is separate from daemon and vault readiness.

- Project admins can bring from a machine with no local host record using their copied host keys and
  assigned VPN address. The bring fetches the CA through pinned own-account SSH over the VPN, refuses
  a fingerprint mismatch before installing trust or recording the host, and shares VPN setup with joins.
  Bring and join share the lasting forge password terminal: after checking the VPN and CA, the person's
  pinned SSH connection feeds the password only on standard input to the host's own-account helper,
  before the bring publishes access or uploads setup. A refused password step stops the bring.

- Project admins can maintain developers and their public laptop keys in project settings. Changes preserve
  access-file comments, use the person's configured Git signing and credentials, and apply through the admin's
  host sync. GitHub access uses read-only collaborator invitations and revocation; host and forge answers stay
  separate, with partial failures available to retry.

- Developers can copy this laptop's host-specific public keys and join a project from its verified signed access
  file. The join uses its listed VPN address, checks the access file's CA SHA-256 before local setup, pins the host's
  SSH key, and uploads both bundles for an own-account join and secrets stop. Private keys stay in the system
  secret store, and a confirmed join retains the access commit for the next verification.

- Project admins can bring a followed project onto a prepared server through their own pinned SSH account,
  without renting or host-admin setup. Private access settings preserve YAML comments, use the person's configured
  Git signing and credentials, and are pushed before both bundles are uploaded. Migration URLs are checked before
  upload. Matrix access uses the fixed room alias, the host-local admission token path, and this host's retained
  CA checked against its fingerprint, with no other Matrix keys. The bring makes the room and shows its final
  output. Public host values, an own account, and an identity file suffice without a watched machine; the
  supplied SSH key is pinned for this host before private access changes. Interrupted brings preserve clean
  checkouts, avoid repeated access pushes, and show existing-folder refusals. Host admins can take the project
  off through its recorded host, preserving local and remote refusals and clearing the association only after
  confirmation, with following left for a separate decision.

- The host's stop is fed by act: the host admin's root stop takes only the VPN key and the forge's certificate,
  a bring's or a join's runs in the person's own account with no `sudo`, and their setup files go into the
  person's own home on the host, theirs alone.

- The secrets file keeps a host's entries under `hosts/<host>/` and a project's under `projects/<project>/`;
  entries kept by an earlier version move there once, in the person's own terminal, and none is lost.

- Host VPNs keep separate network numbers, interfaces, names, and CA files, so several can stay up together.
  A network already held by another host is refused before sudo, naming both hosts. Older setup records migrate
  to host keys and retain support for taking down the original WireGuard interface.

- Startup roles select which commands the interface offers. Ordinary work is always available;
  `--roles host-admin,project-admin` also shows server administration and project placement.
  Unknown roles are refused before the window opens.

### Fixed

- Registry changes refuse missing selections and unpublished checkout work, publish only Core's filed
  commit, and retain publication failures. Registry reads apply Core's latest verified state beside a
  refused commit, preserve first-commit and malformed-card refusals, and name owners for hosts without
  admins. Git disables credential prompts and incomplete initial checkouts can be retried.
- Covered item pages and section-only navigation no longer supply registry actions. Finder choices
  open and select the captured item through its row navigation, preserve watched SSH settings, and
  wait for its page before acting. Registry identity compares machine name and socket path.
- Registry refusals use only contacts verified for the operation. The finder exposes registry actions
  on unwatched machines and unfollowed projects, including pages opened without an explicit admission.
  Choosing a registry action opens its captured item's page and runs it there with its own permissions.
- Project shortcuts and finder commands refuse stale item selections. Default project pages retain
  repository management, and prepared machines without registry state retain project placement commands.
  Forge repository menus retain repository removal and trusted-machine tools; renaming keeps the chosen
  authentication method.
- Registry menus hide operations outside the person's role and name the responsible contacts with their
  supplied email. Saved jobs have a collapsible filter and working finder menus; project rows show tunnel state.

- Project joins supply an explicit local Ansible inventory and disable its localhost warning while retaining
  real warnings and failures in the join log.
- Servers rented without a project can be given back using their existing ownership tag. A refused
  give-back preserves the local VPN and reports the continuing rental; unfinished VPN cleanup stays pending.
- VPN setup makes Firefox's policy folders readable under a private umask, repairs existing restricted
  folders, and refuses linked folders or folders another account owns before copying the CA. Existing
  CA copies must be regular files owned by root and readable by Firefox; only owned regular CA files
  enter the policy. VPN take-down preserves unmanaged policies without preparing Firefox folders.
- Pasted public host keys accept extra blanks and refusals identify the malformed field and its required form.
- Bring and join retries replace only their own completed setup uploads and preserve foreign files and links;
  foreign-upload cleanup checks the staging directory and its ancestors before removing it.
- New lasting forge passwords are confirmed, checked for the minimum length, and saved only after the host accepts
  them. A refused kept password can be replaced without losing the old entry before acceptance.
- Server setup installs the checked host collection for every account with root-only writes, checks its parent
  is a plain root-owned directory, and makes that parent readable by all. Own-account bring and join refuse
  every listed collection outside the host's installation, regardless of listing order.

- Own-account setup keeps each project's `machine.yml`, `project.bundle`, and `access.bundle` in its own
  `porelo-host/setup/<project>/` in the account's data folder. Its machine file names `access.bundle` relatively
  and the project bundle by its absolute path; root and combined setup retain their existing layout.
- Own-account setup refuses root logins, linked home directories, existing setup files, and upload data for the
  wrong act; failed uploads preserve setup material they did not create.
- Own-account uploads validate the home itself, copy to its absolute path, and reserve, recheck, install, and
  verify setup in one SSH session. Scripts run through the account's contracted Bash login shell, whose startup
  files and environment are trusted. The home reply refuses startup output before
  reservation; ambiguous later replies remove only empty reservations and preserve populated directories.
  An absent placement directory needs no cleanup.
- Own-account paths share one project-name check, and publishing refuses an invalid name before touching a bundle.
  Upload staging uses a reserved leading-hyphen name, so it cannot collide with any project's setup directory.
  Bundle homes and URLs must already be normalized absolute paths with a nonempty home prefix.
- Own-account stops require the complete pinned SSH option sequence built by the interface, with no duplicates.
- The secrets step shows readiness only while its opened file, server name, and vault-entry files still match and
  no key remains on the old drive. Legacy links and directories reach the migration refusal before any write.
  Late terminal answers cannot change settings or keys for edited inputs; selecting text preserves a refusal.
  Input identity uses names and paths without probing files; a file changed during opening produces a visible refusal.
- Project removal requires `shared/forge-central-token` before starting SSH. A missing entry refuses locally
  and names how to add it in KeePassXC; take-off has no verified repository list to exempt repository-less projects.
- Recovery actions in Machines use the desktop terminal opener for local VPN cleanup.
- Server-only preparation keeps project secrets and this account's homeserver private; migrated CAs refuse
  signing outside their permitted network, and forge password terminals hide input before starting SSH.
- Stored project-mode server identities remain usable, conflicting migrations preserve their records,
  and migrated machine references keep their host actions available.
- VPN cleanup removes persistent names and trust after reboot, recreated hosts replace their old addresses,
  and Firefox's managed trust policy follows the installed host certificates.
- Each host keeps its own forge and homeserver CA, constrained to its name and VPN network. Certificate setup
  accepts exactly two verified requests and sends both service certificates followed by that host's CA.
- A task's terminal says above its screen when the task was started, and its tile says *started HH:MM*, so what its
  agent still shows from before a stop and a start is not read as its state now.
- Shift+drag selects text in a task's terminal while tmux or the agent in it takes the mouse, without reaching the
  program, and the hint below the terminal says so; what a program copies itself (OSC 52, as tmux's copy mode sends
  it) reaches this computer's clipboard, while a request to read the clipboard is never answered.
- A link a task's program prints to an address only its container reaches (`host.containers.internal`, a loopback
  address, a name without a dot) is shown below its terminal as only reachable inside the task, not as a button to
  the browser.
- Install Tresorit for a work user shows its phase and how far it is: fetching and sending the installer in MB of
  their total, then checking its signature and installing it, and a failure names its phase; Running Porelo's setup
  script as root shows the script's last line.
- While a ready server's setup runs again, its row in Machines says Setting up again (or Needs you at a stop) with the
  protocol's step and time left and opens the protocol; taking it down, forgetting it, putting the project on a server
  and running the setup again are unavailable meanwhile, each saying why.
- Take this server down is a tile among the other tiles of a server's page, its label and mark in red, instead of a
  small text button below them; its confirmation is as before.
- The dialog Your homeserver for this server gives the one command that adds this computer's hosts line, in a box
  with a copy button, to run as it is in a terminal of your own; it adds the line only where it is missing.
- A refused passphrase in the vault's unlock terminal, or a mistyped master password of the secrets file, is asked
  again in the same terminal, three attempts at most, instead of ending it at the first refusal.
- Unlocking a rented server's vault asks the master password of the secrets file once, in its terminal, and feeds
  the vault passphrase its setup kept there to the server's `porelo vault unlock --passphrase-stdin`; nobody copies it
  by hand. A rented server's vault is no longer offered to be made here: its setup makes it, from the file.
- Putting a project on a server checks first that KeePassXC's command line is installed: without it the
  command says so with the line that installs it, the secrets step shows that line once with an error
  mark and a copy button, and its button says Make it now (try again) and looks again on each press.
- A server's row in Machines no longer lists why a greyed button cannot be pressed below its buttons; the button's
  tooltip says it.
- A server's protocol shows its current attempt, and earlier attempts are chosen in a list above it, one at a time,
  instead of stacked below a protocol that scrolls them away while it grows.
- Renting a server is expected to take 15 minutes, as Elastic Metal does, so its protocol no longer says it takes
  longer than usual after 5.
- Bringing a server's VPN up is refused before sudo, with how to start the interface outside it, where the
  interface runs confined by a snap (as under `flutter run` of the flutter snap), in which wg-quick cannot run. Where
  the VPN step fails, its line, with wg-quick's own last words, is kept in the server's protocol.
- A guided walk's panel, detached into its own window, starts that window once at a time, ends it with
  the interface, and stays beside the interface saying so when the window does not answer; its field
  to write in keeps four lines however long a step is (guided_walk 0.3.0).
- Start an agent for each repository no longer offers an agent a second time in the first seconds after
  its start, while the machine lists the task before it says its agent.
- Giving a server back takes down this computer's VPN on Linux before showing Done. Cancelling keeps
  a Take the VPN down action in Needs you until the tunnel is gone. Other platforms finish without
  opening a local VPN terminal or keeping a VPN cleanup action.
- Interrupted server setups keep their recorded steps and messages across restarts until the server
  is given back, with Go on for an interruption and Try again for a failed attempt.

- Each server offers one VPN action that follows the local tunnel state, and skips the sudo
  password prompt when the requested state already holds.
- Interrupted server setups appear in Needs you with Go on. Closing stops setup still renting,
  keeps later setup running, and finds it again when the interface reopens.
- Host setup and teardown hold one project lock across processes, refuse overlapping commands,
  and show lock contention separately from a host login stop.
- Navigation counts match their lists, including servers still being prepared, every open Needs you
  row, and work matching the selected filters.
- Bringing up the VPN leaves its tunnel unmanaged by NetworkManager, preventing desktop
  connection failure notifications when the tunnel is renewed or taken down.
- Scaleway secret keys are checked before being stored and before server setup continues;
  keys can also be imported from a private file, and refused keys leave the earlier key intact.
  Unexpected replies are refused without accepting the key or crashing server setup.
- Server preparations survive restarting the interface with recovery actions in Machines and a
  warning that closing keeps the server rented and billed.
- A server's menu offers Save the VPN connection… after closing its setup dialog or restarting
  the app, using public tunnel settings kept when the host becomes Ready. Saving again keeps the
  newly chosen path and preserves the setup collection's verification digest.
- On Windows, Save the VPN connection… accepts a plain absolute Windows path instead of refusing
  every one.
- Each Choose… in the server setup dialog starts in the folder of the file or folder chosen before it.

### Changed

- *Open it on <host>* moves from a project's page to its row under *Projects*, the one place that names a project's host.
- *Remove this project* is offered only for a project on this computer. Removing a member or revoking a card says when
  it takes effect on a host: within five minutes, or at once on its *Refresh*.

- *Push the approved main…* and *Take the central state…* are for a person whom `porelo project list` gives a role in
  the project and does not list as locked, read again when either is chosen. While the role cannot be read both stay
  listed as unavailable with the reason.

- Machines, Projects, Forges, repository lists, saved jobs, and work use rows with visible menus. Item pages
  have independent collapsible filters, retain registry/host/project identity, and show confirmed host state
  separately from pending registry changes. Each machine always has Without a project. Central forges default
  to SSH identity, and choosing a token explicitly opens its terminal boundary.

- Taking a project off a prepared server opens the admin's terminal and pipes the central forge token from the
  secrets file to the host to protect the repositories' central copies; a missing entry refuses before SSH starts.

- The Linux packages require KeePassXC (`keepassxc-minimal` or `keepassxc`) and `wireguard-tools`, the programs the
  interface runs for a person's secrets file and for a server's VPN.

- Server setup checks the project's verified commit against the public key for signing commits on
  The drive, before anything is rented: a key that did not sign it is refused with both keys'
  fingerprints, and named as the server login key when the two key fields look swapped. The field
  opens on a key in the SSH folder that the project's machine already trusts, and checks a key as soon as
  it is chosen or typed, with a check mark or an error icon beside it.
- Server setup fills in your public ssh key from the private key's own `.pub` whenever there is
  one, also over a key kept from an earlier run, and refuses a public key of another pair at once.
- Server setup installs porelo-host's collection 0.5.12, which brings up the host's forge and gives
  each agent its own forge account and token, the person a forge login of their own, and each
  account's gate its token, with every repository's main protected and merged by fast-forward
  only. The forge's runner takes four jobs at once and keeps a cache between runs. The host
  mounts no drive, takes its secrets at the stop on standard input from the secrets file, reads
  its setup files from `/etc/porelo-host/setup/`, and gets its forge's certificate from the
  person's lasting CA. During the move the host's tasks reach the project's room on this computer, and
  the person's forge login is made on every host with a forge.
  The host follows the organization: who may do what comes from there.
- Creating an organization on a forge whose token is not where `credentials.yml` says now names the
  entry, its address and where the token should come from, says what to do, and offers to take it
  from the vault instead. A forge on its own port says which address needs a token of its own.
- A redirect from Scaleway is named as one and is not followed.
- Server setup shows one protocol with earlier attempts grouped below it, copies its public text
  in one click, and keeps the view and buttons still while you read earlier entries.
- Needs you keeps explanations and further actions in expandable rows; Recently resolved stays
  expandable without a header action. Problem notices use neutral backgrounds, reserving red
  backgrounds for review warnings and decisions that can discard work.
- Server actions appear in a spaced tile grid with distinct icons; Take this server down stands
  alone at the bottom as a red button.
- Projects, Forges, Machines, and Needs you use compact rows with separate buttons for the main
  action and expanding details; clicking a row opens its detail view.

- Server setup finishes with a checked local VPN, removes its temporary private key file, and
  offers recovery when the tunnel stops answering.
- Host setup stops open a small dialog and use the retrying host script, keep cancelled or
  failed stops, and show the terminal command only under Details.
- Unattended starts show the agent's state, last output and silence, with Leave and a reviewed restart when messages wait.
- A locked-vault row names whose vault it is and the projects it holds up with their last use,
  offers unlocking first and stopping to follow each project through its preview.
- A project's room is joined from its page, with lower-case chat names and numbered steps for
  Element, which opens without credentials in its address.
- Project actions, including Its work, are equal raised tiles with a teal icon and title; their
  explanation or the reason they are unavailable shows in a tooltip.
- Server setup writes the followed project’s verified bundle into the tresor folder and fills the
  public SSH key from the chosen private key.
- Server setup shows each step once in words with its local start time, duration, and overdue
  progress while estimating the steps still ahead.
- Giving a server back always asks for confirmation, names what is lost and kept, and uses a destructive button.
- Forge tokens are entered only in terminal prompts, kept on this computer for the forge API and
  in each machine's vault for git over https; setting up and clearing repositories no longer manages deploy keys.
- Server setup continues after its wizard closes, appears in Machines with progress and time
  estimates, asks under Needs you at a stop, and adds the ready server automatically on success.

- Server setup includes its verified collection, so release builds no longer ask for a setup file;
  debug builds can try a test collection with an explicit SHA-256.
- Needs you names each row’s machine and offers recovery there; resolved rows and read messages
  stay readable with disabled actions for a configurable time, one hour by default.

- Putting a project on a server asks one step at a time, keeps answers when going back, and
  reviews them before renting; missing files and a public ssh key chosen as the private one are
  refused in their own step. The local folder appears beside its picker and suggests an editable
  tresor name. Preparation refusals name the input and step, and corrected answers can be retried.
  The host walk uses invented SSH keys kept inside its walk folder.

### Added

- Prepare a server under Machines without creating a project or project account. Its public connection values
  can be copied for project admins; its menu registers and removes projects and admits, locks, or purges admins
  using checked public keys and the rental SSH identity.

- A ready rented server offers Run its setup again in its menu in Machines: `porelo-host up` runs with the arguments
  and files of its setup, as a new attempt in its protocol, a stop in it is completed from Needs you, and the server
  stays in Machines meanwhile. While a setup of the project runs or waits, the action says why it is unavailable.
- `porelo-host find --project NAME --scaleway-project ID [--zone Z]` names the server rented for a project now, as
  one JSON line with its id, address and whether it is ready, or exits 69 when none is; it rents, reaches and writes
  nothing.
- A server that asks for its token for this computer's homeserver gets it at its stop: this computer lets the
  server into the project's conversation and sends the token on standard input, without a master password.
- A server set up from here runs a forge of its own: its first inventory says `porelo_host_forge: true`.
- During the move, once a server's VPN is up, this computer's own homeserver is published on its VPN address
  under `matrix.porelo.internal`, so the server's tasks reach the project's room here; it is closed again when the
  server is given back. Where `/etc/hosts` lacks `127.0.0.1 matrix.porelo.internal`, the line is shown to be added
  once by hand.
- A server's stop takes what it needs from the person's `secrets.kdbx`: its vault passphrase, its VPN key and the
  files of its vault entries go to the server on standard input after one master password, typed in the terminal on
  this computer. A setup that stops for the central forge's token, or a vault entry, waits under Needs you, gives it
  from the file and goes on. Files chosen for vault entries are kept in the secrets file instead of on the drive,
  and only the entries a server's setup names are sent to it.
- A server's forge gets its certificate at the stop: signed on this computer by one lasting CA, made once into the
  secrets file, whose key never leaves it. Bringing the VPN up then trusts that CA on this computer (the system
  store and Firefox's policy) and names the forge in `/etc/hosts`, each once; taking it down takes the name out.
  From 90 days before that CA ends, the VPN's start and the stop say so, and how the next stop makes a new one.
- The machine wizard has an optional step *Your own drive*: Tresorit's client installed in the work user's own
  account, from an installer the machine checks against its own signature under a pinned CA before any of it runs,
  signed in by Tresorit's own login in a terminal, and one tresor synced into that user's home.
- A server's setup mounts no drive: *Put this project on a server…* asks for no Tresorit folder or tresor, and
  `porelo-host up` takes no `--tresor`. A host key a drive folder chosen before still holds moves into the
  secrets file.
- On Windows, *Put this project on a server…* is unavailable with its reason until the interface brings
  KeePassXC there: a server's keys are kept in the secrets file, which it opens only on Linux so far.
- A server's `machine.yml` and the project's bundle are written into the interface's own configuration folder and
  uploaded over the server's own ssh into a place only root writes, checked there by their digests; the drive gets
  neither.

- Putting a project on a server keeps the server's VPN key and vault passphrase in the person's own `secrets.kdbx`,
  which KeePassXC opens too: a step names the file or where a new one is made, and setup opens it in a terminal on
  this computer with one master password. The key no longer lies on the drive; a key already there moves into the
  file. Nothing of the file passes through the interface but the key's public half.

- A project's menu offers Start an agent for each repository: a wizard starts, one after another, an
  attended task for each repository whose `project.yml` names an agent, with that agent and the name
  the machine gives it. Repositories can be left out, an agent with nothing to sign in with is signed
  in first, a running agent is not started twice, a stopped one continues, and a refused start keeps
  its answer while the others start. It stays unavailable against a Porelo that does not say which
  agent a repository names.

- Removing a member from a project's Messages dialog confirms the account, refreshes the room's
  members, and offers Join again after removing this computer's account. Kept accounts and
  transport refusals show the daemon's explanation.

- Project rooms list their accounts and remember your name per machine and project, with New password when
  you are already a member; each account shows why Remove is unavailable.

- Servers offer VPN up and down in a terminal on this computer, with an optional cleanup of the
  saved private-key file after connecting, and a route into the project's room with Matrix client guidance.

- Servers can be taken down from Machines using the last saved setup answers. Removing a server
  from the list warns that it keeps running and billing, and host setup restores its last answers.

- Project pages offer grouped action tiles and a visible Start work here button on each repository;
  starting from a row keeps that repository selected until Change chooses another.

- Task starts show the machine's steps, what they wait on, and the cause when a dependency fails,
  with the detailed output kept below. Older machines keep their existing start feedback.

- Host setup can keep a local Tresorit folder per project and prepare the signed machine file,
  optional vault key files and the host's WireGuard key there without replacing differing files.
  The person's separate WireGuard key stays in the system secret store; only its public half goes
  to setup, resume and teardown. Completed setup shows tunnel settings and offers an explicit
  wg-quick export, restricted to the user on Linux and Windows, to bring up with the person's own WireGuard.

- A completed host setup offers to add `<project> server` to the machines, replacing a host of
  that name. A completed teardown names the host it actually gave back and removes only machines
  matching its account and address; finding no host keeps the list and says so. Tasks use the
  ordinary machine start flow, including agent sign-in in a terminal and its browser reply forward.
  Setup requires a collection that separates bring-up from task start. The final `up` done line
  names the host's address, account and daemon socket, using the account's UID read over SSH.

- Windows reaches an existing machine through Windows OpenSSH with the keys in its agent,
  relaying the daemon’s bytes and showing ssh’s refusal without waiting for a passphrase.

- `porelo-host`, beside the interface in the deb, the rpm, the ZIP and the MSIX: `porelo-host up` and
  `down` put a project on a server and take it off again, with the playbook running on the host
  itself, so this computer needs only ssh. It rents from Scaleway Elastic Metal, or works on a
  machine named by `--given`, and reports the collection's stops. Drive and vault answers reach
  a second `up` on its standard input; unsupported needs are shown without an automatic retry. A `down` whose copy fails keeps the host and
  says so, until `down --give-back-anyway`. `porelo-host key set scaleway` keeps the
  provider's key in the system's own secret store, never in a file. Each step is one JSON line.
  In the interface, a project's *Put this project on a server…* runs it, shows each step as it
  comes and asks at its drive and vault stop, sending the answers to its standard input only.
- A start whose repository's upstream cannot be read says why before anything is made: a key the
  host refused, a repository not found, a host that did not answer, or another cause, with the
  command that fixes it to copy. A refused key can be fixed in a terminal on the machine, and every
  cause can be asked about again. A start refused for it says the same, from the dialog and from a
  task started again, and a start that goes on from the mirror keeps Porelo's warning in its words.
- A machine whose ssh login is refused when it is connected again says why in words on the machines
  page, as when it is added, with the key ssh would log in with where the SSH config names one.
- A finished unattended run's tile ends with a line under its output: finished or stopped before its
  end, and whether its work waits at the gate to be reviewed, or what to read instead.
- `porelo-host` and `porelo-host.exe` on their own, without the interface, in the generic repository
  `porelo-dist-host` under their channel and version, with a `SHA256SUMS` beside them.

### Fixed

- Paths starting with `~` in host setup are understood, each path has a file picker, and the
  VPN file's button and hint explain plainly how to save and use the connection.

- Session, unlock and vault terminals accept Ctrl+Shift+V and Shift+Insert for paste, show the
  paste shortcut, and copy selected text as shown.

- Windows host setup refuses invalid key file names without URI errors and uses native paths
  consistently when preparing files and naming conflicts.

- Stops read survivor counts and lists of helper names, show known survivors by name, and say
  "not reported" for missing or invalid survivor data instead of implying a clean stop.

- Host files are written in private staging directories, protected before publication, and
  published without replacing an existing destination, including one introduced during writing.
  Setup refuses linked Tresorit folders, validates complete Ed25519 or RSA signing keys and
  Windows file names, escapes YAML controls, and shows secret-store transport failures as refusals.

- Host SSH uses one pinned trust policy before every other option, disabling system keys,
  key-producing commands and DNS key verification while retaining ProxyJump from SSH config.
  Managed host machines retain their private key path and use that policy for daemon tunnels,
  temporary connection and vault trials, terminals, login reply forwards and commands. Trust-file
  paths are quoted so a profile path with spaces stays one file. Only `porelo-host` can pin their
  host key; the interface refuses to trust another. Every terminal requires a machine.

- Host setup requires the project's tresor and passes it to up and its resume so the drive is
  synced. Host fields stay read-only after up starts, and resume and down keep its host arguments.
  Unknown needs, including an `agent-login:` need, are shown verbatim with no sign-in
  or resume action; an empty stop says the host has not said what it needs.

- Windows uses one OpenSSH installation for every command, refuses option-like hosts, and
  distinguishes SSH login failures from a missing daemon when trying a machine.

- On a GitHub of its own, every call is asked under its `/api/v3`, not at the instance's root.
- A forge that answers with a page that is not its API, with JSON of another shape, or breaks off its
  TLS or HTTP exchange is said as refusing, and a request it does not answer within thirty seconds
  ends; neither leaves a form busy any more.
- A hand-in whose file cannot be read ends as failed, saying why, instead of staying busy.
- A homeserver forward raised after the window closed its forwards is taken down, and one asked for
  twice at once is raised once.
- Setting Porelo up in WSL refuses a key file that holds another key besides Porelo's.
- On Windows, a WSL distribution no longer counts as this computer, so a silent one is shown under
  *Needs you*, and *Start Porelo* is not offered for it.
- On Windows, a forge workspace looks for the keys made for machines in the person's profile.
- `porelo/frontend.json` keeps the keys this version does not know when it is written, and a second
  machine of a name already read is dropped.
- A default repository's source and remote, a refresh's moved branches and a waiting push's bundle
  read past a value of another type, rather than failing the whole answer.
- Two questions for work a machine does not list yet no longer break the Work page.
- Asking whether a WSL distribution's daemon answers closes its connection whatever came of it, and a
  tile's console asks a session's screen one look at a time.
- The integration leg stops on a lease that names no user or socket, before it asks a machine.
- The words dialog, *Forget* and *Which branch* scroll on a short window, and the forge form shown
  alone offers no *Cancel* that did nothing.
- The guided walk's note on the terminal is in US English.

### Changed

- The host's stop opens a terminal on the host for the Tresorit login and vault passphrase;
  the dialog takes no secret.

- The MSIX is signed from the certificate store: its key is never a file in the build and its
  password never on a command line.
- Every colour of Porelo's look is named in the tokens, as every size is.
- The code is in the shared style: `dart format` at 120 columns, the YAML and the feature files at
  four spaces, and the scripts as `shfmt` writes them, each checked in the build; the build stands
  on `porelo-parent` `0.2.1` and its tools `0.5.1`, and no checkout keeps the job's token.

## [0.5.0] - 2026-10-17

### Added

- The Windows interface also comes as an MSIX, signed by `CN=porelo.ai` with a certificate of the
  project's own, beside the ZIP in Artifactory with the certificate's public half, in the same
  `SHA256SUMS` and under the same attestation. Installed, it writes the same `%APPDATA%\porelo\frontend.json`
  as the ZIP, which the IntelliJ plugin reads.
- `porelo_frontend --diagnose-terminal` shows and logs every key and wheel event the terminal widget
  receives, the bytes it would send, and what of them arrives in a WSL distribution, through pipes
  as the relay and through a pseudoconsole as the attach: for finding out what a system delivers.
- Every build of `main` makes the Windows interface as a ZIP, beside the Linux packages, with a
  `SHA256SUMS` and a build provenance attestation, and publishes all three into Artifactory, so a
  person can check both before unpacking it.
  The Build's jobs are named *Linux* and *Windows*; the trial on a `windows/` branch publishes
  nothing.
- A machine added is asked what it needs to run work the first time it is the one shown and
  answers, and what it says is shown at once: each check in the daemon's own words, green when it is fine, yellow when it is
  degraded or could not be established, red when it is missing, as `porelo doctor` colours them.
- On Windows, a WSL distribution is a machine. The interface lists the distributions with
  `wsl.exe`, never starting a stopped one, and reaches the chosen one's daemon through
  `wsl.exe -d <distribution> --exec porelo daemon connect`, the same Varlink over the relay's standard
  input and output, with no ssh and no open port. Terminals and commands run there through
  `wsl.exe --exec`. Before connecting it checks the Windows version, WSL, WSL2, a system Porelo
  supports, systemd, Porelo and its daemon, and says in words where it stops. Where Porelo is missing
  it offers to set it up: every line shown first, run as root only after a yes, the repository's key
  checked against the fingerprint the interface carries, the agents chosen with none chosen in
  advance, and each line kept in the operations record. Turning systemd on, which restarts the
  distribution, is asked on its own, and the answer is no until changed.
- A Windows build of the interface, the first part of reaching a Porelo in WSL from Windows. Its
  files are under the user's profile: the machine list at `%APPDATA%\porelo\frontend.json`, where the
  IntelliJ plugin reads it, and what it records under `%LOCALAPPDATA%`. A file is kept to its owner
  with `icacls` and opened as a double click opens it, with no shell reading its name. A task's
  terminal runs in a Windows pseudoconsole, and a second launch joins the first over a loopback
  port. Notifications are not raised on Windows yet, and that is said once. A workflow of its own
  builds and tests it on GitHub's Windows runner and publishes nothing.
- The machine list keeps a WSL distribution, `{"name", "kind": "wsl", "distribution"}`, and any
  entry of a kind this version does not know, every field of it, instead of dropping it on the next
  save. On Linux such a machine is shown as not reachable, with the reason in words. The connection
  to a daemon speaks over any byte stream, the first step to reaching a Porelo in WSL from Windows.

### Changed

- The project took its present name, and nothing kept under the former one is read: the interface is installed afresh.
  It installs as `porelo-frontend`, starts as `porelo_frontend`, speaks `org.fuin.porelo.Tasks1` to
  `porelod` over `$XDG_RUNTIME_DIR/porelo/`, keeps its settings in
  `$XDG_CONFIG_HOME/porelo/frontend.json` (`%APPDATA%\porelo\` on Windows) and comes from
  `porelo-dist-deb`, `porelo-dist-rpm` and `porelo-dist-windows`.
- The interface looks like Porelo's website: its near-black ground, cyan, magenta, lime and amber,
  its rounded surfaces with a fine border and pill-shaped buttons in the dark mode, and the same hues
  darkened on a pale ground in the light one, which stays beside it. Every text and mark reads at
  WCAG AA in both. The terminals take the same colours, and the website's logo is the application's
  icon on Linux and Windows.
- The interface is called *Porelo Control Tower* wherever a person reads its name: the window's
  title on Linux and Windows, the menu entry, the about dialog and the Windows package. Its binary
  and package keep the name `porelo-frontend`.
- The packages are proven to install on the systems Porelo supports, Ubuntu 26.04, Debian 13,
  Fedora 43 and Fedora 44, each image pinned by its digest, instead of Debian 12 and Fedora 40.
  The `.rpm` declares the oldest C library it needs, as the `.deb` does, and a build that would need
  more than Debian 13's glibc 2.41 is refused before anything is published, by Porelo's shared
  `check-linkage`.
- Every workflow run is titled with its workflow, its branch or tag and its commit's subject; the
  shared rules' workflow is called "Shared rules check" and the Artifactory probe "Artifactory probe
  test".
- The build takes `porelo-parent` `0.2.0` and with it the build tools' `0.5.0`, and its
  Maven build and tests read the project's `settings.xml` like every other Maven call, so the
  snapshots come from Central's snapshot repository.

### Fixed

- Setting Porelo up in a WSL distribution checks the package key against `porelo-packages`'
  fingerprint `BF27A2FA637F505CAFBE431768D19D175D904415`, the key the repository serves, and no
  longer stops before writing anything.
- Bringing work up to its source no longer says that an online task fetches its upstream itself:
  an online task has a gate now and is brought up like any other. A task with no gate at all, one
  started without a gate or an offline one, is told as that.
- A push forwarded onto a branch that already holds earlier work is refused in words: the branch,
  the commit it holds, that nothing was forwarded, and another branch to forward onto. A start
  refused because the task's earlier work still waits at the gate names that work, in words rather
  than as the machine's error.

## [0.4.1] - 2026-10-08

### Added

- A work tile says what the build of the work's last push did, as the machine reads it from the
  forge, in a line of its own under its head: "Build passed", "Build failed" or "Build running",
  each with a mark of its own shape and colour, and the commit, the jobs and the age under it. The
  work's detail lists every job and which of them left a log in the task.
- A file on this computer can be handed to running work from a tile's menu, sent in parts that go
  on where the machine stopped after a lost connection, and taken back; the work's detail lists
  what it holds, who handed each file in, and the record of every hand-in.
- A followed project's page has "Check it now": the machine fetches the project's repository and
  asks each repository's upstream at once, rather than at its next round, and the page says
  "checking…" and then what came back.
- A repository worked on without a project says where its work comes from and goes: from the
  checkout it was started in and back into it as `<former name>/<task>`, its remote left to the person, or
  from its remote and back there.
- A work's menu has "Bring it up to its source": what moved in its checkout or remote reaches the
  task without stopping it, and the status line says what moved and whether its agent was told.

### Changed

- Every push checks with the release tool that no page or source cites an issue, and that every page
  under `doc/` is in the site's navigation exactly once, and runs the tests that read a document;
  a push of documents alone runs only these and leases no machine.
- Every push checks with the release tool that each directory with a `pom.xml` has a `README.md`.
- A release refuses to build when anything Maven resolved for it is a snapshot - the parent, the
  tools or their plugin dependencies - and names what it found.
- The Maven build takes the project's parent POM as its parent, which gives it the JDK, the build tools' and
  the plugins' versions, and the `ci-tools` profile that puts the tools on the checks' classpath;
  the `hetzner` profile only rents and sweeps a machine.
- The Dart and Flutter packages are at the newest versions that resolve with Flutter 3.47.0,
  `cupertino_icons` at 2.0.

### Fixed

- Text copied out of a work's terminal keeps the spaces it shows, also where the program moved the
  cursor instead of writing them, as Claude Code does.

## [0.4.0] - 2026-10-05

Initial public version.
