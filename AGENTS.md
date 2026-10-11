# Rules for working in this repository

`AGENTS.md` is this file, checked in and shared; `.AGENTS.md` holds what is true only on one machine
and is never committed.

## Shared across the Sokar repositories

> **BEGIN Shared Area** · sha256 `5f6217b026c4daf0` · changed 2026-10-11T07:22Z

Identical in every repository `project.yml` names but `sokar-parent`, which holds only the parent pom
and no `AGENTS.md`. The markers carry the SHA-256 of the lines between them (the first 16 hex digits)
and the UTC time that text last changed; change it in the channel first, never in one copy.

### Agents and the rules they follow

- **When several agents run in parallel, they may communicate through a shared channel.** How it
  works depends on the local setup and is defined in the optional `.AGENTS.md` or fed into every
  agent's context when it starts.
- **Every repository has exactly one responsible agent, and one agent may be responsible for
  several.** Which one is defined in the optional `.AGENTS.md` or fed into every agent's context when
  it starts.
- **A rule that holds for more than one repository is stated generally and shared** - here, or in the
  shared block of `.AGENTS.md` if it concerns the local setup. A rule is one or two sentences and
  says only what matters.
- **A rule belongs in `.AGENTS.md` only if it concerns local settings that cannot be shared through
  `AGENTS.md`.**
- **An agent writes only in its own repositories and asks the responsible agent for anything from
  another**, in the channel. The coordinating agent may also read the other repositories, but never
  writes in them.
- **Where a channel exists, an agent stays reachable on it while any work is open**, and says there at
  once when it waits on the operator.
- **A contract between repositories - an interface, a file format, a path another repository links
  to - changes only after agreement in the channel or by an operator decision**, and in both
  repositories.
- **An ambiguous answer is asked about once, plainly, instead of guessed at.** When an answer
  changes, everything built on the old one is looked for.

### Commits and pushes

- **While working, commit in logical steps, so a mistake can be rolled back.** A task is pushed only
  when it is finished, squashed into one commit as its last step; several finished tasks may go out
  in one push, one commit each.
- **An edit replaces an exact block, never everything between two landmarks; only the files you
  edited are formatted.** Before a commit, `git status` is read and only your own files are added,
  never with `git add -A`.
- **Unless the operator says otherwise, the operator pushes, and agents commit and stop.** An
  instruction to push covers exactly what it names.
- **A change that needs another repository's change names that dependency when it is handed over**,
  and is pushed only after the change it needs has built and published.
- **A change is ready only when every step its build workflow runs - not only Maven - has passed
  locally.**
- **Amend, squash or rebase only commits that are not pushed**, checked with
  `git ls-remote origin refs/heads/main`, never with a cached `origin/main`. A pushed commit is
  repaired by a new commit on the remote's tip, never by a force push.
- **A commit message is one brief line saying in words what changed**, never by a requirement number;
  the reasoning goes into an issue or a decision.
- **No commit message, changelog entry, issue or document says who asked for a change or who made it**
  - no "as the operator chose", no agent's name; it says what changed and why.
- **A change to what ships or builds gets its changelog entry in the same commit**, under
  `[Unreleased]` and the heading of its kind. A generated changelog is changed only through its
  sources, never by hand.

### Issues

- **Every open task is an issue in `issues/`, named `<prefix><nn>-Short-Title.md`** with one of its
  repository's prefixes; a repository may own several, for subgroups. An issue is one task, says
  what must be true and how it is judged done, and names a dependency on another repository's issue
  by repository and number.
- **A new issue follows this skeleton**, and its index row is added in the same commit; *Why* and
  *The shape* may follow *What must be true* in a larger issue:

      # <PREFIX><nn> — <Short Title>

      **Status:** now | soon | later; blocked by <repository> <number>, if so.
      **Size:** XS | S | M | L | XL - one line why.

      **What must be true.** One or two sentences, from the point of view of whoever uses it.

      ## Plan

      - How it is built, read in today's code: what it touches, the steps, the test that goes red first.

      ## Acceptance

      - How it is judged done: what is measured, and what must be seen to fail.

      ## To be checked

      - Open questions, if any; deleted once answered.
- **`issues/README.md` is the index, grouped into Now, Soon and Later**, each a table of number,
  status, size, blocked by, what it covers and open questions, ordered by what to do next; it changes in
  the same commit as the issue. An open task is never a TODO in code or a note in a commit message.
- **Every open issue has a size and a plan, read in the code, not guessed.** XS is under an hour (one
  file, no contract); S a few hours (one module and its tests, no contract other repositories read);
  M about a day (several modules, or one contract change, docs, an acceptance step); L several days
  (crosses repositories, or a design to decide first); XL is too big to build as one and says how it
  splits into issues of L or smaller. *Plan* names the files and classes it touches, the steps and the
  test that goes red first; a size or a plan that turns out wrong while building is corrected in the
  issue in the same commit.
- **An issue's unanswered questions sit under *To be checked*, and the index counts them.** An
  answered question is deleted once its answer is in the criteria, the design or a decision.
- **A finished issue is deleted, with its row and every mention of its number.** What outlives it
  moves first: to `doc/` if a user needs it, to `doc/decisions.md` if it is a decision, to
  `AGENTS.md` if it is a rule, to `.AGENTS.md` if it is true only on one machine.
- **`doc/decisions.md` opens with an index** - subject, one line of what holds, link - and a row is
  written with its decision. An accepted risk states the exposure, why it stays, and what would
  change the answer.
- **A requirement not yet placed waits in `sokar-project`** until it is clear which repository builds
  it, then moves there as an issue.
- **Link to a requirement by its number and the index, never to its file**, which is deleted when the
  requirement is finished. A repository that can test this, does.
- **Code, comments, test names and anything that ships never cite an issue number**; they state the
  constraint itself, since the issue is deleted once it is finished.

### Testing and machines

- **Work is tested on local VMs before it is handed over, on rented machines reachable from here only
  when the operator says so, and in the GitHub build on every push.** Which machines a setup has is
  defined in the optional `.AGENTS.md` or fed into every agent's context; machines are rented only
  through the shared tooling, and nothing else names a provider.
- **How agents exchange files for a test on a local VM is defined in `.AGENTS.md`.** Where it says
  nothing, a test uses only the agent's own artifacts.
- **A local VM is restarted only when agreed in the channel or asked of the operator.** A rented
  machine reachable from here is restarted only by the operator.
- **A rented machine's name says which agent and which run made it.** Every run deletes exactly what
  it created, after a failure too, and never sweeps by age or touches a machine it cannot attribute.
- **A script that changes a machine refuses to start over leftovers, removes only what it created -
  on interrupt too - and exits non-zero naming anything it left.**
- **Before a run on a shared machine, check what it does to that machine and say so.**
- **Before a long run, say how long it will take**, from a measured time, or say that it is a guess.
- **A test that waits on an agent, a model or any paid service fails fast on a loop**: it stops as
  soon as the same failure repeats, instead of waiting out its time, and names what repeated. A run
  seen looping is reported at once, so the operator can cancel it.
- **A defect is fixed only after a unit or integration test reproduces it.** The test fails first,
  then the fix makes it pass.
- **A test is trusted only once it has been seen to fail**: break the code on purpose, watch the
  test go red, and restore it. A break that does not compile proves nothing.
- **A guard asserts what its reference set is, not only that it has entries**: an empty set, one
  that cannot change, and one nobody reads all pass as green as one that works.
- **A test asserts the observable effect, never what the system reports about itself or its
  internals.** A fixture states what the real system produces, never what the code assumes, and is
  never edited so that a feature has something to show.
- **A test depends on nothing outside itself**: not on the machine's configuration (a suite calling
  git runs with `GIT_CONFIG_GLOBAL=/dev/null`), not on wall-clock time, and not on a pinned version
  written into it - it reads the version from the build.
- **Before a commit, the full suite runs as its own step and its result is read.** A commit is gated
  on the exit code, never on grepped output, and never chained onto the test run.
- **A change handed over says which test levels actually ran** - unit tests, local VM, rented
  machine - never which ought to have. A change to documents or issues only needs the tests tagged
  `documents`, which run alone; every test that reads a document carries that tag, and a test fails
  when one does not.
- **A repository with a workflow runs `sokar-release`'s `check-shared`, `check-citations` and, where
  there is a documentation chapter, `check-doc-site`, with the tests tagged `documents`, on every
  push and pull request**, on a GitHub runner; the build skips a change to documents only.
- **A test result names every skipped test**, never just a count.
- **A failing check prints what it asked and what it got, never a guessed cause**, and its failure
  path has been made to happen once and read.

### Claims and writing

- **Measure before you claim, and say what was measured and what inferred.** Agreement between agents
  counts only where each measured, and "I could not get X" only once a second method failed too.
- **A command that should have changed something is checked by observing the change** - connect,
  read the file, ask the daemon - never by its exit code alone.
- **Every date, time or age written is read from the system (`date -u`) first, never from memory.**
  An age is computed from two timestamps that were both read.
- **When a thing is right in two forms, keep one.** The second copy is the one that goes stale.
- **Documentation and rules state what is true now**: no dates, no history, no stories, and nobody
  named, only roles. The shared blocks' markers are the one exception.
- **Everything written is US English** - documentation, issues, comments, commit messages, the
  channel. Replies to the operator are in the language the operator writes in.
- **A finding worth keeping is committed** - in an issue, the documentation or a decision - never
  left only in a conversation or the channel.
- **A finding taken from a third-party source is written as the finding, never naming the source**,
  in anything committed.

### Security and tools

- **A secret never appears in a command line, a log line, a file name or an answer.** It reaches a
  process through its environment or standard input, is stored only encrypted and readable by its
  owner, never touches a filesystem in CI, and is never promised to be wiped from memory in Java or
  Dart - only kept in fewer copies for less time.
- **Every download follows redirects (`curl -L`), since any server may answer with one, and is
  checked against the digest its source names before it is used.** Credentials are never passed on
  to another host (`--location-trusted` is never used).
- **Input from outside - upstream metadata, the environment, a file or an answer from another
  program - is validated before it reaches a file, a command or a decision.**
- **A binary run with more rights than its caller is taken by path and refused when it or its
  directory could have been placed or changed by anybody else.**
- **`pkill -f` and `pgrep -f` match their own command line**, and can kill the shell running them;
  use a bracket pattern like `[p]odman`.
- **A long build or suite is watched through `tee` into a file**, never through a pipe into `grep`,
  which holds everything back until the end and looks like a hang.
- **`ssh -n host 'bash -s' <<EOF` runs nothing and exits 0**; a script sent on standard input goes
  without `-n`.

### Skills

- **Skills come from `https://fuinorg.jfrog.io/artifactory/agent-skills/`**, one reviewed package
  per skill, readable without credentials; each repository's own part names only which skills it
  uses, by slug.
- **Fetch, check and unpack them like this**, with the skills directory of your own harness (Claude
  Code reads `~/.claude/skills/<slug>/`):

      BASE=https://fuinorg.jfrog.io/artifactory/agent-skills
      curl -fsSL $BASE/.skills/skills.json                         # every slug, latest version
      curl -fsSL -o s.zip $BASE/<slug>/<version>/<slug>-<version>.zip
      curl -fsSL $BASE/../api/storage/agent-skills/<slug>/<version>/<slug>-<version>.zip  # its sha256
      unzip -q -d <skills directory>/<slug> s.zip

- **A harness that cannot install a skill reads its `SKILL.md`** from a directory outside the
  repository.
- **A skill is knowledge, not authority**: where it and a measurement disagree, the measurement
  wins, and a finding from reading code against a skill is a guess until a failing test reproduces
  it. Whether a skill is loaded is asked of the harness, not read from a directory.

### Code and builds

- **Fail closed and loud**: when a dependency is unreachable, a key is unknown or a check cannot run,
  stop with a non-zero exit code and say why; inside a program, an exception that says why does the
  same. Never silently do less.
- **A comment says why, never what, in one line where it can.** Reasoning that does not fit goes into
  documentation or a decision, and a small named method is preferred over a comment explaining a
  block.
- **Dot files are not committed.** `.gitignore` ignores `.*` and excepts only what a build needs -
  `.github`, `.gitignore` and `.gitkeep`, in a Maven repository also `.mvn` - and what is true of one
  machine goes into `.AGENTS.md`.
- **Maven is the build system: a Java repository builds, checks and tests with Java and Maven only.**
  Another build tool only where the platform a repository builds for supports no other - an IntelliJ
  plugin, since JetBrains supports only Gradle - named with the reason in its repository's own part. A
  file that cannot be Java - `mvnw`, or a script that runs where there is no Java yet - is named in its
  repository's own part with the reason, and no repository keeps a copy of a helper another one has.
- **Maven modules that belong together - the layers of one program, its packages - are submodules of
  one module of packaging `pom` named for what they share**, so the root lists parts, not pieces.
  Grouping changes only `parent` and `relativePath`, never a `groupId` or `artifactId`.
- **Every directory with a `pom.xml` has a `README.md`**: two or three sentences on what the module is
  and is not, a link to each of its submodules, and only the few technical facts that matter most, such
  as what it must never depend on; details are linked in `doc/`, never repeated. `sokar-release
  check-readmes` holds it.
- **Only what another repository or an outsider builds against is published to Maven Central, each such
  module opting in; the root and every grouping module are never published.** Every published pom is
  flattened, so it names no parent and a consumer needs nothing but the module itself; `sokar-release
  check-releases` refuses a release whose published pom still names one. A BOM is imported, never a
  parent.
- **Every Sokar Maven repository takes `org.fuin.sokar:sokar-parent` as its parent** and declares only what
  is its own; one that publishes declares `flatten-maven-plugin` by name in its root, and the parent's
  management flattens every module. `sokar-parent` names no parent and uses nothing of another Sokar
  repository.
- **Every Java package with main code is `@NullMarked` and checked by NullAway as an error when it
  compiles**, with a test that fails on an unmarked package.
- **`Files.move` with `ATOMIC_MOVE` replaces a file that already has the target name**; where the
  first of two writers must win, publish with `Files.createLink` (`link(2)`), which fails on an
  existing name.
- **Java code carries brief Javadoc on every public type and method; a test method's name reads as a
  sentence (never `testXxx`) and an assertion states its reason (`.as(...)`).** Every build call in
  CI names its repositories in the repository itself (Maven: `-s settings.xml`).
- **Everything a build runs is pinned and moved only by review**: actions by commit with the version
  beside it, the JDK (from `sokar-machines jdk --github`), the build tool's wrapper (Maven, Gradle) and
  images by version and digest, updated by Dependabot weekly, in one group, after three days.
  `sokar-release check-actions` enforces it.
- **While it is developed, a repository may build against another Sokar repository's snapshot from
  Sonatype**, and its build may fail for a while when that snapshot moves; a release depends only on
  releases, which the release build checks.
- **Packages are built online**: offline, the CycloneDX bill of materials skips itself with only a
  warning, and the package ships without it.
- **A publish is believed only once the published index shows the exact version**, probed with
  retries; a snapshot version sorts above the one before it. Retiring a package removes it from the
  index too.
- **Every native executable is built with `-march=x86-64`**, so it starts on any x86-64 CPU, and the
  build checks each executable for exactly that instruction set.

> **END Shared Area** · sha256 `5f6217b026c4daf0`

## This repository

The Sokar interface: a Flutter desktop app (Linux) that watches and drives the Sokar daemons of
several machines over their varlink socket. Its issues carry the prefix `F`; its design is in
`doc/design.md`, the daemon calls it uses in `doc/Backend-API.md`, what the daemon cannot do yet in
`doc/Contract-Gaps.md`, its decisions in `doc/decisions.md`, and the guided walk in
`doc/guided-walk.md`.

### Running it

    dart tool/mock_daemon.dart                  # prints a socket and a situation to choose
    SOKAR_SOCKET=<that socket> flutter run -d linux
    dart run build_runner build                 # after adding or editing a feature file
    dart analyze                                # stays at "No issues found!"
    flutter test                                # the whole suite
    flutter test --tags documents               # a change to documents or issues alone
    tool/e2e.sh                                 # the integration leg, against SOKAR_E2E_HOST
    flutter build linux --release && tool/package.sh

- **`dart analyze`, never `flutter analyze`**, which rewrites `analysis_options.yaml` with an exclude
  block that silences findings.
- **The mock daemon is started with a deadline** (`timeout 20 dart tool/mock_daemon.dart`): it reads
  keys, a closed standard input is no key, and it runs on otherwise.
- **The Linux desktop toolchain is `clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev` and
  `libsecret-1-dev`**; `flutter doctor -v` says what is missing.
- **Skills it uses:** `dart-add-unit-test`, `dart-build-cli-app`, `dart-collect-coverage`,
  `dart-generate-test-mocks`, `dart-resolve-package-conflicts`, `dart-run-static-analysis`,
  `dart-use-path-package`, `dart-use-pattern-matching`, `dart-use-primary-constructors`,
  `dart-write-documentation`, `flutter-add-integration-test`, `flutter-add-widget-test`,
  `flutter-apply-architecture-best-practices`, `flutter-build-responsive-layout`,
  `flutter-fix-layout-issues`, `flutter-implement-json-serialization`.

### The contract

- **Everything reaches a daemon through `org.fuin.sokar.Tasks1` over its socket; nothing parses the
  `sokar` CLI and no code is shared with the backend.** `ssh` (transport), `sokar task attach` in a
  pty (a session the contract cannot carry), a command the machine itself names, and `notify-send`
  (the desktop) are not breaches. Nothing reads or writes a backend's files.
- **No design here needs a token, a session or a login screen**; one that seems to is said in the
  channel rather than built.
- **The contract is served, never copied**: `dart tool/contract.dart <socket>` prints it from a
  running daemon.
- **A requirement is checked against the IDL parameter by parameter and field by field**, never
  against a method's name or a field named in prose. `doc/Contract-Gaps.md` is read before a
  requirement is picked up; what the daemon lacks goes there and is raised as a requirement in
  `sokar`, never designed around, and comes off the page once it has landed.
- **Take the highest `org.fuin.sokar.TasksN` `GetInfo` offers, turn `MethodNotFound` into
  `FeatureNotSupported` for that feature alone, ignore unknown fields, and render an unknown enum
  value rather than throwing** (`Outcome` is no Dart enum); a feature is never gated on the build
  version.
- **One call at a time per connection.** A stream ends only on a final reply, anything else is an
  error; a single call has a deadline (30 s, `GetInfo` 5 s), a stream never does.
- **Nothing is derived here that the daemon knows**: logs, credential keys, store commands,
  readiness, what `Start` would do, what a removal keeps. Render verbatim what only the daemon can
  compose; take counts, states and instants as parts and word them here.
- **Every project-scoped method takes the project's name, never a file path**, and a path is
  refused rather than answered as an empty list.
- **A change to the contract is agreed in the channel first**; within `Tasks1` it only grows, and a
  change that cannot is a `Tasks2` served beside it.

### The client

- **Only `lib/src/wire/` and `lib/src/client/` open a socket; the frame talks to `FleetBackend`.**
- **`VarlinkConnection.close()` destroys the socket**, because `Socket.close()` completes only when
  the peer closes; streams use an explicit subscription with `onCancel`, never `await for`, which
  cannot be interrupted while it waits.
- **A throw in a socket's `onData` never reaches `onError`**, so everything a peer can send wrong is
  caught there and reported as a lost connection; `mostBytesPerReply` bounds a reply with no end.
- **A forward this interface raises is `ssh -N` with `BatchMode=yes` and `ExitOnForwardFailure=yes`,
  believed only once a connection through it arrives**, and only what was raised here is ever taken
  down.
- **A command run on a machine over ssh goes through its login shell** (`inTheLoginShell`), or it
  meets the machine-wide `sokar` instead of the account's own.
- **Nothing forks out of Dart**: a pty child is made with `posix_spawn` and `POSIX_SPAWN_SETSID` and
  takes the terminal by opening it without `O_NOCTTY`.
- **The settings file is written beside itself and renamed over, and every stored field is checked
  rather than cast.**

### The frame

- **Every action is a `Command` in `commands.dart`, lives where it acts (`Command.home`), is
  reachable with a pointer alone, and is listed with its reason when it cannot run now.**
- **A refusal is an answer with its own place and sentence, never weakened to make a flow smoother**;
  a forcing button exists only where the contract has one, worded as the second decision it is.
- **Absence is rendered as absence**: an empty field from an older daemon, `UNKNOWN`, an unreadable
  vault or a lost connection never reads as a good state, and losing contact keeps the last list.
- **Nothing is applied optimistically**: a decision shows once the daemon's own answer or echo
  confirms it.
- **No layout assumes the window is never a phone's.**
- **A spacing, width or radius is spelled only in `tokens.dart`, a width compared only in
  `window_size.dart`**, which reads the window, never the pane; icons are outlined, filled only when
  selected.
- **`SOKAR_SOCKET` is read only in `Machine.local()`.**
- **A node is an OS user with a `sokard`, so nothing is keyed by hostname alone; a host is an egress
  destination, never a machine.**
- **No credential value is shown, stored, logged or sent over the socket**; credentials are listed by
  name, kind and length, a value reaches a machine by its own command, and nothing promises to wipe
  one from memory.
- **A saved job holds name, project, agent, mode and prompt only**, read field by field, never
  clearance or the gate.
- **The interface writes no `project.yml`**; a project's settings are changed only in its repository.
- **A terminal session gets the frame's focus node**, so `Escape` reaches the far end, and a modified
  Enter is sent as itself only after the far end asked for modified keys.

### Tests

- **Features are Gherkin files generated into widget tests by `bdd_widget_test`, and the generated
  tests are committed.** A `Feature` line is one short sentence, step wording is an API reused as
  is, and an apostrophe or a `$` in a step's text breaks the generated Dart.
- **No requirement id appears outside `issues/`**: `sokar-release check-citations .` enforces it, and
  `check-doc-site doc mkdocs.yml` holds `doc/` to the site's navigation, and `check-readmes .` the
  `README.md` beside `pom.xml`; `shared-rules` runs all three on every push. A channel question number is
  kept out of the code by `test/features_named_test.dart`.
- **Three levels**: the frame against `FakeBackend` in `testWidgets`; the client against `MockDaemon`
  over a real unix socket in plain `test()`; `test/client/live_daemon_test.dart` against a real
  `sokard` when `SOKAR_SOCKET` is set (and `SOKAR_VAULT_TEST=1` for the vault round trip).
- **A socket never completes inside `testWidgets`**, which runs on a fake clock.
- **A stand-in acts on what it is told and is never canned**; the mock serves `pushes` for `Watch` and
  `Prompts` and `stream` for anything finite, driven by the test, never by the clock.
- **Widget tests run at 1280x800 on `tester.view` with `devicePixelRatio = 1`**; steps settle with
  `World.settle`, never `pumpAndSettle`, which never returns while a spinner shows.
- **A unix socket path is limited to about 108 bytes.**
- **The integration leg runs headless under `xvfb-run` inside `dbus-run-session`**, the app with its
  own config and runtime directories; `./mvnw verify -Pe2e,hetzner` rents a machine through
  `sokar-machines` and sweeps it after a red run too.

### Building and publishing

- **Packages are `.deb` and `.rpm` from `tool/package.sh` with nfpm**, `type: tree`, dependencies
  derived from the ELF files (never listed), `recommends: sokar`, `amd64` only;
  `test/packaging_test.dart` asserts the template with comments stripped.
- **Every build job runs on `ubuntu-22.04`**, because the bundle links the system GTK, so the build
  machine is the oldest one the package installs on.
- **A snapshot is `0.1.0~snapshot.<run>`**, so each build supersedes the last; a flat version
  published once strands whoever installed it.
- **An upload passes `--target-props` with distribution, component and architecture, and
  `--flat=true`**; without Annotate permission the properties are dropped in silence
  (`artifactory-probe.yml` checks it). `JF_URL` is the platform URL, without `/artifactory`.
- **`tool/test_report.dart` reads `flutter test --machine` once** and writes the HTML page, JUnit XML,
  the step summary and one annotation per failing scenario; an empty run fails.
- **A change to `**.md`, `doc/`, `issues/` or `mkdocs.yml` alone starts no build.**
