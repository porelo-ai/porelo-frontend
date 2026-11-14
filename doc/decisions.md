# Decisions

What holds and what it costs, including the risks that were looked at and accepted. **A decision
here is not a rule** — rules live in [AGENTS.md](https://github.com/porelo-ai/porelo-frontend/blob/main/AGENTS.md) — and it is not an open question,
which is an issue. What it records is a choice somebody would otherwise make again. When one was
taken, `git log` answers.

| What was decided |
|---|
| [The interface can do what a console can](#the-interface-can-do-what-a-console-can) |
| [No browser: the interface is a desktop application over a unix socket](#no-browser) |
| [The interface raises and supervises its own ssh forward, and a cut stream is a disconnection](#the-interface-raises-and-supervises-its-own-ssh-forward) |
| [A connection trial may ask the machine for its uid without a question, to name a wrong one](#a-connection-trial-may-ask-the-machine-for-its-uid-without-a-question) |
| [A socket that answers is refused rather than deleted; the remaining race is accepted](#a-socket-that-answers-is-refused-rather-than-deleted) |
| [`XDG_RUNTIME_DIR` is trusted, and that is not a hole worth closing](#xdg_runtime_dir-is-trusted) |
| [An agent's login redirects to localhost, forwarded here, rather than asking for a code](#an-agents-login-redirects-to-localhost-forwarded-here) |
| [A key sent from this computer goes into the vault, and only the private key is asked for](#a-key-sent-from-this-computer-goes-into-the-vault) |
| [A unit that refuses is a failure, and a start without one is watched for two seconds](#a-unit-that-refuses-is-a-failure-and-a-start-without-one-is-watched-for-two-seconds) |
| [A project comes from the organization, or from a file on one machine](#a-project-comes-from-the-organization-or-from-a-file-on-one-machine) |
| [A project's settings are changed only in its repository; the window never writes a `project.yml`](#a-projects-settings-are-changed-only-in-its-repository) |
| [A person's signing key is found among those the forge lists for them](#a-persons-signing-key-is-found-among-those-the-forge-lists-for-them) |
| [A refused project signature is a state of the project, and it is put in front of a person](#a-refused-project-signature-is-a-state-of-the-project) |
| [Work always starts in a repository somebody chose; the project stays the unit of navigation](#work-always-starts-in-a-repository-somebody-chose) |
| [Daily work in front, setting up apart: the window opens on *Work*](#daily-work-in-front-setting-up-apart) |
| [Needs you shows what a machine knows, not what a terminal seems to say](#needs-you-shows-what-a-machine-knows-not-what-a-terminal-seems-to-say) |
| [Needs you shows only what needs a person; everything else is under *Work*](#needs-you-shows-only-what-needs-a-person) |
| [Needs you has ranks, and a question with a deadline is always first](#needs-you-has-ranks-and-a-question-with-a-deadline-is-always-first) |
| [A held message is read whole, as text, before it is decided, and one the filter refused can still be delivered](#a-held-message-is-read-whole-as-text-before-it-is-decided) |
| [A person's own words reach a task's agent in its inbox: why a push was dropped, why a message was refused, or anything else](#a-persons-own-words-reach-a-tasks-agent-in-its-inbox) |
| [Whom work may talk to is the project's: its rules declared in its repository, only the brake set here](#whom-work-may-talk-to-is-the-projects) |
| [An authorization is granted in a browser, its link shown whole, and the wait ends outside the interface](#an-authorization-is-granted-in-a-browser) |
| [A tile keeps its actions, each offered only where it can be honored](#a-tile-keeps-its-actions-each-offered-only-where-it-can-be-honored) |
| [A row says its state; its agent's lines are under Running](#a-row-says-its-state-its-agents-lines-are-under-running) |
| [One session at a time, in its tab under Running](#one-session-at-a-time-in-its-tab-under-running) |
| [Handing off work from another device needs no feature of its own](#handing-off-from-another-device-needs-no-feature-of-its-own) |
| [The settings file is written atomically and owner-only, and a bad entry is dropped rather than fatal](#the-settings-file-is-written-atomically-and-owner-only) |
| [What was run is kept for thirty days in one owner-only file, and an unseen failure still waits](#what-was-run-is-kept-for-thirty-days-in-one-owner-only-file) |
| [The new-machine wizard may use root once, inside the wizard, and never stores it](#the-new-machine-wizard-may-use-root-once) |
| [The person's forge token is entered in terminals and kept here for the API and in each machine's vault for git](#a-forges-token-stays-on-this-computer) |
| [The review only shows; the whole push is approved or rejected](#the-review-only-shows) |
| [A waiting push is read in the person's own clone, and never built there](#a-waiting-push-is-read-in-the-persons-own-clone-and-never-built-there) |
| [Clearing a machine or a project is one action, and the forge's part is the interface's](#clearing-a-machine-or-a-project-is-one-action-and-the-forges-part-is-the-interfaces) |
| [A person joins a project's conversation by an account made for them, its login shown once](#a-person-joins-a-projects-conversation-by-an-account-made-for-them) |
| [The homeserver starts with a project's first conversation, not with the machine](#the-homeserver-starts-with-a-projects-first-conversation-not-with-the-machine) |
| [A push that changes only documentation starts no build](#a-push-that-changes-only-documentation-starts-no-build) |
| [Where a Dart or Flutter skill says otherwise, this repository's measured rules win, and what was left is named](#where-a-dart-or-flutter-skill-says-otherwise) |
| [The license is GPL-3.0-only, and *or-later* is not decided](#the-license-is-gpl-30-only-and-or-later-is-not-decided) |
| [The client is written by hand until it has drifted from the contract once](#the-client-is-written-by-hand-until-it-has-drifted-from-the-contract-once) |
| [A WSL distribution is reached through `wsl.exe` and the relay, never over a port](#a-wsl-distribution-is-reached-through-wslexe-and-the-relay-never-over-a-port) |
| [A stopped WSL distribution is never started by the interface, but for the restart a person asked for](#a-stopped-wsl-distribution-is-never-started-by-the-interface) |
| [The Windows build is checked on GitHub's Windows runner; a test on a Windows machine is welcome, not required](#the-windows-build-is-checked-on-githubs-windows-runner) |
| [The rename to Porelo carries nothing over: the interface is installed afresh](#the-rename-to-porelo-carries-nothing-over) |
| [A work's terminal keeps the cursor its program sets; the sign-in and passphrase terminals always show one](#a-works-terminal-keeps-the-cursor-its-program-sets) |
| [The interface takes the website's colours and shapes, not its motion, and keeps a light mode](#the-interface-takes-the-websites-colours-and-shapes-not-its-motion) |
| [`porelo-host down` keeps a host whose down play did not finish, until told otherwise](#porelo-host-down-keeps-a-host-whose-down-play-did-not-finish) |
| [`porelo-host` is a command of its own, and the playbook runs on the host itself](#porelo-host-is-a-command-of-its-own-and-the-playbook-runs-on-the-host) |
| [The person's ssh key is registered once by hand in Scaleway's console; the API key only reads keys](#the-persons-ssh-key-is-registered-once-by-hand-in-scaleways-console) |
| [The host key is made by `porelo-host`, handed to cloud-init and kept in the server's tag, never scanned](#the-host-key-is-made-by-porelo-host-and-kept-in-the-servers-tag) |
| [A server without the project's tag is never given back; `down` finds the host by the tag alone](#a-server-without-the-projects-tag-is-never-given-back) |
| [No Scaleway secret is on GitHub: the Build tests against recorded answers, with one real rent per release](#no-scaleway-secret-is-on-github) |
| [The interface calls the `porelo-host` its own package ships by path, never by `PATH`](#the-interface-calls-the-porelo-host-its-own-package-ships-by-path) |
| [An agent on a host is signed in at task start, and every ssh trusts only the key `porelo-host` pinned](#an-agent-on-a-host-is-signed-in-at-task-start-and-every-ssh-trusts-only-the-key-porelo-host-pinned) |
| [Tresorit's installer runs only when signed under a pinned CA, checked on the machine](#tresorits-installer-runs-only-when-signed-under-a-pinned-ca-checked-on-the-machine) |
| [A task's program may write this computer's clipboard, never read it](#a-tasks-program-may-write-this-computers-clipboard-never-read-it) |
| [Each repository's agent is started one after another, a stopped one brought back, and leaving does not cancel](#each-repositorys-agent-is-started-one-after-another) |
| [Host joining uses verified signed state and SSH](#host-joining-uses-verified-signed-state-and-ssh) |
| [One set of servers, called machines, and two lists of them](#one-set-of-servers-called-machines-and-two-lists-of-them) |
| [A row's actions are behind one menu, and a page's lists are cards](#a-rows-actions-are-behind-one-menu-and-a-pages-lists-are-cards) |
| [A change that adds to or takes from a list closes onto a provisional row](#a-change-that-adds-to-or-takes-from-a-list-closes-onto-a-provisional-row) |
| [Each organization role answers for the one below](#each-organization-role-answers-for-the-one-below) |
| [Planning is porelo-planner's, and the window keeps none of its own](#planning-is-porelo-planners-and-the-window-keeps-none-of-its-own) |
| [A planner the window started ends with the window](#a-planner-the-window-started-ends-with-the-window) |
| [The window carries ideas to the planner, which talks to no Porelo](#the-window-carries-ideas-to-the-planner) |
| [The planner is given the one Porelo the window vouches for, by its path](#the-planner-is-given-the-one-porelo-the-window-vouches-for) |
| [A task on a host is certified by this computer's agent, which is never forwarded](#a-task-on-a-host-is-certified-by-this-computers-agent) |
| [An organization may be created at an https address, with a word that no machine can follow it](#an-organization-may-be-created-at-an-https-address) |
| [The side bar is a folding tree, and only a leaf shows a list](#the-side-bar-is-a-folding-tree-and-only-a-leaf-shows-a-list) |
| [The scenarios' stub agent is pinned by version, and a warning says when to move it](#the-scenarios-stub-agent-is-pinned-by-version-and-a-warning-says-when-to-move-it) |

## The interface can do what a console can

The interface stands in for working at the console, so what a person can do there with `porelo` is,
as far as it goes, reachable here too — stopping a daemon because starting one is, rather than
leaving one half to a terminal. Where an action costs something, the question before it says what;
where the machine cannot be asked, the action is shown as unavailable with its reason. What stays out
is what the contract rules out on purpose: a passphrase typed here, a secret's value on the socket.

## No browser

The interface is a Flutter application talking to a unix socket, and reaching a remote Porelo is an
SSH socket forward rather than a server. A browser interface is the one thing that would force the
daemon to bind a network interface, and leaving it out is what keeps local and remote the same code.

## The interface raises and supervises its own ssh forward

Three choices Porelo's remote access leaves to the client:

- **Which tunnel shape: a unix socket forward**, `ssh -L <local socket>:<remote socket> <host> -N`.
  The daemon never binds a network interface, so local and remote are the same code over the same
  socket. A socket somebody else forwarded is also accepted, and is opened as it is — nothing
  raised, nothing supervised, nothing taken down.
- **The interface manages `ssh` itself** for a machine described by where it is: one process per
  machine, `BatchMode=yes` so it fails with ssh's own sentence rather than prompting, and
  `ExitOnForwardFailure=yes` so a forward that cannot bind does not read as connected. When a
  login is refused, the refusal is explained in plain words beside the machine on *My machines* as well
  as when it is added, naming the key `ssh`'s configuration resolves for the host or saying that
  none is named. It owns only what it raised, and closing the window takes those down.
- **A cut stream is a disconnection, never an empty machine.** A forward that drops is raised again
  without being asked, and a machine that stops answering is tried again every two seconds; a
  `Watch` that ends without its final reply reports a lost connection. Nothing is re-derived from
  silence.

## A connection trial may ask the machine for its uid without a question

When *Try the connection* finds the forward up and nothing serving, it runs
`ssh -n -o BatchMode=yes <host> id -u` and compares the uid with the one in the typed socket path, so
a socket in somebody else's runtime directory is named as that rather than as a missing daemon.

**Why without a question**, when starting a daemon asks first: `id -u` reports the caller's own uid,
needs no privilege, reads nothing of anybody else's and changes nothing — and it runs only inside a
trial the person asked for. The rule it relaxes exists for commands that change a machine.

**What would change the answer:** any second command added beside it, or one that reads more than
the caller's own identity. A trial that needs more than that asks, the way a start does.

## A socket that answers is refused rather than deleted

The endpoint of a managed forward may belong to another program of this user that happens to sit at
that path. Taking it away to put ours there would break it silently, so the forward is refused and
says so; only a socket that answers nothing is removed as a leftover.

**Accepted risk:** the probe and the delete are not one operation, so a socket that comes alive in
between is still removed. What would change the answer: an ownership marker or a lock protocol,
which nothing else on either side of this implements, or a per-instance directory. It needs another
process to bind that exact path inside a millisecond-wide window, and a second instance of this
interface — the likeliest candidate — is already prevented by the single-instance socket.

**A forward this interface left behind is ended, not refused.** Each ssh forward raised here is recorded under
`$XDG_RUNTIME_DIR/porelo-forwards` with its pid, start time, boot id and arguments, the directories 0700 and the record
0600, all of this account, written without following a link. At a start, after the single-instance socket is taken, an
endpoint that already answers is ended only when its record still names that very process, of this account, forwarding
this very endpoint and not held by this run; the signal goes through a pidfd, and an endpoint still answering two
seconds later is refused as before. Elsewhere than Linux nothing is swept. SIGINT and SIGTERM let go of every forward
as closing the window does, within five seconds; SIGKILL and a crash leave what the next start ends. No parent-death
signal is used: Linux sends it when the starting thread ends, and Dart starts processes from pool threads.

## `XDG_RUNTIME_DIR` is trusted

Both the local endpoint of a forward and the single-instance socket are placed under it, from the
environment. **Accepted risk, and deliberately not defended against:** anybody who can set that
variable for this process can already run code as this user, so a check here would buy nothing and
would break the legitimate use — a test or a sandbox pointing the interface at a directory of its
own, which is how `tool/e2e.sh` isolates a run.

## An agent's login redirects to localhost, forwarded here

Signing in is pressing the link in the terminal and signing in in the browser here, with no code
typed back. The login's redirect to `localhost:<port>` is forwarded from this computer to the same
port on the machine for as long as the login terminal is open, and taken down after. Only a login
terminal may ask for it, for one port that is not a privileged one, and only once.

**What it costs**, measured at the machine: a listener on a rootless container's own loopback
cannot be reached by publishing its port, so the login container runs with the machine's network.
Its processes can then reach whatever listens on the machine's own loopback. It is a throwaway
container with no vault, no broker and no egress ruleset either way. **What would change the
answer:** an agent whose login must run with a credential or a workspace inside it.

## A key sent from this computer goes into the vault

A private key sent from here goes into the machine's vault, and never into the SSH folder there. Only the
private half is asked for, because the machine works out the public half. A key that is already in
the SSH folder is chosen where it lies, so the case of a key in the SSH folder is covered without this interface
ever writing a private key to a disk.

A token or a password is not sent from here at all. It is typed into a terminal on the machine,
as the wizard's last step, so the only secret this interface ever handles is a key file.

**What it costs:** somebody who wants their key as a plain file on the machine puts it there
themselves, and then chooses it from the list.

## A unit that refuses is a failure, and a start without one is watched for two seconds

- **A unit that is loaded and refuses is a failure**, reported with systemd's own words and exit
  code. Starting the binary behind it would run a daemon nobody supervises, next to a unit that
  says it is stopped.
- **Only with no unit loaded** — none installed, or no user manager to ask — is the binary started
  directly.
- **Such a start is looked at two seconds later**, and a daemon that has already ended is a failure
  with its exit code and the last lines it wrote. Two seconds is enough for one that cannot read
  its configuration and short enough not to hold every start. A daemon that dies later is found by
  the connection trial that follows every start.

Measured at a machine with a user unit installed: the start line reports *"started by systemd"* and
the daemon comes up in `app.slice/porelod.service`.

## A project comes from the organization, or from a file on one machine

A project is the organization's, and a person has it because a project admin made them a member and
a host carries it. Its `project.yml` lives in the project's own repository, and what is wrong with
it comes back as the machine's named reasons, never as rules worked out here. The interface makes no
project from a repository.

A project registered on a machine alone comes from a `porelo task start` from a project's file, or
from `$XDG_CONFIG_HOME/porelo/projects/<name>/project.yml`, written by the person. Only such a project
is removed here, with `porelo project remove`, and only on this computer: `porelo project list` says
whose a project is, for this computer alone.

## A project's settings are changed only in its repository

The window never writes a `project.yml`: the file in the project's repository is the one source of
truth. A repository without one is said to be no Porelo project, and nothing is offered for it. What
a project may reach is shown, with where each host comes from, and said to be changed only in its
`project.yml`.

Porelo changes no project file that exists either. Where a person adds, changes or removes a
project's repository, changes its review policy or fills a project from a checkout, the window shows
the entry Porelo says to write, verbatim, with the file it goes in and a way to copy it, and the
project's admin commits it signed; for a removal, Porelo's words say what to take out. Nothing of it
is signed in the window. An older Porelo that still writes the change itself and answers the
revision it wrote is taken as written, and the pages are read again, so that nothing is asked twice.
Opening a project asks whether its person works alone, and a yes opens it with review optional.

What stays in the window is what is no setting of the project: letting running work reach a host it
was refused, for that run or that work; and the brake on a project's messages to a peer.

**What it costs:** a project is made and changed in YAML, in an editor of the person's own.
Accepted, because a second way to write the file would be a second source of truth.

## A person's signing key is found among those the forge lists for them

The person's signing key is found, never chosen from every key the ssh agent holds: the SSH signing
keys their forge account lists, and git's `user.signingkey`, marked as theirs. Any other key is
offered only after them, as *another key*. Signatures are ssh signatures, never GPG.

*Make my card…* takes what Core found and where each came from. The login comes from a token or `ssh -T`. The key comes from
`git config user.signingkey` where it names an SSH key, then from a key in the agent that the forge lists for signing, then
from one it lists for authentication. Name and email come from `git config`, then from the forge's public profile. The
window shows them in one line with *Sign*, asks only what was not found or found more than once, and shows the `ssh-add`
line for a key that is not in the agent. Porelo reads no private key.

## A refused project signature is a state of the project

When a machine turns a project commit away, the project's header says so as a state of its own —
what is in force, what was turned away, and why — and the project is also **under *Needs you***,
because a commit signed by a key the machine was never given is either somebody putting a project
file past it or a legitimate commit signed with the wrong key, and both need a person. **Which
states need a person is Porelo's to say** (`needsAPerson`), never worked out here: an unreachable
repository may answer by itself on the next pass, a refused signature never will.

## Work always starts in a repository somebody chose

A project is one or more repositories. The project stays what the tree navigates by, with no level of
its own for repositories; the project's header has a line per repository, and the gate lists what
waits in every repository. **Starting work names a repository somebody chose**: preselected only where
the project has exactly one repository to work in, so there is nothing to choose. *This exception
waits for the operator's confirmation in a coming test run.* *Start again*, *Recreate*, *Continue* and a saved job keep the
repository the work was in.

**A project whose file names `repositories:` is never worked in itself**: its own repository holds
the file and the planning, only the named repositories are offered for work, and the project's
header says which is which. Without `repositories:`, the project is its one repository, and that
one is worked in.

## Daily work in front, setting up apart

Machines say where work runs, forges where its repositories are, and projects how it runs; they are
set up rarely, while tasks are the daily work. So the rail holds *Work* and *Needs you* first, and
under *Set up* *My machines*, *My forges* and *My projects*, with the refresh and the stop for every machine
at its foot. **The window opens on *Work***: every piece of work on every machine, grouped by what
it asks, each tile naming its machine, narrowed to a machine or a project, *Default* among them.
Work is shown only there; a machine's or a project's page leads to it, narrowed.
A rail entry always lands on the first page it opens, whatever was open under it: *Work* from the rail shows all work,
and only a machine's or a project's page leads to it narrowed. *Refresh* at the rail's foot also reads the page shown
again, a machine's page by `org status`, which only reads. A machine's own *Fetch now* is what makes it fetch the
organization at once, and the page says when the machine last answered. The quiet refresh leaves the store and the
machines alone.

- ***New work*** asks where it runs when more than one machine answers, then in which project,
  *Default* among them. Where the project has work with a conversation on another machine, it says before the start
  that the two cannot talk.
- ***My machines*** and ***My projects*** list them, each opening a page of its own with its tools.
  Beside an organization, *My projects* lists the organization's projects the person holds a role in, and the rail
  counts the same. *Default*, the project every machine has, and a project a start in a checkout copied onto a machine
  stand under *All projects on your machines*, with a row and a page like any other: a repository is put into *Default*
  from its card on its forge's page.
- ***My forges*** lists every forge set up on this computer; a forge's page lists its repositories with
  a filter, each card saying on which watched machines it is worked on.
  Creating a Porelo organization lists its forge here, named by its repository's host, and asks for nothing: the token
  that created it is the access. Each count on the side bar is its page's rows with no filter counted; the organization
  page's *Projects* and *Machines* count the whole organization.
- **The first start**, while there is no work anywhere, leads through a machine that answers, a
  project or none, and the first work, each step saying when it is done.
- **Problems needing a person go to *Needs you***, a machine that does not answer included, so daily
  work needs no visit to the machines.

## Needs you shows what a machine knows, not what a terminal seems to say

Work first rather than navigation first, one pane for every machine, one tile per piece of work with
its state legible and its actions on it, and the machine as a property of the tile rather than a
mode of the window. **Not taken:** leading with model, context and cost, and detecting *awaiting
permission* by reading a session's terminal. Inside a task an agent's own permission prompts are off
by design — the container is the answer — so an agent stopping to ask is a defect rather than a
state to display. What a person is asked is a clearance question, which the machine knows. A quiet
task is drawn as a guess, and a guess is never drawn like a known state.

## Needs you shows only what needs a person

*Needs you* lists open questions, agents that ended, and work waiting at the gate, from every
connected machine, and says which machines are silent. **Working, quiet, unseen and stopped work is
not in it**: it is under *Work*, where the same tile carries the same menu.

**Why:** the reason to open the window is a short list of things that need answering. At fifty tasks
a list of every tile is fifty tiles of which two need anybody, and a filter added later to fix that
would hide something without saying what. Nothing is hidden this way; it is placed.

**An answered question, a resolved row, or a read message moves into *Recently resolved*** below the open rows,
newest first, kept in memory with its buttons disabled until a set time passes (one hour by default, or removed at once
with 0); it does not survive a restart, and keeps the confirmation of an answer from vanishing with the click that gave
it. **A question that ran out is a row of its own and counts until a person presses *Seen***, across a restart too: the
window cannot tell whether anybody looked when it ran out. The settings file keeps it with the address it asked to
reach, in plain words, and keeps up to fifty seen ones for a week, so a machine sending the same one again does not
bring it back.

**An operation somebody started that failed waits there too, until it has been opened** — from its
card, from the session record, or by having been open while it failed — so a failed start is not
found only by going to its machine. **No dialog reports an outcome**: the question before something
runs on another machine stays, and afterwards a failure goes to Needs you and a success to the
status line. A start from *Watch another machine* still shows its outcome in that dialog, where
somebody is waiting for the trial, and a failure there is recorded as well, so closing the dialog
does not lose it.

**A task whose agent ended before finishing its prompt is in it**, in the machine's words: the
error as the agent or the provider gave it, and when. A provider's refusal (credits, key, limits)
is named as the provider's, so the person looks there and not at Porelo. The end wins over the
activity: such a task is never said to be working or idle, and its row stands in *Needs you* until
it is opened or put away. An agent that finished its prompt needs nobody and is not listed.

## Needs you has ranks, and a question with a deadline is always first

Tiles order by what they are — an open question, then an agent that ended, then work at the gate,
then working, quiet, unseen and stopped — and within a rank by the nearest deadline, a question with
none sorting after every one that has one, then by the oldest question.

**So a week-old review can never sit above a question with two minutes left.** The page stands its
rows in cards: *Decide soon* holds the questions and the held messages, *Reviews* the work at the gate,
and *Also needs you* the rest.

**It counts every row, one number**, in its subtitle and on the side bar's badge, work at the gate like any
other: a count that left some rows out said two things about one page. Work that ended with a failure
or left something a person has not seen is a row until it is opened or put away; what was put away is
kept in the settings by machine, work and end, so a later end is a row again. Work that finished with
nothing waiting is no row and stays under *Work* alone. The rows that are no work, such as a silent
machine, a host's stop, a failed operation or an authorization, stay and count.

A planner's stopped reading is put away by the planner's own key for it: machine, project, issue, and the reason and
state it showed, so a change of either says it again. The window keeps that set in its settings, not the planner's,
whose set forgets every row no board says and so would bring each back at every start; a mark goes once its board,
read whole, no longer says it as it was, or no machine lists its project, or its machine is gone.

**What it costs:** a reading that stops again as it was while the window is closed, after its board stopped saying it
in between, stays put away.

## A held message is read whole, as text, before it is decided

A message waiting for a person is in *Needs you*, and **what was read is what is decided**: the
decision names the message that was shown, who wrote it, which way it was going and why it waits. It
is shown as selectable monospaced text and never interpreted: no markup, no link that can be pressed,
nothing fetched, because it has not been cleared. It is released or refused, never edited.

**A message the filter refused is read in full too, and can still be delivered**: a person decides
whether it is still delivered, and to decide must first see it whole and then act on it. That
reverses the earlier rule that it be shown only by a masked
excerpt. Delivered that way it is said as *delivered despite the filter*, never as released, and a
person delivering to an `external` peer is told that its own filter checks it again. What the filter
could not check at all is never offered.

**What it costs:** a refused message's text is on a person's screen. Accepted, because the person is
the one deciding, and nothing on the screen can act on it. **Not measured:** delivering a message the
filter refused, since the machines measured on run the filter without `--blocking`, so only an
inbound message from an `external` peer is refused by content.

## A person's own words reach a task's agent in its inbox

Dropping a push asks why, and refusing a message has a field for it; both are optional, and the
words go to the task the work or the message came from, so its agent knows why instead of handing
the same thing over again. The task is told that the push was dropped even without words; where no
task of that name is left, the interface says nobody was told. **Writing to a task's agent** puts a
person's words straight into its inbox, marked as a person's. It never leaves the machine, so it is
neither signed nor filtered: all three, by decision.

**What it costs:** a new way for content to enter a task. Accepted, because it carries only what a
person typed at their own interface, and it is said as such where the agent reads it.

## Whom work may talk to is the project's

A task's peers follow from its project and are **declared in the project's configuration, in its
repository** (`mail`), with the project's message rules: whether a message is allowed, asked about
or denied, for the project's other work, for the people in its room and for anyone else. The
defaults are the machine's, so a project writes only where it differs. Nothing on the socket writes
them, and nothing here offers to: the machine reads them from the verified `project.yml`.

**What stays in the window is the brake**: holding a project's messages to a peer, per project and
peer, for every task of the project, one started later included. A peer with everything held is
never shown as reachable, and `off` is said as what it is: nothing is asked, and the filter still
runs. **A person never writes to a peer from the window**: they write from their own Matrix client,
as themselves, in the project's room.

## An authorization is granted in a browser

Work that needs an authorization nobody granted asks a person, in *Needs you* and where the start was
refused, naming the credential, the work and the project. **The link is shown whole**, as it came from
the machine, selectable and kept on screen after it is opened; only an http or https address with a
host is ever opened here. For a redirect, the port its answer comes back to is forwarded over the
machine's ssh connection before the page is offered. **The wait says it is decided in the browser and
that the machine hears the answer**, never a spinner that implies the interface is doing the work.
Who granted it, and when, is shown from the machine's record.

A token that never expires, as GitHub's OAuth apps give one, is kept as it is, and
*Granted* carries the machine's words that removing it there cannot revoke it: only the person can,
at the service. A grant the machine would not keep is said as the machine's refusal, never as the
person's in the browser.

**Not measured:** a grant the service revokes while work spends it (`ended`).

## A tile keeps its actions, each offered only where it can be honored

The actions belong on the card when the view is used from elsewhere. The interface runs where the
person is and reaches every machine over ssh, so attaching is `porelo task attach` over ssh in a
terminal of the window's own and a diff is fetched over the socket — see *Handing off from another
device needs no feature of its own*. An action a machine cannot honor from here is shown as
unavailable with its reason rather than removed: working in a task by hand, for one, is unavailable
for a machine reached through a socket somebody else forwarded, because there is no host to log into.

## A row says its state; its agent's lines are under Running

An unfolded row on *Work* shows its state's whole sentence, its facts and its way on: *Open its terminal*, *Follow its
log*, or *Read its log* once its work has stopped. It shows none of its agent's lines: those are in its tab under
*Running*. Its *Tokens used* is read when it unfolds, and every thirty seconds while running work's row stays unfolded;
where to go next is said in *Needs you*, since no row of *Work* decides.

**What it costs:** a row of work in a terminal, folded too, is asked every thirty seconds, one call at a time, whether
its session is there (`Screen`), so its row and its tab can say when it has ended.

## One session at a time, in its tab under Running

Two sessions over one terminal make leaving one look like leaving both. So:

- **One session is open at a time.** Working by hand in other work leaves the one that was open,
  without asking: nothing at the far end stops, and opening it again shows its last lines. The status
  line says which was left.
- **Terminals have one place, *Work* > *Running***: a tab per running agent. Asking for a session
  anywhere goes there.
- **Changing the tab, or leaving the page by a menu click, leaves the session.** The agent runs on, and
  coming back shows the same tab, which opens its session again. Nothing else is a way out of it.
- **A tab looks before it opens**, through `Screen`, since attaching to a session that ended would start
  a new one nobody asked for. That one says so, with *Open a new terminal* as its next step.
- **Ctrl+PgUp and Ctrl+PgDn go to the next agent and never reach the far end**; every other key does.

## Handing off from another device needs no feature of its own

A session on a remote machine is `porelo task attach` over ssh in a terminal of this window's own,
and a diff is fetched over the socket and handed off here. Both are what the interface already does,
so neither is a separate capability.

## The settings file is written atomically and owner-only

Written beside itself and renamed over it, and `0600` before the rename. A write in place is not
one step: a crash halfway leaves truncated JSON, which the reader cannot tell from a first run, so
*"why are my machines gone"* would have no answer in the file. The mode matters because the file
names the machines somebody watches and the accounts they log in as — not secrets, and not
everybody's business.

**A malformed entry is dropped and the rest kept.** A throw during the load happens where nobody
awaits it: the window opens with the machine list silently reduced to the local daemon, which is
indistinguishable from having lost it. A machine with no name or no socket cannot be watched or told
apart from another, so it is not one.

## What was run is kept for thirty days in one owner-only file

Every operation — what ran, on which machine, what it printed and how it ended — is kept in
`$XDG_STATE_HOME/porelo/operations.json` (the default state folder without it), and
the list of what was run shows earlier ones beside this run's, marked *earlier*, and names the file.
The finder opens it with the desktop's opener.

- **Thirty days**, and only an operation's last 2,000 lines, with how many were not kept said where
  it is read. Older operations are dropped when the file is read, and the list says how many.
- **One file for every machine.** One place to open, and forgetting a machine does not forget what
  was run on it.
- **A failure nobody opened still waits under Needs you after a restart.** Whether it was seen is
  kept with it, so closing the window before reading a failure does not count as reading it.
- **Written the way the settings are**: beside the file and renamed over it, mode 600, because it
  names hosts. A start, an end and being seen are written at once; the lines of a busy operation are
  gathered for a second, so a build that prints thousands of lines is not thousands of writes.
- **An operation still running when the window closed comes back as a failure nobody has seen**,
  saying that how it ended is not known. Nothing watched it end, and reporting it as finished well
  would be a guess in the direction that costs.
- **Nothing read back is announced again.** A desktop notification for yesterday's build on every
  start would teach somebody to ignore them.

## The new-machine wizard may use root once

Preparing a rented machine means packages and `/etc`, which is root on the node, so the wizard uses
root for setting up, and nowhere else. Root is never stored: no `Host` entry, no setting and no
forward names it. Every command run as root is shown before it runs, and the person agrees to the
step. Every step checks before it acts, so a wizard run again changes nothing that is already
right. The work user is made before the packages, and the setup script is Porelo's, published beside
the packages and fetched on the machine, because installing Porelo is Porelo's knowledge.

**What it costs:** a person who can rent a machine is trusted with root on it for a few minutes,
inside one dialog. Accepted, because the alternative is a terminal, which a person new to Porelo
does not have.

## A forge's token stays on this computer

The person's own forge token is entered only at a terminal prompt. On this computer, *Connect a
forge* opens `porelo-host key set <forge address>`, which reads without echo into the system secret
store. The interface reads the same entry for its forge API calls, sending the token only in the
Authorization header. The local working clone reaches git through its environment. No form takes
a token, and no token enters a command line, the settings or an operation record.

Binding a machine opens a terminal there running `porelo vault put git.token.<host>`. Porelo's own
prompt reads the person's token into that machine's vault for git over https. The interface checks
the vault listing by name; no token value crosses the daemon socket. Git over ssh continues to use
the person's ssh key. The interface makes, lists, checks and removes no deploy keys, and the token
needs no right to administer them. Device-code login can use the same terminals when the forge's
OAuth application is available.

For `porelo org create` and `porelo project open`, a forge token missing from Core's local vault goes there from the system
secret store by `porelo vault put git.token.<address>`, on standard input alone, with the vault opened first. Where the
secret store has none, it is asked for in the `porelo-host key set` terminal, as above. A forge reached by ssh on a port of
its own is lent no token this way. A machine, which has no account at the forge, takes its Machine Admin's token once, on
its own command's standard input. With it, the machine adds its own read-only key to the organization's repository and to
each waiting project's, and copies the project's repository to its own forge. It holds the token in memory for that run
alone, which is read on one host and not checked against the token itself. For that, the token needs the repository's
Administration (write) and Contents (read).

**The exposure:** each machine holding the person's token can use its repository rights. Keep its
scope to the repositories it needs, with Contents for git, and Administration only while a machine is given it to add
its read key. **What would change the answer:** a forge
login that grants narrower access without requiring repository administration.

## The review only shows

The ranked review shows what a push changes, the machine's order and reasons first, and what the task
was asked apart from what it touched. No entry in it offers anything of its own: what is decided is
the whole push, approved or rejected. The order is the machine's, and the screen says that it
detects nothing.

## A waiting push is read in the person's own clone, and never built there

Beside the review, the `git fetch` the machine names for each waiting push is shown whole and
selectable, with the host this computer reaches the machine by, and copied with one button. It
says the work is the agent's and not yet reviewed: open it in the IDE's safe mode, and never build
or test it on this computer, where it would run with the person's rights. Nothing is fetched by
itself.

## Clearing a machine or a project is one action, and the forge's part is the interface's

*Clear this machine…* and *Clear this project from the machine…* list what the machine's dry run
says will go, then clear it with one press. The machine removes what Porelo put there. The interface never
contacts the forge's deploy-key API or edits signing policy while clearing. If the daemon names a legacy key in its removal or clear
answer, the interface shows its name and the daemon's words verbatim, leaving its removal to the
person. The person's token stays in this computer's system secret store and in each machine's
vault until explicitly forgotten. One report says, thing by thing, what was removed and what was
left and why, and one refusal does not stop the rest.

## A person joins a project's conversation by an account made for them

A person takes part in a project's Matrix conversation from a client of their own, through an account
the machine makes for them. Its login is shown once, whole and selectable, and kept nowhere; a
second join offers a new password.
Where the person already has an account on that homeserver, a join into another project's room invites it instead:
no password is made or shown, and the person accepts the invitation in the client they already sign in to.

**Where the homeserver is the machine's loopback, its port stays forwarded while the window runs**,
once the person has joined from this computer, and not only while the dialog is open: a Matrix
client that loses its homeserver says so only later, and what was written meanwhile never arrives.
The project's page and the dialog say the address the client reaches, or why it is not reachable.
The forward is remembered in the settings and raised again when the window starts, the same port
as far as it is free, so a client's saved address keeps working. One that drops is raised again on
the next round, and one that cannot be raised is under *Needs you*. A homeserver not on the
machine's loopback gets no forward.

## The homeserver starts with a project's first conversation, not with the machine

Setting a machine up starts no homeserver; a project's first conversation does, and every later
project is a room on it.

**What it costs:** the first conversation of a machine waits about ten seconds for it, and the
window forwards one homeserver port per joined project. Accepted, because a homeserver at machine
setup costs every machine about 165 MB of memory at rest, whether it ever carries a message or not.

## A push that changes only documentation starts no build

A build runs the tests, leases a machine for the integration tests, installs and publishes a
snapshot — all of it for a package that has not changed when only documentation did. `build.yml`
ignores pushes whose every change is under `**.md`, `doc/**` or `issues/**`; a push that changes code
as well runs in full, and `workflow_dispatch` still forces a run. On a push whose tree a run already
proved with the leased leg green, the build skips leasing again and names the run it took the
proof from; a tag always runs the leg.

**The cost is that CI does not check such a push**: the decisions index, dead links and retired
issue ids are held by `test/docs_test.dart` run before the commit, not after the push.
`test/packaging_test.dart` fails if the filter goes or grows to cover anything but documentation.

## Where a Dart or Flutter skill says otherwise

The whole of `lib`, `test`, `tool` and `integration_test` has been read against the sixteen skills
`AGENTS.md` names, each checked against its SHA-256. Every finding was fixed with a test that fails
without the fix, or is named here.

**Where a skill and a rule recorded in `AGENTS.md` disagree, the rule stands**, because each of these
was measured here and the skill was written for an application that is not this one:

- **Tolerant readers**, not fast-failing ones: `dart-use-pattern-matching` and
  `flutter-implement-json-serialization` throw on an unexpected shape; a client that dies on an
  unfamiliar reply dies on a routine backend release.
- **`Outcome` and the other values that arrive from a backend are not Dart enums**, and every switch
  over one has a `_` arm; exhaustiveness is what the tolerance rule is about.
- **No `freezed`, `provider`, `get_it` or `lib/data`/`lib/domain` layout**
  (`flutter-apply-architecture-best-practices`): `lib/src/app` is what the interface knows and
  `lib/src/ui` draws it, models are `ChangeNotifier`s passed in, and the frame talks to
  `FleetBackend`.
- **`World.settle`, never `pumpAndSettle`**; **stand-ins that act, never `mockito`**; **`integration_test`
  under xvfb, never `flutter drive`**; **no breakpoint compared outside `window_size.dart`** — each
  recorded in `AGENTS.md` with what it costs.
- **Processes are driven with stand-in scripts in temporary folders, not `package:test_process` and
  `test_descriptor`** (`dart-build-cli-app`): the scripts are the far end's own programs, `ssh`,
  `systemctl`, `xvfb-run`, put first on a `PATH` the test builds, and what is held is what the real
  script does with them. `tool/contract.dart` stays one dependency-free file, run as
  `dart tool/contract.dart <socket>`, with no `bin/` and no command framework around it.

**Not done, on purpose:**

- **Primary constructors** (`dart-use-primary-constructors`) are on by default at Dart 3.13, and new
  code may use them. Moving every class to them would reflow every file, which `AGENTS.md` rules out.
- **`package:checks`** (`dart-migrate-to-checks-package`) would rewrite every assertion in the suite
  and find nothing.
- **Dialog widths 520, 540 and 560** are three tokens, as they are three values. Whether they are
  meant to be one width is a design question, not a defect.

**Found, measured, and not confirmed** — so not changed, and no test kept, since a test that passes
with and without a fix proves nothing:

- Settings written from several places at once: 50 writes started together, three runs, the last one
  landed every time and nothing was left beside the file.
- A stream whose final reply is followed at once by the peer hanging up: five runs, it ended quietly.

**Measured and accepted:**

- **A 7 MB reply blocks the interface for about 250 ms**, 1 MB for about 25 ms. Reading it byte by
  byte is not the cost: reading up to each NUL at once measures the same, so the time is the
  transfer and the decoding. Replies that size are rare — a very large review. What would change the
  answer: decoding in another isolate, if a real review is ever felt.
- **The operation record is encoded once a second while something runs**: 22 ms for fifty operations
  (8 MB), 64 ms for two hundred. Thirty days of ordinary use is far below that.

**Left, named, because each is taste rather than a defect:** a few decisions made in a view rather
than its model (`_setsIn` in the shell and the egress view, reading a key file in `_sendAKey`);
`check!` read several times where one local would do; a file's label cut at `/` on a Linux-only
application; a review's diff built as one list rather than lazily; `PickAFile`'s `title` parameter,
which is the confirm button's words.

## The license is GPL-3.0-only, and *or-later* is not decided

The rest of Porelo is GPL v3, and the packages, the POM and `LICENSE` here say `GPL-3.0-only`.
**What is not decided is *or-later*.** It is the operator's to settle: `-only` cannot be relaxed
later without every contributor's agreement, while `-or-later` cannot be tightened at all. Nothing
depends on the answer.

## The client is written by hand until it has drifted from the contract once

The contract is machine readable and the daemon serves it, so a client generated from the IDL is
possible. It is not written: a generator is code to keep, and it pays for itself only once a
hand-written client has drifted from the contract. The tests that read the served contract
(`dart tool/contract.dart`, the live daemon tests) are what would show that drift.

## A WSL distribution is reached through `wsl.exe` and the relay, never over a port

`porelod` answers only on its unix socket, which a Windows program cannot open across WSL2's
boundary. The interface runs `wsl.exe -d <distribution> --exec porelo daemon connect` and speaks
Varlink over its standard input and output, as Docker Desktop and Podman Desktop reach their WSL
machines. **Not `porelod` on TCP at localhost:** WSL2 forwards such a port to Windows, where any
program of any user could start tasks, approve at the gate or open the vault; the socket's file
permissions are the only guard, and a port would remove it. Not an ssh server in the distribution
either: it is one more service and key for what `wsl.exe` already does as the Windows user.

## A stopped WSL distribution is never started by the interface

`wsl.exe -d <distribution> -- …` starts a stopped distribution, with its memory and CPU. The
interface reads each one's state with `wsl.exe -l --running -q` and `-l -v`, which start nothing,
calls into one only while it runs, and shows a stopped one as stopped for the person to start. **The
one exception** is turning systemd on, which needs the distribution restarted: asked as a question of
its own, saying that shells, services and running Porelo tasks in it end, the answer no unless the
person changes it; after a yes, `wsl.exe --terminate` and the next call starts it again.

## The Windows build is checked on GitHub's Windows runner

There is no Windows machine here, so the rule that the whole workflow runs green on the VM before a
push has one exception: the Windows build's regular check is GitHub's Windows runner, its unit,
feature and documents tests, the ZIP and the MSIX built and signed, and the MSIX installed and
started once after a copy signed with another certificate is seen refused. The operator tests on a
Windows machine from time to time, as [design](design.md#a-test-on-a-windows-machine) says how;
such a test is welcome, not required before a push or before an issue is finished. Until one is
done, the download page and the issue's row say "untested on a Windows machine", then "tested on
Windows on <version>".

**The exposure:** until such a test, nothing has shown the interface on Windows reaching a WSL
distribution, a terminal attached through ConPTY, a push approved at the gate, or that a second
Windows user cannot reach the distribution.
**What would change the answer:** a Windows machine here would make the test part of every
hand-over.

## The rename to Porelo carries nothing over

The interface installs as `porelo-frontend`, keeps its settings in `porelo/frontend.json` and speaks
`porelod`'s contract; nothing reads the old name's settings, socket or packages. The MSIX is a new app,
`ai.porelo.frontend`, beside the old one rather than an update of it. The old name stays only where
a sentence says what it was - the changelog's released sections and the line that announces the
rename - and `test/no_old_name_test.dart` holds every other tracked file to the new name.

**The exposure:** a person who used the interface under the old name connects their machines again
and removes the old package and app themselves. **What would change the answer:** people outside
this project who installed a release under the old name.

## A work's terminal keeps the cursor its program sets

The sign-in terminal and the vault's passphrase terminal always show the cursor while they wait for
the person, whatever runs in them hides: a pasted code has to be seen to land. The terminal of a
piece of work honours what runs in it, since Claude Code hides the terminal's cursor and draws its
own, and a second cursor there would point at the wrong place.

## The interface takes the website's colours and shapes, not its motion

The interface looks like Porelo's website - its ground, cyan, magenta, lime and amber, its rounded
surfaces with a hairline border and its logo - so the two read as one product. Unlike the website it
keeps a light mode beside the dark one, the same hues darkened for a pale ground, and every text and
mark in either holds WCAG AA (`test/ui/theme_contrast_test.dart`). Its surfaces are the website's
frosted glass laid opaque, and its moving background, glitch and typing effects stay on the website:
a blur and motion cost a tool open all day more than they give. The terminal stays dark in both
modes.

## `porelo-host down` keeps a host whose down play did not finish

The down play copies the host's last state off, the drive's sync and the Matrix room among it,
before the host is given back. When every step of it finishes, or `up` never got as far as any
data, `down` gives the host back. When a step does not finish, or the host cannot be reached, `down`
keeps the host: the failed step says what failed and what would be lost, and the last line says the
host is kept and still billed, and names the ways out: `down` again, or `down --give-back-anyway`
to give it back knowingly. Taking a server down confirms the consequences (giving the server
back, deletion at the provider, billing stops, server vault and room history lost) with a red
*Give the server back* button before running `down`. The test script says a host kept so as plainly.

**What it costs:** a host kept goes on billing until somebody looks, and the person who closed the
window may not. The other way, giving back whatever the play answered, ends the bill but can take
the only copy of a project's data with it. The data is kept, with the bill said plainly.
`down` cannot tell a failed copy from another failed step, so any failure keeps the host; the down
play itself must finish for what `up` never made.

## `porelo-host` is a command of its own, and the playbook runs on the host

Putting a project on a server and taking it off again is a standalone command, `porelo-host`, built
from `packages/porelo_host/` for Linux and Windows, rather than a subcommand of `porelo`: Porelo
does not run on the person's computer before the host exists, and does not run on Windows at all.
`porelo-host` copies the collection's tarball and the first play's inventory to the server with
`scp`, installs `ansible-core` there, and runs `ansible-playbook -c local` on the host itself,
while Porelo on the host writes the second play's inventory. The person's computer needs only
`porelo-host`, `ssh` and `scp` — no Python and no Ansible locally.

## The person's ssh key is registered once by hand in Scaleway's console

`porelo-host up` refuses renting until it returns as planned for 0.9, sprint 5; this and the next three decisions hold for then.

`porelo-host` never registers an ssh key at Scaleway. The API key it uses holds Elastic Metal and
`SSHKeysReadOnly` only, so the key that rents cannot change who may log in to what it rents.
Before renting, `up` reads the project's keys and, when the person's public key is
missing, stops before anything is rented and prints the line to paste and where in Scaleway's
console it goes.

**What it costs:** a one-time paste in Scaleway's console per ssh key before the first `up`.

## The host key is made by `porelo-host` and kept in the server's tag

Scaleway's Elastic Metal API reports no ssh host key for a server, and a keyscan trusts whatever
answers first on the network. Before renting, `porelo-host up` makes an ed25519 host key pair with
`ssh-keygen`, passes the private half to cloud-init in `ssh_keys`, and stores the public half in
the server's tag `porelo-host-key=<base64>`. Every later `up` and `down`, on any computer, reads
the public key back from that tag and pins it in a `known_hosts` of its own before `ssh` connects;
a server that offers another key is refused before any login.

## A server without the project's tag is never given back

`porelo-host` tags the server it rents with `porelo-project=<name>`, and both a second `up` and
`down` find the host by that tag alone. Before sending `DELETE`, `release` checks that the server
carries a `porelo-project=` tag and refuses any server without one, so a server in the same
Scaleway project that `porelo-host` did not rent can never be deleted by it.

## No Scaleway secret is on GitHub

GitHub holds no Scaleway API key: the Build runs the Scaleway adapter against recorded answers and
the host play flow against a local VM, and one real `up` and `down` at Scaleway is run by hand per
release of the package. Keeping the key off CI means no workflow can rent bare metal or reach the
Scaleway project.

**What it costs:** a change in Scaleway's API is caught at the release's real rent rather than in
the Build.

## The interface calls the `porelo-host` its own package ships, by path

The Linux packages install `porelo-host` at `/usr/lib/porelo-frontend/porelo-host`, and the Windows
ZIP and MSIX place `porelo-host.exe` beside the interface, compiled from the same commit with the
package's version baked in; the packaging refuses a binary that reports another version. The
release's collection tarball is packaged beside `porelo-host` for the setup adapter. The interface starts `porelo-host` by that path,
never by `PATH`, so neither an older copy on the machine nor a binary placed earlier on `PATH` can
stand in for the one built with the interface.

## An agent on a host is signed in at task start, and every ssh trusts only the key `porelo-host` pinned

`porelo-host up` installs agents and starts no task; when it finishes, the host is added as a
machine and an agent is signed in there when starting a task needs it, through the existing
machine sign-in and its reply forward. Every SSH connection uses the person's identity and trusts only
the accepted host key, refusing to scan or trust another key on screen: one sign-in
path for every machine, and no on-screen trust of a key nobody checked.

## Tresorit's installer runs only when signed under a pinned CA, checked on the machine

**What holds.** Tresorit serves one Linux installer at a fixed address and replaces it without notice, so it cannot
be pinned by its digest. Its line 2 is an RSASSA-PSS SHA-512 signature over everything from line 3 on, and line 3 is
the signing certificate with the CA that issued it. The machine wizard's drive step installs the client for a user
only when that CA's SHA-256 fingerprint is the pinned one, the CA issued the certificate, the certificate is made for
code signing and both are valid now, and the signature covers the file from line 3 on as it is. Lines 1 and 2, which
the signature does not cover and the file runs from, may only be `#!/bin/sh` (or `#!/bin/bash`), a comment to the
shell, and `SIGNATURE=` with hex, an assignment, checked here and again on the machine. The installer's own
`CHECKSUM` is a CRC and is not relied on.

**Where each check runs.** This desktop fetches the installer, splits lines 2 and 3, and takes from the chain exactly
the certificate with the pinned fingerprint, which needs only the SHA-256 the interface has. The rest runs on the
machine, as the user the client is for, with its own `/usr/bin/openssl`: `verify -partial_chain` against that one CA
alone, the extended key usage, and `dgst` with PSS over the file from line 3 on. Only then does the installer run, as
that user, never as root or Porelo's account; the folder it was sent to goes on every ending. Every machine Porelo
sets up is Ubuntu or Fedora, which carry `openssl`; this interface's own cryptography reads no certificates and has
no RSA-PSS, and Windows desktops set up machines too.

**Where the pin comes from.** The fingerprint of "Tresorit Code Signing CA 2020" was read for the host's drive, from
the installer as Tresorit's site serves it, fetched twice by separate ways, by curl and in the operator's browser,
both byte-identical. Tresorit publishes no fingerprint that could be read instead. The CA's root, "Tresorit Root CA
2014", is not in the file.

**What would change the answer.** A fingerprint Tresorit publishes, which then replaces the one read; a new CA when
this one expires at the end of 2029, which stops the drive step, naming the pinned fingerprint, until the pin is read
again in the same way.

## A task's program may write this computer's clipboard, never read it

**What holds.** In a task's terminal, what the program copies itself (OSC 52, as tmux's copy mode sends it with
`set-clipboard on`), up to a megabyte, is held and asked about in a bar under the terminal, with its size and a preview
that shows line breaks and every character that would not show, and reaches this computer's clipboard only on *Copy*.
**No write goes through without a word**, not even one of exactly the text the person just dragged across: no program
in the task is told of a drag this window selects itself, so a write that matches it is a guess, or text the task
staged on the screen for the person to drag, which no reading of the screen can tell apart. A request to read the
clipboard is never answered, since that would hand whatever was copied here to the container.

**The accepted risk:** text the person allowed with *Copy* lands on the clipboard and may be pasted elsewhere later;
the preview is what they judged it by. It stays because copying out of tmux is otherwise impossible while tmux takes
the mouse, and other terminals allow the same write without asking. The window's own copy keys copy its selection
without a question, and a paste into the interface's own terminals goes to the task it came from. What would change
the answer: copies asked about so often that people allow them without reading.

## Each repository's agent is started one after another

**What holds.** *Start an agent for each repository* starts one attended task per repository that names an agent,
one after another, each with `now: true`, and a refusal stays that row's answer without stopping the others. A
repository whose agent already runs in an attended task is not started again; a stopped one is brought back with its
session (`RESUME`), and the summary says it continues. Leaving the wizard does not cancel a start in flight, since
cancelling `Start`'s stream may stop a task half made; the wizard says the start may keep running.

## Host joining uses verified signed state and SSH

Host and project actions use the current person's agent identity and Core's accepted host and project-admin
signers. Retired VPN, local trust, host-secret and laptop-key setup paths are removed. The typed replacement
boundaries fail before an operation starts when their served implementation is unavailable; fakes do not
establish interoperability.

Legacy rental recovery keeps the validated provider project and original rental identity. An old key is
never used to resume setup or connect. Give-back requires explicit confirmation and a successful provider
result before recovery is removed. Existing system trust and network artifacts are not automatically deleted:
removal needs an ownership check so unrelated configuration is preserved.

An ssh to a host that the interface starts takes `IdentityFile=none` and its own configuration, never a forced
`IdentitiesOnly=yes` without a named identity, which would shut out the agent's key too. A person's own
`GIT_SSH_COMMAND` for the registry checkout is kept as it is: its shell syntax cannot be rewritten safely, so
non-interactive ssh stays that command's own concern; without one, `ssh -o BatchMode=yes` is used. The central
forge token reaches the host's push or pull only as the bare line on that command's standard input, read from the
secrets file inside a terminal; it is never on a command line, in a file, or in this program.

## One set of servers, called machines, and two lists of them

To a person there is no difference between a host and a machine, so nothing a person reads says host; *SSH host key* stays, as
ssh's own term a person compares. *Organization* lists every machine of the organization and is where a machine is connected,
prepared and managed. *My machines* is the person's own list, of those they connected to or added, and it is not joined from the
organization. A server has one page, from either list.

Taking a machine down has two names, as it means two things: *Take Porelo off this machine…* where the machine simply exists,
and *Return this rental…* only where a saved rental stands. Every machine prepared now simply exists, as `up` rents nothing
until 0.9.

*Connect* stands on a machine's row in *Organization* and on a project's row, and connects at once. *Disconnect* ends this
computer's connection and asks nothing, as *Connect* undoes it: the machine stays under *My machines*, and nothing connects
to it by itself, after a restart either, nor does *New work* offer it. *Forget* takes the entry off the person's list and
leaves it in *Organization*, warning a machine's admin first that the server keeps running. This computer's own machine is
never disconnected or forgotten. A machine added over ssh or WSL is private: it stands only under *My machines*, and
*Forget* deletes it. A machine's row says *Connecting…*, connected or the refusal, never a forward, and a retry after a
refusal keeps the refusal on the row. Taking a machine down names the projects still on it, says that only what reached
the central forge is safe, and stays possible. A Machine Admin with no record on this computer is offered it by the
organization's card, and is told what is missing where the card is not enough.

**What it costs:** a person who wants to work on a server connects to it first, and only then finds it under *My machines*.

## A row's actions are behind one menu, and a page's lists are cards

Every row of *Organization*, of a machine's page and of a project's page holds its actions in one ⋮, as *Machines*,
*Projects* and *Forges* already did, because a row with five actions is wider than the pane. One stands beside the
row: *Connect* while not connected. A person sees only the actions
of their roles, so a row with none shows no menu, and what cannot be run stays greyed with its reason. What adds to a
section, and *Add me*, is on no row and stays visible.

A page of several lists draws each as a card: a header band with its title and count, a magnifier that opens its filter,
and a sort menu, by name and by state, and by machine for projects, the choice kept per list. No card starts folded
because it is long.
An empty one starts folded, its count 0 and its head's actions still usable; it folds when emptied and opens with its
first row, unless the person folded or opened it, which the window keeps until it closes.

**What it costs:** an action is two clicks and cannot be seen at a glance. Tabs or a table sort more naturally, but hide
the rest of the organization or cut off a row's words, which a person's roles need.

## A change that adds to or takes from a list closes onto a provisional row

Adding or removing a member, a repository, a project, a machine or an owner closes its dialog at once, and the row stands
marked as running until the source has answered and the page has read again. A refusal stays on that row in the
source's words, with a way to ask again or to drop it. A change with no row of its own, such as an address or *Create the
organization*, keeps its dialog and says what runs, through the reads after it. Nothing is shown as done before the
source's own answer.

**What it costs:** a refusal outlives the page, so it is kept with the organization per project. One change runs at a
time, so the others wait visibly. Closing the window mid-change loses what makes asking again safe, and the page then
reads what stands. None of it shortens the wait, which is the forge's.

## Each organization role answers for the one below

Owners answer for owners and Organization Admins. An Organization Admin answers for cards, projects, machines and the
admins of projects and machines. A Machine Admin answers for the machine's card, the projects it carries, its token and
taking Porelo off. A Project Admin answers for developers, repositories and the project's address. Each level may create,
change and delete in the one below, and the owner acts rarely. A Project Admin or a Machine Admin names no further admin of
their own level, which the Organization Admin does under *Organization*. A machine leaves the organization by its Machine
Admin or an Organization Admin.

A project is put on a machine, and taken off it, from the organization's row of that project, by that machine's Machine
Admin alone. An Organization Admin does it by first naming themselves its Machine Admin, a signed change like any other.
The machine's page lists its projects read only: it answers whether the machine carries one, and is no second way to
change it. A Machine Admin changed or replaced by an Organization Admin takes effect on a running server at its next
follow, without the former admin's confirmation. While `porelo org` names no `organization_admins`, owners act as
Organization Admins.

**What it costs:** a Machine Admin who is in no project of it reaches that project only from *Organization*, as
`porelo project show` keeps a non-member out of *Projects*.

## Planning is porelo-planner's, and the window keeps none of its own

The board, its moves, a story's work and their screens are porelo-planner's, written once in its Flutter package and
tested there without Porelo. The window embeds that package and answers its hooks: where the planner listens, a start
on a machine, the window's place, its opener and its commands.

**What it costs:** a change to the planning screen is the planner's to make, and reaches the window only when the pin
moves; the window's planning tests run on the package's stand-in source.

## A planner the window started ends with the window

A planner the window started because none was serving lives only as long as the window: the window holds its input,
whose close ends it, and the window's clean ends stop it. A planner that served before the window started is left
running, and so is one that took the started one's place.

**What it costs:** a planner the window started no longer serves the account's other windows and tools once that
window ends; they find or start their own.

## The window carries ideas to the planner

The planner runs on this computer and talks to no Porelo, while the ideas it plans come from tasks on machines, a rented
host as often as not. The window reaches both, so it carries them: the idea file an ended discussion names, read from
its machine with `Result` and handed as `POST /projects/{project}/ideas` with the offer it came from, and each idea a
task on a watched machine proposes, handed as a new issue in Idea of the task's repository and then taken from its task
with `TakeIdea`. Each is handed once, also across restarts, by a mark kept in the settings.

**What it costs:** an idea reaches the planner only while a window runs. The planner's new issue takes no key that makes
a second send harmless, so a window that ends between the planner's save and its mark hands that idea once more at its
next start. Against a Porelo without `TakeIdea` the idea stays on its task's row, and the window logs it.

## The planner is given the one Porelo the window vouches for

The planner lends git the account's forge tokens through Porelo (`vault credential --for <url>`), so it runs the same
`porelo` the window does. The window looks for it once at start, at two places only: the account's own install,
`porelo` in the local `bin` folder of the home directory, then the package's, `/usr/bin/porelo`. The first where anything lies decides, its links followed.
The planner it starts gets that path as `PORELO_EXECUTABLE`, any inherited value dropped. The path is given only where
the file and every folder up to `/` are owned by root or the person and writable by nobody else but the person's own
private group: their primary group, which no other account has as its primary one and which `/etc/group` lists with no
other member. Off Linux the variable is left unset.

**What it costs:** a Porelo installed elsewhere, as under `/opt` or by Nix, is not found, and a refused one is said only
in the window's log; the planning then reads public repositories only. Accounts and groups known only through NSS (LDAP,
NIS) are not seen, so a folder their group may write is refused.

## A task on a host is certified by this computer's agent

A host starts no task without a certificate for that task's own key. The window asks for it in `Start` itself, and
this computer's ssh agent signs. The window never starts through the command line and never forwards the agent:
`ForwardAgent=no` stays. Before signing, the window checks what the host asked for, as the command line does: one
Ed25519 key, the principal `task:<project>:<task>` of the start the person asked for, and at most seven days.
Renewing runs `porelo task certify` here, since only the command line asks the agent for that.

**What it costs:** a card key missing from the agent stops the start; the window names the key beside the start.

## An organization may be created at an https address

A machine follows a Porelo organization with an ssh key of its own, so it cannot follow one at an https address. Creating
one there is still allowed: once such an address is typed, the dialog says that no machine can follow it and asks for the
ssh form, and preparing a machine later names Core's way to move it, `porelo setup --organization <its ssh address>
--replace`. It is not refused, as that stops a person who needs no machine, and not converted, as that needs an
authentication key the person may not have.

**What it costs:** a person who wants a machine later moves the organization first.

## The side bar is a folding tree, and only a leaf shows a list

The side bar folds open to each machine and each organization, and those to their sections, so a machine's vault or an
organization's people are reached in a few clicks and never through a menu; a section opened under a machine shows that
machine's, whichever is current. An entry with entries under it shows facts and actions, never a list of what is under
it; only a leaf lists, under one head: the path line, a large title, a subtitle counting every row, a filter and its
main action. An action with no command yet is a greyed, dashed button saying that it waits for one. The fold and the
chosen place are kept across a restart, and a first start unfolds *My machines* and the current machine. The side bar
stands beside the page from 600 wide and is a drawer only below; the stop for every machine stays in the title bar at
every width and never goes into its overflow.

**What it costs:** a section's action is a click further than in a machine's menu, and the tree grows with every
machine and organization, so it scrolls under its foot.

## The scenarios' stub agent is pinned by version, and a warning says when to move it

The stub agent the scenarios fetch is a named version, in
`integration_test/step/the_test_machine_has_porelos_stub_agent.dart`, so a run can be repeated; reading the newest from
its folder's listing was not taken. The folder on Artifactory keeps the newest 20 versions, and its retention stays as
it is: `tool/stub_pin.sh`, run by `tool/e2e.sh` before every run, says when the folder no longer holds the pin or holds
15 or more newer versions, and never stops a run.

**What it costs:** the pin is moved by hand, before 20 Builds on `main` have passed it.
