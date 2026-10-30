# Changelog

All notable changes to this project are recorded here.

The format is [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Existing-server preparation runs the checked collection over pinned, agent-only SSH as root,
  retains callback refusal words, and saves the dialog's public settings for retry and card publication.

- Host administration retains confirmed card and applied-revision state when replacing stale changes,
  preserves returned-host deletion during publication retries, and migrates older delivery records.
  Preparation reads SSH-only host results on private networks, carries optional forge job limits and
  local forward choices, shows root bootstrap instructions for a separate terminal, and refuses root stops.

- Host administration recovers unpublished ready cards, changed selections and lost intake staging,
  delivers verified newer registry state without rolling back host access, and refuses unassigned hosts,
  purged memberships and refused-card unlocks. Confirmed returns retain visible deletion recovery,
  disable stale admin actions and permit name reuse after deletion; publication status tracks the host card.
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

- Retired VPN and local trust installers, host-secret stops, copied laptop keys, project-key setup inputs,
  and the associated walks. Old rentals remain visible for confirmed give-back or setup again without
  reusing obsolete credentials. Signed-state setup and joining require the served replacement adapters.

### Added

- Host administration has registry-backed app operations for trusted-person admission, host-scoped locking,
  readmission and separately confirmed account deletion. Checked SSH completion cards and confirmed provider
  returns retain publication recovery independently; registry delivery resumes the same signed revision and
  requires the intended host, revision and membership result before confirming it. Signing and host intake
  remain injectable until their implementations are available.
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
  `~/.local/share/porelo-host/setup/<project>/` directory. Its machine file names `access.bundle` relatively
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
  opens on a key in `~/.ssh` that the project's machine already trusts, and checks a key as soon as
  it is chosen or typed, with a check mark or an error icon beside it.
- Server setup fills in your public ssh key from the private key's own `.pub` whenever there is
  one, also over a key kept from an earlier run, and refuses a public key of another pair at once.
- Server setup installs porelo-host's collection 0.5.7, which brings up the host's forge and gives
  each agent its own forge account and token, the person a forge login of their own, and each
  account's gate its token, with every repository's main protected and merged by fast-forward
  only. The forge's runner takes four jobs at once and keeps a cache between runs. The host
  mounts no drive, takes its secrets at the stop on standard input from the secrets file, reads
  its setup files from `/etc/porelo-host/setup/`, and gets its forge's certificate from the
  person's lasting CA. During the move the host's tasks reach the project's room on this computer, and
  the person's forge login is made on every host with a forge.
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
