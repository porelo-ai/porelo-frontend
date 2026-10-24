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
| [A project comes to a machine only by being followed](#a-project-comes-to-a-machine-only-by-being-followed) |
| [A project's settings are changed only in its repository; the window never writes a `project.yml`](#a-projects-settings-are-changed-only-in-its-repository) |
| [A machine is pinned to every signing key the forge lists for the person](#a-machine-is-pinned-to-every-signing-key-the-forge-lists-for-the-person) |
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
| [A tile shows the last lines its agent wrote, read now and then](#a-tile-shows-the-last-lines-its-agent-wrote-read-now-and-then) |
| [One session at a time, shown only where it was opened](#one-session-at-a-time-shown-only-where-it-was-opened) |
| [Handing off work from another device needs no feature of its own](#handing-off-from-another-device-needs-no-feature-of-its-own) |
| [The settings file is written atomically and owner-only, and a bad entry is dropped rather than fatal](#the-settings-file-is-written-atomically-and-owner-only) |
| [What was run is kept for thirty days in one owner-only file, and an unseen failure still waits](#what-was-run-is-kept-for-thirty-days-in-one-owner-only-file) |
| [The new-machine wizard may use root once, inside the wizard, and never stores it](#the-new-machine-wizard-may-use-root-once) |
| [A forge's token stays on this computer; a machine gets deploy keys of its own](#a-forges-token-stays-on-this-computer) |
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
| [Secrets reach the host only on standard input: the drive's password and one-time code, and the vault's passphrase](#secrets-reach-the-host-only-on-standard-input) |
| [No Scaleway secret is on GitHub: the Build tests against recorded answers, with one real rent per release](#no-scaleway-secret-is-on-github) |
| [The interface calls the `porelo-host` its own package ships by path, never by `PATH`](#the-interface-calls-the-porelo-host-its-own-package-ships-by-path) |
| [The host's files reach it through Tresorit, and the person's WireGuard key stays in the secret store](#the-hosts-files-reach-it-through-tresorit-and-the-persons-wireguard-key-stays-in-the-secret-store) |
| [An agent on a host is signed in at task start, and every ssh trusts only the key `porelo-host` pinned](#an-agent-on-a-host-is-signed-in-at-task-start-and-every-ssh-trusts-only-the-key-porelo-host-pinned) |

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
  login is refused, the refusal is explained in plain words beside the machine on *Machines* as well
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

A private key sent from here goes into the machine's vault, and never into `~/.ssh` there. Only the
private half is asked for, because the machine works out the public half. A key that is already in
`~/.ssh` is chosen where it lies, so the case of a key in `~/.ssh` is covered without this interface
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

## A project comes to a machine only by being followed

A project is a repository a machine follows. Its `project.yml` lives in the project's own
repository, and a machine gets the file only by following the repository; what is wrong with it
comes back as the machine's named reasons, never as rules worked out here. How a followed
repository's commits are checked — a pinned key or unverified — is chosen in the dialog and never
defaulted. Removing a project is *Stop following*.

## A project's settings are changed only in its repository

The window never writes a `project.yml`: the file in the project's repository is the one source of
truth. A repository without one is said to be no Porelo project, and nothing is offered for it. What
a project may reach is shown, with where each host comes from, and said to be changed only in its
`project.yml`.

What stays in the window is what is no setting of the project: letting running work reach a host it
was refused, for that run or that work; the brake on a project's messages to a peer; and binding a
machine, which gives it deploy keys at the forge and its line in `machine-signers`.

**What it costs:** a project is made and changed in YAML, in an editor of the person's own.
Accepted, because a second way to write the file would be a second source of truth.

## A machine is pinned to every signing key the forge lists for the person

The person's signing key is found, never chosen from every key the ssh agent holds: the SSH signing
keys their forge account lists, and git's `user.signingkey`, marked as theirs. Binding a machine
pins it to all of them at once, and asks for no key again; any other key is offered only after
them, as *another key*. Signatures are ssh signatures, never GPG.

**What it costs:** a signing key added at the forge later is trusted by a machine only after the
project is followed again.

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
under *Set up* *Machines*, *Forges* and *Projects*, with the refresh and the stop for every machine
at its foot. **The window opens on *Work***: every piece of work on every machine, grouped by what
it asks, each tile naming its machine, narrowed to a machine, a project or work in no project.
Work is shown only there; a machine's or a project's page leads to it, narrowed.

- ***New work*** asks where it runs when more than one machine answers, then in which project or in
  none. Where the project has work with a conversation on another machine, it says before the start
  that the two cannot talk.
- ***Machines*** and ***Projects*** list them, each opening a page of its own with its tools.
  *Projects* lists no *Default*: work without a project starts under *Work*, and a repository is put
  into it from its card on its forge's page.
- ***Forges*** lists every forge set up on this computer; a forge's page lists its repositories with
  a filter, each card saying on which watched machines it is worked on.
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

**A question that was answered or ran out stays, with its outcome, until it is put away** with *Got
it* on its tile: a question that ran out while nobody looked would otherwise leave the view without
a trace, and the confirmation of an answer would vanish with the click that gave it.

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
activity: such a task is never said to be working or idle, and its tile on *Work* never folds. An
agent that finished its prompt needs nobody and is not listed.

## Needs you has ranks, and a question with a deadline is always first

Tiles order by what they are — an open question, then an agent that ended, then work at the gate,
then working, quiet, unseen and stopped — and within a rank by the nearest deadline, a question with
none sorting after every one that has one, then by the oldest question.

**So a week-old review can never sit above a question with two minutes left.** The count the view
shows is questions and silent machines only: work at the gate can wait for days without anything
being wrong, so it is listed and not counted.

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

## A tile shows the last lines its agent wrote, read now and then

Each unfolded tile on *Work* shows about five of the newest lines its agent wrote, formatted rather
than raw JSON, in a small console under its name; one press enlarges it to the log view on the
right, following, and one press makes it small again. It reads only the end of the log (`Tail` with
`last` and `formatted`, asked only where the machine takes them), is redrawn at most every three
seconds, and a folded tile reads nothing. Work in a terminal shows the session's last lines
through `Screen`, without attaching, in the terminal's own look. When an unattended run's agent has
ended, a line under the console says whether it finished or stopped before its end, whether its
work waits at the gate, and where to go next: the review at the gate or the output above it.

**What it costs:** an unfolded tile reads even while it is scrolled out of view; folding it is what
stops the reading.

## One session at a time, shown only where it was opened

Two sessions over one terminal make leaving one look like leaving both, a session filling Running
leaves no room to open a second, and a session that follows nobody's place is lost from view by
going elsewhere and back. So:

- **One session is open at a time.** Working by hand in other work leaves the one that was open,
  without asking: nothing at the far end stops, and opening it again shows its last lines. The status
  line says which was left.
- **It belongs to the place it was opened** — Needs you, a machine's Running, or one project — and is
  shown only there. Going elsewhere leaves it running out of sight; coming back finds it as it was.
- **Leave is the only way out of it.**

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
`$XDG_STATE_HOME/porelo/operations.json` (`~/.local/state/porelo/operations.json` without it), and
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

A person's forge token is kept in this computer's keychain and reaches git through its environment,
never a command line, a file, the settings or a machine. A machine gets a deploy key of its own for
each repository it works in, titled after itself, read-only for a project's own repository and with
write access where its work is pushed; its forge login is nobody's.

**What it costs:** the token needs the forge's right to manage deploy keys (*Administration* at
GitHub), which is more than reading and writing code. Accepted, because the alternative is giving a
machine the person's token.

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
says will go, then clear it with one press. The machine removes what Porelo put there; the interface
removes each deploy key it names at the forge with the person's sign-in, and the machine's line in
each project's `machine-signers` in one signed commit. One report says, thing by thing, what was
removed and what was left and why, and one refusal does not stop the rest.

## A person joins a project's conversation by an account made for them

A person takes part in a project's Matrix conversation from a client of their own, through an account
the machine makes for them. Its login is shown once, whole and selectable, and kept nowhere; a
second join offers a new password.

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
- The follow form keeping a machine's typed text after switching to another: switching rebuilds the
  form; on the same machine keeping it is the feature.

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
to give it back knowingly. The test script says a host kept so as plainly.

**What it costs:** a host kept goes on billing until somebody looks, and the person who closed the
window may not. The other way, giving back whatever the play answered, ends the bill but can take
the only copy of a project's data with it. The operator chose the data, with the bill said plainly.
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

## Secrets reach the host only on standard input

When `up` resumes after its stop (`--answers-on-stdin`), it reads the drive's login and the vault's
passphrase from its own standard input and sends them on to the host over `ssh` on standard input
alone. `tresorit-cli login --password-on-stdin` receives the password and, when the account uses a
second factor, the one-time code as the line after the password on the same standard input, never
through `--totp` or another argument; the vault receives its passphrase through `--passphrase-stdin`.
Neither secret is ever put in an argument, an environment variable, a file or a log on either
computer.

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
interface starts `porelo-host` by that path, never by `PATH`, so neither an older copy on the
machine nor a binary placed earlier on `PATH` can stand in for the one built with the interface.

## The host's files reach it through Tresorit, and the person's WireGuard key stays in the secret store

When a local Tresorit folder is chosen for a project, the interface writes the host's machine file,
any copied keys and the host's private WireGuard key there without replacing differing files or
following links. The person's private WireGuard key stays in the system secret store and is written
out only when the person exports it. That gives the host its key without a secret on a command line
or in a log, while the person's own key never travels.

## An agent on a host is signed in at task start, and every ssh trusts only the key `porelo-host` pinned

`porelo-host up` installs agents and starts no task; when it finishes, the host is added as a
machine and an agent is signed in there when starting a task needs it, through the existing
machine sign-in and its reply forward. Every ssh to a host uses the setup identity and trusts only
the host key `porelo-host` pinned, refusing to scan or trust another key on screen: one sign-in
path for every machine, and no on-screen trust of a key nobody checked.
