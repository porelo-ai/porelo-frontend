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
  the oldest distribution that must be supported. That is `ubuntu-22.04`: measured on 2026-10-10,
  its packages install on every system Porelo supports, Ubuntu 26.04, Debian 13, Fedora 43 and
  Fedora 44, and the workflow proves that on each build in those four images, pinned by digest.
- **The C library floor:** both packages declare the oldest glibc they need, the `.deb` as
  `libc6 (>= …)` from `dpkg-shlibdeps`, the `.rpm` as `libc.so.6(GLIBC_…)(64bit)`. `tool/package.sh`
  holds it with `porelo-release`'s `check-linkage --declared-only`, as Porelo's own packages hold
  theirs: no object may need a newer glibc symbol than declared, and the floor may not rise above
  Debian 13's glibc 2.41.
- **Architecture:** Flutter has no cross-compile for Linux desktop. Every architecture shipped
  needs a builder of that architecture.

### Where it lives

**`lib/` at the root, one package named `porelo_frontend`**, organization `org.fuin`, Linux and
Windows the enabled platforms. A `packages/` split pays for itself only once something is shared, and nothing
is; a second consumer of the client code is what would change that.

## Projects on prepared hosts

*Put this project on a server…* takes the public JSON copied from *For the project admins…*, the project admin's
own account name on that host, and their SSH identity file. A watched machine is not required. Renting belongs
to *Prepare a server…*. Before any access edit or push, the public values, VPN address, identity path, project
and credential names, and host CA are checked. The supplied SSH host key is pinned at that VPN address in a
file for this host alone under porelo-host's state. Both SSH and the stop use that file, with no shared trust,
root login, or sudo. A signing-key selection reads only its public prefix before reading the public key body.

The daemon's verified project revision supplies `access.repository` and every central repository URL. The access
checkout lives under `~/.local/share/porelo-frontend/access/<project>/`, mode `0700`, outside operation records.
An existing checkout must be clean, have no unpublished commits, and use its default branch. Host settings and
`transports.matrix` are edited with preserved comments. Git must already have commit signing configured; its own
credential setup performs the clone and push, and its own signing setup signs the commit. The chosen project
public key verifies the access commit before it is pushed, independently of Git's signature-display settings.
Each attempt edits and signs in a private detached worktree. A failed initial clone removes its own incomplete
directory; a signing, verification, or push failure discards only that attempt, preserving the clean persistent
checkout for retry. Identical already published access bytes need no additional commit or push. No public
`project.yml` is edited.

The own-account upload installs `machine.yml`, `project.bundle`, and `access.bundle` under the person's host
home, with directory mode `0700` and file mode `0600`. A bring adds the checked Forgejo migration list to the
machine file; a join omits it. Each migration has a unique repository name derived from a central HTTPS URL
without a user, query, or fragment. The bring's stop receives only its allowed needs from the secrets-file
terminal. Its entries must already exist: the stop names anything missing. Host entries use the prepared
host's name, while vault and credential entries use the project name. Resuming a completed stop reruns the
playbook without repeating the access push or setup upload. An interrupted bring can be retried without
republishing identical access settings. An existing setup folder remains untouched and its host refusal is
shown verbatim; the interface does not replace it.
The playbook performs one sync and its last task runs `porelo talk room <project>` in the admin's account.
The interface writes exactly four keys in `transports.matrix`: the supplied `homeserver` as
`https://matrix.<host>.porelo.internal:8448`, the fixed `room` alias
`#porelo-<project>:matrix.<host>.porelo.internal`, `registration_token_file` as the literal
`~/.config/porelo/matrix/host-registration-token`, and `ca_certificate` as a literal YAML block. The alias is
shown for review and cannot be edited. Admission leaves the registration token in the admin's own home on
the host; the interface writes its path and never reads the token.

The CA comes from the selected host's retained public forge CA in its setup record. Before any access edit
or upload, it must be one PEM certificate, with no chain or extra DER bytes, and its DER SHA-256 must match
that host's `ca_sha256`. Missing or mismatched trust is refused without a network fetch. This trust applies
only to the selected host. The written PEM must read back byte for byte, including its final newline;
existing YAML comments are kept. Other Matrix keys, including `tls_verify` and `ca_file`, are removed.
The project's Matrix peer belongs in the signed project file and is not edited here. The interface makes no
separate room or sync call. It shows the playbook's latest public lines, including a room refusal in Porelo's own words.
Completion also requires the host daemon to confirm the verified project revision over the same pinned SSH
connection. An already watched connection to that account is refreshed. The checked host values determine
the project-to-host association kept in `frontend.json`.

*Take this project off the server* is the host admin's act. Its project-menu action uses that association to
find the retained host record, then opens the existing root helper dialog with the project fixed for review.
The helper runs over the same pinned admin SSH as registration. It receives only the central token, one line
on standard input; it receives no central URL. A refusal is shown verbatim, and only exit zero with a matching
`project` and `removed: true` is accepted. The reply may also list `locked` accounts. The helper checks before
changing anything and does not unfollow. A confirmed removal clears a local association to that same host;
a refusal preserves it. Local secrets-file failures are shown without inventing a remote reply or exposing
a temporary reply path. Password prompts remain visible while public refusals are captured; their capture
finishes before the dialog reads the reply. The separate *Stop following this project* action remains the unfollow.
The project-menu action is available only with the host-admin role and that host's record on this desktop.
Otherwise its reason directs the host admin to the server's menu, *Take the project off*.

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
  (`Process.start`). Windows PowerShell 5.1 has no `<` and re-encodes text in its pipes; measured on
  2026-10-10, `wsl.exe` itself carries Varlink's framing both ways, the closing `\0` included.
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
- **Notifications are not raised on Windows yet**, and that is said once: Windows' own need the
  application registered with the shell, which the MSIX's identity would give.
- **The files:** `%APPDATA%\porelo\frontend.json`; the operations record under
  `%LOCALAPPDATA%\porelo`; a file kept to its owner with `icacls`; one window over a loopback port
  named in `%LOCALAPPDATA%\porelo\frontend.port`.
- **The packages,** made by `tool/windows-package.ps1` in the Build's job *Windows* on GitHub's
  Windows runner: a ZIP, not signed, and an MSIX signed by `CN=porelo.ai`, with one `SHA256SUMS` and
  the build's provenance attestation, in Artifactory's `porelo-dist-windows`. The MSIX's writes to
  AppData are not redirected (`unvirtualizedResources`), so it reads the same `frontend.json` as the
  ZIP and the IntelliJ plugin. The MSIX version takes four numbers: `0.4.2~snapshot.141` becomes
  `0.4.2.141`.

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
3. **Follow a project, start work, attach its terminal**: type, resize, scroll, and go back.
4. **Approve a push at the gate**; it arrives at the upstream.
5. **No ssh and no port:** in the distribution, `ss -ltnp` shows no `sshd` and no `porelod` on TCP
   while the interface works with it.
6. **Only the owner:** a second Windows user on the same machine does not reach the distribution.
7. **Stopped stays stopped:** `wsl --terminate <distribution>`; the interface shows it as stopped,
   and `wsl -l -v` still says *Stopped* afterwards.

Where typing or scrolling fails, `porelo_frontend.exe --diagnose-terminal` writes what arrives to
`%TEMP%\porelo-terminal-diagnose.txt`. The result, with the version tested, goes in the channel; the
download page and the issue's row then say "tested on Windows on <version>".

