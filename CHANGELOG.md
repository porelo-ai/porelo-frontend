# Changelog

All notable changes to this project are recorded here.

The format is [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Every build of `main` makes the Windows interface as a ZIP, beside the Linux packages, with a
  `SHA256SUMS` and a build provenance attestation, and publishes all three into Artifactory, so a
  person can check both before unpacking it.
  The Build's jobs are named *Linux* and *Windows*; the trial on a `windows/` branch publishes
  nothing.
- A machine added is asked what it needs to run work the first time it is the one shown and
  answers, and what it says is shown at once: each check in the daemon's own words, green when it is fine, yellow when it is
  degraded or could not be established, red when it is missing, as `sokar doctor` colours them.
- On Windows, a WSL distribution is a machine. The interface lists the distributions with
  `wsl.exe`, never starting a stopped one, and reaches the chosen one's daemon through
  `wsl.exe -d <distribution> --exec sokar daemon connect`, the same Varlink over the relay's standard
  input and output, with no ssh and no open port. Terminals and commands run there through
  `wsl.exe --exec`. Before connecting it checks the Windows version, WSL, WSL2, a system Sokar
  supports, systemd, Sokar and its daemon, and says in words where it stops. Where Sokar is missing
  it offers to set it up: every line shown first, run as root only after a yes, the repository's key
  checked against the fingerprint the interface carries, the agents chosen with none chosen in
  advance, and each line kept in the operations record. Turning systemd on, which restarts the
  distribution, is asked on its own, and the answer is no until changed.
- A Windows build of the interface, the first part of reaching a Sokar in WSL from Windows. Its
  files are under the user's profile: the machine list at `%APPDATA%\sokar\frontend.json`, where the
  IntelliJ plugin reads it, and what it records under `%LOCALAPPDATA%`. A file is kept to its owner
  with `icacls` and opened as a double click opens it, with no shell reading its name. A task's
  terminal runs in a Windows pseudoconsole, and a second launch joins the first over a loopback
  port. Notifications are not raised on Windows yet, and that is said once. A workflow of its own
  builds and tests it on GitHub's Windows runner and publishes nothing.
- The machine list keeps a WSL distribution, `{"name", "kind": "wsl", "distribution"}`, and any
  entry of a kind this version does not know, every field of it, instead of dropping it on the next
  save. On Linux such a machine is shown as not reachable, with the reason in words. The connection
  to a daemon speaks over any byte stream, the first step to reaching a Sokar in WSL from Windows.

### Changed

- The packages are proven to install on the systems Sokar supports, Ubuntu 26.04, Debian 13,
  Fedora 43 and Fedora 44, each image pinned by its digest, instead of Debian 12 and Fedora 40.
  The `.rpm` declares the oldest C library it needs, as the `.deb` does, and a build that would need
  more than Debian 13's glibc 2.41 is refused before anything is published, by Sokar's shared
  `check-linkage`.
- Every workflow run is titled with its workflow, its branch or tag and its commit's subject; the
  shared rules' workflow is called "Shared rules check" and the Artifactory probe "Artifactory probe
  test".
- The build takes `sokar-parent` `0.1.4-SNAPSHOT` and with it the build tools' snapshot, and its
  Maven build and tests read the project's `settings.xml` like every other Maven call, so the
  snapshots come from Central's snapshot repository.

### Fixed

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
  checkout it was started in and back into it as `sokar/<task>`, its remote left to the person, or
  from its remote and back there.
- A work's menu has "Bring it up to its source": what moved in its checkout or remote reaches the
  task without stopping it, and the status line says what moved and whether its agent was told.

### Changed

- Every push checks with `sokar-release` that no page or source cites an issue, and that every page
  under `doc/` is in the site's navigation exactly once, and runs the tests that read a document;
  a push of documents alone runs only these and leases no machine.
- Every push checks with `sokar-release` that each directory with a `pom.xml` has a `README.md`.
- A release refuses to build when anything Maven resolved for it is a snapshot - the parent, the
  tools or their plugin dependencies - and names what it found.
- The Maven build takes `sokar-parent` as its parent, which gives it the JDK, the build tools' and
  the plugins' versions, and the `ci-tools` profile that puts the tools on the checks' classpath;
  the `hetzner` profile only rents and sweeps a machine.
- The Dart and Flutter packages are at the newest versions that resolve with Flutter 3.47.0,
  `cupertino_icons` at 2.0.

### Fixed

- Text copied out of a work's terminal keeps the spaces it shows, also where the program moved the
  cursor instead of writing them, as Claude Code does.

## [0.4.0] - 2026-10-05

Initial public version.
