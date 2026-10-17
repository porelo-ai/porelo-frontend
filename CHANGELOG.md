# Changelog

All notable changes to this project are recorded here.

The format is [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- Sokar is now Porelo, and nothing of Sokar's is read or kept: the interface is installed afresh.
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
