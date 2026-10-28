# Changelog

All notable changes to this project are recorded here.

The format is [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Putting a project on a server checks first that KeePassXC's command line is installed: without it the
  command says so with the line that installs it, the secrets step shows that line once with an error
  mark and a copy button, and its button says Make it now (try again) and looks again on each press.
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

- The Linux packages require KeePassXC (`keepassxc-minimal` or `keepassxc`) and `wireguard-tools`, the programs the
  interface runs for a person's secrets file and for a server's VPN.

- Server setup checks the project's verified commit against the public key for signing commits on
  The drive, before anything is rented: a key that did not sign it is refused with both keys'
  fingerprints, and named as the server login key when the two key fields look swapped. The field
  opens on a key in `~/.ssh` that the project's machine already trusts, and checks a key as soon as
  it is chosen or typed, with a check mark or an error icon beside it.
- Server setup fills in your public ssh key from the private key's own `.pub` whenever there is
  one, also over a key kept from an earlier run, and refuses a public key of another pair at once.
- Server setup installs porelo-host's collection 0.5.6, which brings up the host's forge and gives
  each agent its own forge account and token, the person a forge login of their own, and each
  account's gate its token, with every repository's main protected and merged by fast-forward
  only. The forge's runner takes four jobs at once and keeps a cache between runs. The host
  mounts no drive, takes its secrets at the stop on standard input from the secrets file, reads
  its setup files from `/etc/porelo-host/setup/`, and gets its forge's certificate from the
  person's lasting CA.
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
  page, as when it is added, with the key ssh would log in with where `~/.ssh/config` names one.
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
