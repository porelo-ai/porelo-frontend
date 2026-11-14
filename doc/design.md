# Design

How this interface is built. The requirements say what must be true for a person using it; this
says what it is made of. One section per decision, each with the reason it was taken — a decision
without one gets re-argued every time somebody new reads it.

## Flutter

- **Language:** Dart 3.13, Flutter 3.47 stable. Pinned in `pubspec.yaml` once the app exists;
  until then these are what the decisions below were taken against.
- **UI:** Flutter, one codebase for desktop and tablet. **Linux desktop is the only target that
  works today** — the backend is a unix socket, so a client has to be able to open one, and a
  phone cannot without a tunnel it has no way to raise. Phone is not designed out; it is simply
  not reachable until there is a way for a device without a shell to get
  a socket, and the layouts do not assume it never will.
- **Contract:** the Porelo backend and its API contract — the varlink interface
  `org.fuin.porelo.Tasks1`, over one unix socket. **No REST, no HTTP, no shared code with the
  backend at all**: the only thing crossing the boundary is the IDL, which the daemon serves
  from itself. See [Backend API](Backend-API.md) before writing a call.
- **Client:** hand-written, in one package, against the contract. There is no varlink code
  generator for Dart and the protocol is small enough — a socket, JSON objects, a NUL between
  them — that generating it would be more machinery than it saves. Whether that stays true once
  every method has a typed request and reply is the open question below.
- **Auth:** **none, and that is the design.** The socket is owner-only, so the filesystem decides
  who may connect and there is nothing to log in to. A remote backend is an SSH forward, so its
  authentication is SSH's. A design that needs a token, a session or a login screen means
  something has gone wrong upstream of it.
- **Build:** **Maven drives Flutter here.** A `pom.xml` in this repository calls `flutter` through
  `exec-maven-plugin` — `pub get` in `generate-sources`, analyze and the tests in theirs,
  `flutter build` in `package` — with a profile keyed on `env.FLUTTER_ROOT`, so a machine without
  Flutter still builds.

  **What it costs is a JDK.** The interface builds, tests and releases on its own, and needs a JDK
  to do it, for one reason: an end-to-end test that drives this interface against a real machine
  has to lease one, and leasing is `org.fuin.porelo.machines`, which is Java. With Maven here it is
  a library call; without it, a downloaded jar and a command.

  **This repository is still not in the backend's reactor.** It resolves `porelo-machines` as a
  published artifact like any other dependency. The split that matters — that the interface
  releases on its own schedule, against a published contract rather than a checkout of the
  backend — is unchanged. What changed is the tool that runs the build, not who owns it.
- **Test:** `flutter test`, and **`dart analyze` at "No issues found!"**, failing the build on any
  finding. It is `dart analyze`, not `flutter analyze`, which rewrites `analysis_options.yaml` with
  an exclude block that silences findings instead of fixing them.

## The terminal, and the only dependency there is

A session inside running work needs two things this codebase did not have: something that
understands escape sequences, and a pseudoterminal. They were decided separately and the answers
are different.

- **`xterm` from pub.dev draws it, and it is the first runtime dependency here.** Everything else
  is hand-written against a contract — the varlink client included, because that protocol is a
  socket, JSON and a NUL. A VT emulator is where that argument stops holding: cursor motion, an
  alternate screen, scroll regions, colour, wide characters and reflow are not a small protocol,
  and getting one subtly wrong is the failure the requirement was about — colours work, and then
  `Ctrl-C` ends the wrong thing. It is pure Dart, so it changes nothing about the package.
- **The pty is ours, written with `dart:ffi`.** The usual companion, `flutter_pty`, is a native
  plugin, and a native plugin is another `.so` in the bundle. Every `.so` in the bundle goes
  through `dpkg-shlibdeps` and the rpm scanner and comes out as a package dependency, which is
  the chain the packaging requirement was about — met and retired — and the most delicate part of shipping this.
  `dart:ffi` is in the SDK and costs the packaging nothing.
- **Nothing forks.** The obvious shape is `forkpty` and then `exec` in the child — and the child
  returns into the Dart runtime, in a process whose other threads no longer exist. `posix_spawn`
  with `POSIX_SPAWN_SETSID` does both inside libc, and the child takes the terminal by opening it
  as a session leader, so no Dart code ever runs in a forked process.
- **A blocking `read` needs somewhere to block.** `dart:io` cannot wrap a descriptor it did not
  create, so an isolate sits in `read(2)` and posts what it gets. It reaps the child too, so a
  session that ends leaves no zombie.
- **The terminal holds the frame's keyboard for what is open**, rather than the frame holding it.
  Every other thing that opens over the frame is read rather than typed into, so the frame keeping
  the keyboard costs them nothing; a terminal is the opposite. With the frame holding it `Escape`
  closed the pane and never reached the far end, which would have made `vim` unusable inside a
  session.
- **What cannot be faked is tested against the kernel.** `test/app/pty_test.dart` runs `stty size`
  in a pty and reads the answer back, which proves the controlling terminal and the window size in
  one line. Everything above the byte channel is proven through a seam, on the fake clock, like
  the rest of the interface.

## Testing

Tests are written as Gherkin `.feature` files and run as ordinary Flutter widget tests, via
**[`bdd_widget_test`](https://pub.dev/packages/bdd_widget_test)**, which generates the tests from
the features.

- **Why that one, measured rather than assumed.** It is the only live option in this space:
  `sdk: ^3.7.0`, 63k downloads, 181 likes — against `flutter_gherkin` (declares `sdk: <3.0.0`,
  changelog ends May 2021, pins `gherkin ^2.0.2` while that is at 3.1.0, drags in the legacy
  `flutter_driver` stack), the `gherkin` package itself (`sdk: <3.0.0`, changelog ends July
  2022), and `bdd_flutter` (41 downloads).
- **It generates real tests, which is the whole point.** A feature becomes a `group` and each
  scenario a `testWidgets`. Every other Gherkin option for Dart is a *parallel runner* with its
  own reporters — `flutter_gherkin` contains no `testWidgets` and no `group` anywhere — so its
  scenarios never become `package:test` events, never reach JUnit XML, and never appear
  individually on a build server. That single fact decided this.
- **Results on the build server:** `tool/test_report.dart` reads `flutter test --machine` once and
  writes the HTML page, JUnit XML grouped by feature, a table on the run's summary page, and an
  `::error` on the line of each failing scenario. Why each is shaped that way is in
  [AGENTS.md](https://github.com/porelo-ai/porelo-frontend/blob/main/AGENTS.md), under *What the build reports*.
- **The `Feature` line says what the file tests**, in one short sentence of 70 characters at most.
  It is the group name in every report, so a reworded scenario never moves a row.
- **Steps are shared by name.** `Given the app is running` resolves to
  `test/features/step/the_app_is_running.dart` across every feature that uses it, and the generator
  scaffolds the file the first time. So step wording *is* the API: phrase a step the way you
  want to reuse it, and vary the data rather than the sentence.
- **Names are checked, not maintained.** `test/features_named_test.dart` holds every `Feature`
  line to one short sentence, unique, with no requirement id in it, and `test/docs_test.dart`
  holds these documents to files that exist. A table nobody checks is a table that lies.

A green row is not completeness: a feature with one shallow scenario shows as green as one
with twelve. Only reading the scenarios fixes that, and no framework changes it.

**Generated tests are committed**, formatted as the rest, and the build runs `build_runner` and
`dart format` over them and fails on a diff. Left
out, a build that did not generate them would find no tests and report green; committed and
checked, they cannot drift or silently vanish.

### How it is laid out, as measured

- **`test/features/*.feature`**, with step definitions in **`test/features/step/`** — beside the
  feature, not in `test/step/`. The generator scaffolds a stub there the first time it meets a
  step, referencing `MyApp`; replace it. A stub left unreplaced fails to compile, which is the
  right way round.
- **Generated tests land beside their feature** as `<name>_test.dart`.
- `dart run build_runner build && dart format test/features integration_test` after adding or
  editing a feature: the generator writes its own layout, which the format check refuses. Its
  `--delete-conflicting-outputs` flag has been removed and is silently ignored.
- `avoid_print` is disabled per-file in `tool/contract.dart`: it is a command-line tool and
  printing is its output. That is the only lint exception, and it is stated in the file.

### A move rehearsed in the window

`tool/rehearse_window.sh` drives the main scenarios of a move through the real window, unattended,
against a rented host that is already set up, acting as one test person; the scenarios are
`integration_test/rehearsing_a_move.feature`, and each step checks on the host itself, over the
contract or `porelo build status`, what the window made happen.

- **The window runs in a local VM with no desktop**, under `xvfb-run`, so no window, notification
  or keyboard focus reaches a person's display. `check` names what the VM lacks and the line that
  installs it; `run` copies HEAD there, fetches the pinned Flutter against its published digest,
  trusts only the host key it is given, and forwards the test person's ssh agent for the run alone.
  The key never enters the VM, and no token reaches a command line, a log or the report.
- **The report** is `scenarios.txt`, one `OK`, `FAIL` or `SKIPPED <name>: <why>` line per scenario
  from `tool/test_report.dart --lines=`, beside the HTML and JUnit report and a picture of the
  window for every failed scenario (`pictures/<scenario>.png`, drawn from the window's own root
  layer). The run exits 0 only where no scenario failed and one ran; the window's part stops after
  `--budget-minutes`.
- **The host's key** shown on the host's page is compared with the one read from the server as
  root; a mismatch fails the run.
- **An agent's sign-in** is driven up to its terminal showing the provider's link; the browser login
  is not driven, and the report says so. A host where the agent is signed in skips it.
- **Not driven:** a grant under *Needs you*, which the run cannot bring about, *Take Porelo off*,
  which would remove Porelo from the rented host, and the gathered push to central, which waits on
  the host taking the central token from the person's vault; each is named in the report as not run.

### An idea walked in the window

`tool/walk_idea.sh` walks a real idea through the real window to its story Finished, in a local VM under `xvfb-run`
against that VM's own `porelo` and a given planner; the steps are `integration_test/walking_an_idea.feature`, and each
reads its effect on the board, in the repositories and on the forge, never in what the window says of itself. A run
works in repositories of the test organization made for its story, deleted whole when it ends; a red step keeps them,
and the VM's state, for `resume` or `clean`. The script's head says what each command takes and needs.

## The mock backend

A mock daemon — a small Dart program binding a real unix socket and speaking real varlink. The
app's own client runs against it unchanged, because the socket path is the only thing that
differs. That is the same property that makes a remote backend work, so the mock costs nothing
extra to reach.

**It is permanent, not scaffolding until the backend is ready.** It produces states a real
daemon cannot be made to produce on demand, and those are the hard requirements:

- `MethodNotFound`, to prove per-feature degradation against an older backend. A real daemon
  always has all its methods, so this rule is otherwise unenforceable.
- An unrecognized `Outcome` value, to prove the tolerance rule. A real daemon only ever sends
  values it knows — and a generated Dart enum with no fallback case is exactly how this breaks.
- `GetInfo` advertising `Tasks2`, to prove the client picks the highest name it understands.
- A stream cut mid-flight, for the requirement that tunnel loss reads as disconnection and never
  as an empty fleet.
- `HOLDS_WORK` on demand, without contriving a task that genuinely holds unpushed commits.
- A four-minute image build, and a clearance prompt with a live deadline.

It also means the test suite needs no podman, no containers and no Linux host with a runtime —
so it runs on any hosted runner.

- **Scenarios are named for the situation, not the requirement** — `task-holds-unpushed-work`,
  not `f09-case-2`. A finished requirement is deleted; the situation and the test guarding it
  outlive it.
- **Events are driven by the test, never by wall clock.** Otherwise stream tests are flaky, and
  flaky tests get deleted.
- **Drift is caught by one CI job with a real daemon**: install the `porelo` package, start
  `porelod`, compare the mock's method and field set against `GetInterfaceDescription`. The mock
  proves the client handles what it is sent; that job proves the contract is what we think it is.
  Neither substitutes for the other, and a drifted mock is worse than no mock.
- **Watch the socket path length.** Unix paths are limited to about 108 bytes on Linux and
  temporary directories in test harnesses get long enough to hit it.

## Packaging

On Linux, delivered as a `.deb` and an `.rpm`, from the same repository as the `porelo` package —
The packaging requirement is met and retired; this is what it is made of.

- **Output:** `flutter build linux --release` produces a bundle directory — the binary,
  `lib/libapp.so`, `lib/libflutter_linux_gtk.so`, `data/`. Measured at 22 MB and 11 s. The
  package installs that directory, a launcher on the path, a `.desktop` entry and an icon.
- **Dependencies:** derived, never listed. The shipped `.so` resolves the system GTK3 stack, and
  `dpkg-shlibdeps` and rpm's ELF scanner both work that out themselves. A hand-written list is a
  list that goes stale between Flutter releases.
- **Tool:** [nfpm](https://nfpm.goreleaser.com/) — one static binary, one YAML, both formats.
  **Not `rpm-maven-plugin` and jdeb**, which is what the backend uses: those plugins need
  `rpmbuild` on a Debian runner, where nfpm writes both formats from one binary. What matches the
  rest of Porelo is the package a person installs, not the tool that wrote it; that Maven runs the
  build here is no reason to change it.
- **Relationship to the backend:** `Recommends: porelo`, not `Depends:`. An interface talking to
  a remote daemon over SSH is useful with no local backend, and a hard dependency would be wrong
  for that.
- **Where it is published:** into the same Artifactory repository as `porelo` and the agent
  packages. A dependency between packages does not resolve when they are split across configured
  sources — this is recorded in the backend's own notes and applies here unchanged. Each package,
  Windows archive and standalone `porelo-host` binary is uploaded to Artifactory by `curl` with its
  SHA-1 and SHA-256 checksums and the token passed on standard input, with no client downloaded in
  the job that holds the token.
- **Build machine:** Ubuntu, never Fedora, because the bundle links glibc dynamically — the
  backend's own rule. Flutter adds one the CLI never had: the bundle links the GTK3 stack too,
  so the build machine's GTK is the oldest GTK the package can run against, and the build runs on
  the oldest distribution that must be supported. That is `ubuntu-22.04`: measured,
  its packages install on every system Porelo supports, Ubuntu 26.04, Debian 13, Fedora 43 and
  Fedora 44, and the workflow proves that on each build in those four images, pinned by digest.
- **The C library floor:** both packages declare the oldest glibc they need, the `.deb` as
  `libc6 (>= …)` from `dpkg-shlibdeps`, the `.rpm` as `libc.so.6(GLIBC_…)(64bit)`. `tool/package.sh`
  holds it with `porelo-release`'s `check-linkage --declared-only`, as Porelo's own packages hold
  theirs: no object may need a newer glibc symbol than declared, and the floor may not rise above
  Debian 13's glibc 2.41.
- **Architecture:** Flutter has no cross-compile for Linux desktop. Every architecture shipped
  needs a builder of that architecture.
- **Third-party notices:** `tool/package.sh` unpacks the bundle's gzip `NOTICES.Z` into one plain
  `THIRD-PARTY-NOTICES`, installed to `/usr/share/doc/porelo-frontend/` and named in the deb's `copyright`, and as a
  second license file under `/usr/share/licenses/porelo-frontend/` for the rpm, since Fedora has no shared license
  directory; a `NOTICES.Z` that is not gzip, not UTF-8 or empty stops the packaging.
- **The channel a host installs from** follows the `porelo-host` that prepares it: only a plain
  `<major>.<minor>.<patch>`, compiled in from a tag, installs from `releases`; a snapshot, a pre-release or a build
  with no version installs from `snapshots`, and `--distribution` wins. A window run from source passes
  `--distribution snapshots`, since the `porelo-host` it calls is the installed one, of whatever channel.

### Where it lives

**`lib/` at the root, one package named `porelo_frontend`**, organization `org.fuin`, Linux and
Windows the enabled platforms. A `packages/` split pays for itself only once something is shared, and nothing
is; a second consumer of the client code is what would change that.

## Projects on prepared hosts

Host and project actions consume Core's verified person, host and admission state. No wizard asks for host
values, project signing keys, laptop keys or host secrets.

*What does creating it need?*, in the dialog of creating, shows Core's own check of founding at the typed address (`porelo
org create <address> --check`), each need in Core's words with its next step. It is asked on a press, not while typing,
as asking may reach the forge, and it never holds *Create it* back: Core's own creating refuses what it must.

A read of the organization that meets an unknown SSH host key of its forge asks the person in the window: the keys
Core offers (`porelo credentials trust-host <host>`) are shown, to be compared with what the forge publishes; only the
one the person chooses is recorded, and the read is asked once more. A read nobody asked for, such as a timer's, never
asks: it says the key was not trusted, and *Refresh* asks again.

A project is on one host at a time, and a Machine Admin decides which projects a host carries, never which persons: every
member of a project is on its host. *Connect* makes one connection per host, whatever number of projects it carries, from
the address, port and host key in the organization. Other programs read what it writes, so that stays as it is:
`frontend.json`'s `machines` with each machine's `host`, and `porelo/ssh/<host>.conf` and `<host>.known_hosts` beside it,
`<host>` being one lower-case DNS label whatever the address.

A card may name a host name, an IPv4 or an IPv6 address. Two limits stand: a server with no IPv4 default route cannot be
prepared, as the host's own play stops, and on Linux the host vault is not opened from here for a card on another port or at an IPv6
address, as `porelo host unlock` takes neither, which the interface says in words; on Windows the window opens it
itself, over the card's port. A whole preparation given by name, and any
run over a real IPv6 network, have not been tried.

*Bring it to central…*, on a project's page on its host, is the one way the window releases a host's approved main
to the central forge: through the machine's own `PushToCentral`, after the person agreed to the commits it names. The
host refuses what a person's role does not allow, and the page says it in the machine's words.

*Open its forge*, on a connected host's row and machine page, opens the host's forge through the window's forward at
`http://<host>.localhost:<port>/`, or `http://127.0.0.1:<port>/` where this computer has no IPv6 loopback.

On Linux no ssh binds a TCP port of this computer: a card's forge web, Git and homeserver forwards, a joined
homeserver and a sign-in's redirect each go to a Unix socket of the person's own, and the window holds the loopback
port itself (`PersonOnlyRelay`). It relays a connection only when `/proc/net/tcp` or `tcp6` names this account's uid
as the owner of its other end, and closes any other before reading from it; every byte passes as it came. On Windows a
card's ports and a sign-in's forward are still reached by every local account of this computer.

A project's row says how its machine's approved commits stand with the central forge, as the person's own daemon on the
host lists it in `Projects` (each carried repository's `central`, `ahead` and `aheadMeasured`), asked over the person's
connection once it is up: so many waiting, up to date, the forge moved on, or that it cannot say, which never reads as
up to date; ahead by a count nobody gave cannot say either. The answer can be five minutes old and says when it was
read. The row only says it: the
work is brought there from the project's page on its host.

*Set up a machine…* opens for a person the organization names as a Machine Admin of that very machine, judged on what
`porelo org --json` answers, read again before anything happens; a `stale` answer prepares nothing. The wizard asks
one question per page, and a page opens only once the one before it holds: an address answering SSH, a key fetched by
hand and compared on the server, a root login that answers with the card key. It names the person's own key in the
line that lets them in as root, run in a terminal on the server that trusts only the compared key; an address the
person's `known_hosts` holds with another key is said so, and that key goes only once the new one is compared. A key
that changed between comparing and *Prepare* starts nothing and returns to the key's page. Before `up` starts,
the interface writes the machine file whose `organization` part the host reads: the organization's `settings`, the
central forge's lines from the person's own `known_hosts` (first use is not trusted, so none stops here) and a
`login key` pin from every row of `hosts[].admins`, backup keys included; a row with no key refuses the whole pin.
*Run it for me* runs that line from here instead, only at the person's press: over ssh as the first login, trusting
only the compared key, never waiting for input, each `sudo` as `sudo -n`; root's login is tried right after, and where
`sudo` wants a password the terminal on the server is the way.

The wizard opens at the click and does that read inside it, its first *Next* unavailable until the answer and a refusal
shown there. A run belongs to the window, not to its dialog: the dialog says at once what runs and that it can take
minutes, closes while the run goes on, and the machine's row opens the protocol again. No role is given at the interface's
start: what a person is offered follows from the organization's answer alone, and *Set up a machine…* shows for an
Organization Admin, a Machine Admin, or a person who reads no organization yet. Over ssh only the card's key is offered, so that more than
six keys in the agent do not stop `up` at sshd's limit.

When `up` reports the host, its real address, ssh port, host key and service ports go on its card by `porelo org
host change`, the machine is added and followed. The token is a step of its own, on the wizard's last page or behind *Give it your
token…* on the machine's row: it names each source it asked, this computer's Porelo-Vault, the token kept under *My
forges* and the secrets file, with what each answered, and a source that could not be asked is said as that, never as
holding none. Should `up` stop, or the card be
refused, nothing is given back, as `up` rents nothing: it takes only a server given to it, and renting returns as
planned for 0.9, sprint 5. The server stays as it is, and that is said in words. On a given server *Take Porelo off this machine…*
takes the setup off, and releasing it at the provider is the person's own step; a saved rental from before is
released by the provider's confirmation, and a give-back that fails keeps the recovery record.
Before Porelo is taken off or a rental returned, the dialog reads, by `org status` as root, who still holds machine
administration or a project on the machine, and who is locked with a purge day. The host purges only a person locked,
listed in no project, no Machine Admin and past their purge day, so only those are offered: the person confirms the
removal of exactly those named accounts and all they hold, and every other account is named with why it is not offered.
Each confirmed one is purged as root before the down play (`porelo-host person purge`), and the first failure stops the
rest, the play and the release. A
status that cannot be read purges nothing and leaves the ordinary take-down, whose play still refuses while anyone holds a
membership. A holder new after a refused play needs another confirmation, and a failed take-down then offers the one
confirmed as a loss.
Once Porelo is confirmed off, the window removes the machine from the organization's list; a refusal, or no answer within two minutes, is said in the dialog, and the row keeps *Remove the machine…*. SSH forwarding and unlock integration belong to the shared host transport. Provider sign-ins and the
local vault keep their own terminal paths.

A saved rental made before one-click joining stays visible for give-back or setup again. Its provider
project and original rental tag remain readable; retired trust and credential metadata is ignored. An old
machine is never connected with its saved private-key path. Failed or unconfirmed give-back retains the
rental. Explicitly confirmed legacy give-back does not run obsolete backup or teardown credentials and
clears recovery only after the provider confirms removal. Setup again receives that existing rental,
without discarding its recovery record while the replacement flow runs.

- **A ready server's *Run its setup again*** runs `up` once more in the interface's own run, with the arguments its
  setup was made with, so a stop in it is completed from *Needs you* and the server stays listed as ready.
- **`porelo-host find`** asks the provider which server carries the project's tag and prints one JSON line, or exits
  69 when none does; it changes nothing. A guide asks it before it uses an address, since neither the window's list nor
  `known_hosts` tells a given-back server from a live one.
- **The collection is taken only by its digest:** `up` refuses a tarball whose SHA-256 differs from the one it was
  given before anything is copied, and the host checks the copy again with `sha256sum -c` right before
  `ansible-galaxy collection install`, so only Porelo's own tarball reaches an installer that resolves member paths
  without following links.
- **A server is the package's to give back** when it carries `porelo-project=<project>` or, rented with no project,
  `porelo-host=<name>`; one with neither is refused.
- **A project with no Git repository yet** is one whose `opened` is false in `porelo org --json`; an answer without the
  field, or a `stale` one, says nothing of a missing repository. Such a project is on no list of *My projects* or of a
  machine: it stands on the Organization page, where its named Project Admin creates the repository, also from a row of
  *Needs you* that only they get, and anyone else reads who it waits for.
- **A project's page stands at once**, its head filled from what the organization's list holds, while `porelo project
  show` takes two to three seconds. Opened again, it shows the session's last read of the project at once, marked as
  read again, and offers no change while it shows it, since a change carries the revision of the read it was made on;
  a read again that fails keeps the last read and says so.

## Planning

- **The planning screen is porelo-planner's Flutter package `porelo_planning`**, taken by `git:` at a pinned commit
  with `path: screen`. The board, a story, an issue, their moves and *Start work* are the package's; the window embeds
  it (`lib/src/ui/planning_embedding.dart`) and answers its hooks, and its feature files run on the package's stand-in.
- **A Start the machine refuses after the planning screen asked for it**, by a refusal, a throw or an answer with no
  container, is written to the window's log at WARN with the machine, the project, what was to start and the machine's
  words, and shown as a notice beside the planning screen's own line. A Start turned away in the dialog, or refused by
  the window before it asks, is neither.
- **The planner is found by its address file**, `porelo-planner/planner.json` under `XDG_RUNTIME_DIR`. Only a missing
  address means none runs: the window then starts `/usr/libexec/porelo/planner`, else `porelo-planner` on an absolute
  `PATH` entry, once, and waits 20 s for its address. Every other refusal is said, and starts nothing.
- **A project is told to the planner by its own repository's upstream** as a watched machine lists it, a remote clone
  URL before a local path; where no machine names one, the board says so in words.
- **Each task the window starts for an offer is reported to the planner** through the provider's source, one report
  at a time: `started` once, and `ended` once for each end of its agent, with Porelo's record unmapped. The offer is
  kept in the settings by machine and container with what was told, so nothing is told twice across restarts, and the
  newest 2000 offers handed to Start are kept, so a follow-up order of an answer starts once. `TaskNotAnswered` stops
  the task and forgets its offer; another refusal is said and not sent again before the window's next start; a planner
  not reached is tried again on the next change. A story stopped on the board stops the tasks the package names, with
  no report. A report a crash cut off before its mark was kept is sent once more after the restart.
- **A reader is started naming the tasks whose work it reads**, the order's `reads`, so Porelo's gate hands it those
  branches. Work that still waited at the gate when its task ended is reported once more, as `landed`, once the task's
  row names where it landed; an end that already names it counts as that report.
- **A task is found again by its offer**, which Start is given as the task's `callerKey` where Start declares it: a
  window that ended before Start answered keeps, at its next start, the listed task of the offer's project whose key
  is the offer, and reports it. Against a Porelo without `callerKey` such a task is not found again, and its reports
  are lost.
- **The address file is read again every two seconds**, so the window follows a planner restarted on another port
  without a restart of its own; a file gone at two reads in a row counts as no planner, which is then looked for, and
  started, as at first.
- **A planner the window started ends with it.** It runs with `--end-with-input` and its input a pipe the window
  holds, so a hard kill of the window ends it too; closing the window, SIGTERM and SIGINT end it with SIGTERM, then
  SIGKILL after two seconds, only while its address file still names the address it wrote. A planner found serving is
  never touched.
- **On Windows the planner is `porelo-planner.exe` on a `PATH` folder from a drive's root**, its address
  `%LOCALAPPDATA%\porelo-planner\planner.json`. It is started only when the person asks on the planning place, and is
  ended by closing its input, then hard after three seconds, as Windows has no SIGTERM.

## The window's log

- **`frontend.log` in `logs` under the window's state folder**, `$XDG_STATE_HOME/porelo/logs` on Linux and
  `%LOCALAPPDATA%\porelo\logs` on Windows, the folder the planner writes its log into too. One line per entry: its time
  in UTC, its level, the machine where there is one, and its words, never a credential's value. Past 10 MB a new file
  is started and three older ones are kept. A folder that cannot be written is said once on standard error, and the
  window goes on without its log.
- **What only informs goes to the log, not to *Needs you***: a row put away or resolved is written there at INFO, and
  so is what a planner the window started prints, its standard output at DEBUG.
- **The log level**, ERROR, WARN, INFO or DEBUG, is chosen under *Options* → *Logs*, INFO where none was, and holds
  from the next entry. The planner is told it with `PUT /log/level` when the window finds or starts one and on each
  change; *Logs* says where the planner answered another level or did not take it.
- **Each log opens from *Logs*** with the desktop's opener, the planner's at the path its `planner.json` names, kept
  once that planner has gone. Only a file of its own directly in the `logs` folder is opened, never a link or a path
  elsewhere, since the opener runs whatever lies at a path; a file not there yet is said with its path. On Windows
  `rundll32 url.dll,FileProtocolHandler` ends with 0 whether or not a program took the file, so a failure to open is
  not seen there.

## Windows

On Windows the interface reaches a Porelo in a WSL2 distribution of the same Windows user. A unix
socket does not cross the boundary of WSL2's virtual machine, so the way in is a relay:
`wsl.exe -d <distribution> --exec porelo daemon connect`, which joins its standard input and output to
the daemon's socket. `VarlinkConnection` speaks over that byte stream as over a socket file. No ssh,
no open port, no key: `wsl.exe` runs as the Windows user, so only that user reaches the
distribution.

- **`--exec`, not `--`:** after `--`, `wsl.exe` hands the words to the distribution's shell, which
  splits them again; `--exec` runs the program with exactly the arguments given.
- **A process, never a shell pipe:** `wsl.exe` is started with byte streams of its own
  (`Process.start`). Windows PowerShell 5.1 has no `<` and re-encodes text in its pipes; measured,
  `wsl.exe` itself carries Varlink's framing both ways, the closing `\0` included.
- **The distributions** come from `wsl.exe -l -q`, those running from `-l --running -q`, the WSL
  version from the last column of `-l -v`, whose state column is in Windows' language. Each call into
  a distribution is preceded by that reading.
- **What runs on a machine over ssh on Linux runs through `wsl.exe` on Windows:** a task's terminal
  (through ConPTY, `lib/src/app/conpty.dart`), attaching, a sign-in, and the connection trial's checks.
- **Setting up Porelo in a distribution that lacks it** checks, in order, the Windows build, WSL
  installed, WSL2 and not WSL1, a supported distribution from `/etc/os-release`, systemd, and Porelo
  and its daemon, and says in words where it stops. Then it offers the lines Porelo's
  `doc/getting-started.md` gives for the distribution's package manager, with `loginctl
  enable-linger` and `porelo setup`, each shown before it runs. Root inside the distribution
  (`wsl.exe -u root`) is used only for exactly the lines the person said yes to, and recorded in the
  operations record. The repository's key is checked against a fingerprint the interface carries.
- **A machine over ssh is reached from the Linux build only, so far:** `dart:io` opens no unix socket
  on Windows, so the forward does not work there. A socket entry carried over from Linux is said to
  name a path Windows cannot open.
- **A host's vault is opened by the window itself:** Core's `porelo host unlock` does not run on Windows, so
  `lib/src/app/windows_vault_unlock.dart` does its steps over the card's own `ssh -F <card config>`. `ssh-keyscan` of the
  card's address and port must offer the pinned Ed25519 key; the Windows OpenSSH agent (`\\.\pipe\openssh-ssh-agent`,
  where KeePassXC adds its keys) signs Core's SSHSIG; and the share derived from it by Core's written rule goes only on
  the standard input of `porelo vault unlock`, `init` or `rekey --share-stdin` on the host. A vault another key opened is
  kept.
- **Notifications are not raised on Windows yet**, and that is said once: Windows' own need the
  application registered with the shell, which the MSIX's identity would give.
- **The files:** `%APPDATA%\porelo\frontend.json`; the operations record under
  `%LOCALAPPDATA%\porelo`, the window's log in `%LOCALAPPDATA%\porelo\logs`; a file kept to its owner with `icacls`; one window over a loopback port
  named in `%LOCALAPPDATA%\porelo\frontend.port`.
- **The packages,** readied by `tool/windows-prepare.ps1` and made by `tool/windows-package.ps1` in
  the Build's job *Windows* on GitHub's Windows runner: a ZIP, not signed, and an MSIX signed by `CN=porelo.ai`, with one `SHA256SUMS` and
  the build's provenance attestation, in Artifactory's `porelo-dist-windows`. The MSIX's writes to
  AppData are not redirected (`unvirtualizedResources`), so it reads the same `frontend.json` as the
  ZIP and the IntelliJ plugin. The MSIX version takes four numbers: `0.4.2~snapshot.141` becomes
  `0.4.2.141`. The packer and `tool/windows-install-check.ps1` take the app as parameters, written in
  their heads: another repository's Windows build calls them at a pinned commit, so a change to those
  parameters is a change it pins against. Neither leaves a signing key's container or the started app's
  files behind; the Windows trial packs and installs a second app to prove both.

### The machine file, which the IntelliJ plugin reads too

The interface keeps its machines in `frontend.json` (`$XDG_CONFIG_HOME/porelo/` on Linux), and
`porelo-intellij` reads the same file, so a new kind of entry is a contract between the two
repositories, changed only after agreement in both.

- **Without `kind`:** a plain `socket`, or a machine behind ssh when `host` and `remoteSocket` are set.
- **A WSL entry:** `{"name": "<label>", "kind": "wsl", "distribution": "<WSL distribution name>"}`,
  with no `socket`: the socket inside the distribution is found on each connection, from the
  distribution's user id. An older plugin drops an entry without `socket`, so it never opens a Linux
  path on Windows.
- **A host entry:** `kind: "host"` with `host: "<account>@<address>"`, `remoteSocket` and
  `identity`, the private key path given to `porelo-host up`. On Linux `socket` is the local tunnel
  endpoint; on Windows the daemon uses an SSH relay. Every SSH to this machine uses only
  `porelo-host`'s pinned host key and that identity, including temporary trial tunnels. The
  interface never offers to trust a different key for it.
- **`disconnected: true`:** the person disconnected this machine. The entry stays listed and nothing connects to it until
  they connect it again, also after a restart. Absent or anything else means connected. This computer's own entry never
  carries it, as the plugin would add its own beside it.
- **An unknown `kind`** is kept in the file and shown as not reachable by this version, never dropped.
- **`tresorFolders`:** a map from project name to the local Tresorit folder chosen in setups before the drive left
  the host's setup, checked on load and written in the same settings file, never in `project.yml`. It is read only
  for a host key such a folder may still hold, which the secrets file takes over; nothing chooses one any more.
- **`hostUp`:** the kept setup arguments and preparation state per project, written atomically
  before `up` starts, keeping a server in preparation across restarts and refilling the setup dialog
  or `down` command without typing fields again.

### A test on a Windows machine

Not required before a push; welcome from time to time, since GitHub's runner has no WSL
distribution with Porelo. On a Windows 10 2004 or later, or Windows 11, with WSL2:

1. **Install** from the newest folder of
   [`porelo-dist-windows/snapshots/`](https://fuinorg.jfrog.io/artifactory/porelo-dist-windows/snapshots/)
   the ZIP or the MSIX, checked as the download page says; in a fresh WSL distribution (Ubuntu
   26.04, Debian 13, or Fedora 43 or 44), nothing of Porelo yet.
2. **Add the distribution** with *Watch another machine…* → WSL: the setup is offered, every line
   shown, the snapshot channel chosen as Porelo's `doc/getting-started.md` says under "Snapshots";
   the distribution is reached afterwards.
3. **Start work in a project, attach its terminal**: type, resize, scroll, and go back.
4. **Approve a push at the gate**; it arrives at the upstream.
5. **No ssh and no port:** in the distribution, `ss -ltnp` shows no `sshd` and no `porelod` on TCP
   while the interface works with it.
6. **Only the owner:** a second Windows user on the same machine does not reach the distribution.
7. **Stopped stays stopped:** `wsl --terminate <distribution>`; the interface shows it as stopped,
   and `wsl -l -v` still says *Stopped* afterwards.

Where typing or scrolling fails, `porelo_frontend.exe --diagnose-terminal` writes what arrives to
`%TEMP%\porelo-terminal-diagnose.txt`. The result, with the version tested, goes in the channel; the
download page and the issue's row then say "tested on Windows on <version>".

