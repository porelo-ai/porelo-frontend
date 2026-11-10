# F424 — Setting Up A Machine, One Question Per Page

```json
{
  "$schema": "issue-1.json",
  "id": "F424",
  "title": "Setting Up A Machine, One Question Per Page",
  "state": "Review",
  "size": "L",
  "priority": "Medium",
  "rank": 71,
  "blockedBy": [],
  "covers": "Setting up a server as a machine is one wizard, one question per page, each opening only once its answer holds: name, address answering SSH, the host key fetched by hand and compared, an address known with another key said so, the login handed over in a terminal on the server until root answers, the check passed and any no-answer named; *Add a machine* and *Prepare* become one *Set up…*."
}
```

**Why this size.** eight pages, a terminal on the server with a pin of its own, the token page, and `porelo_host` changes
for the check's answer.

**What must be true.** Setting up a server as a machine of the organization is one wizard that asks one thing per page,
in order, and opens the next page only once what the page asks holds: the server answers, its key is compared, the
login is handed over, the check passes. A person never wonders whether to add or to prepare, and never trusts a key
the window could not yet know to be the server's.

## Why

The window test of 2026-11-07 (renting `porelo-move` on Scaleway Elastic Metal, Part B of the rental guide) found:

- **Finding 1.** *Add a machine* on the organization's page and *Prepare this machine…* in its row read as two ways
  to the same thing. A machine listed but not set up should say so on its row, *listed, not set up yet*, and offer one
  *Set up…* that leads into the wizard.
- **Finding 2.** The host key was fetched while Elastic Metal still ran its installer, and was shown as if it were the
  server's. The dialog says to wait for the provider in running text, below a key that already looks valid.
- **Finding 3.** The SHA256 fingerprint and the line `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` disappear in the
  running text: neither is tied to the key field, and the line is not shown as a command to run on the server.
- **Finding 4.** The key is fetched by itself half a second after the address is typed (`_addressChanged` in
  `lib/src/ui/host_dialog.dart`), so an address typed early fetches the installer's key. *Fetch SSH host key* should be
  the one way.
- **Finding 5.** Scaleway gave the new server the address of the deleted one. `ssh ubuntu@<address>` on the laptop
  then failed with `REMOTE HOST IDENTIFICATION HAS CHANGED`, since the person's own `known_hosts` still held the old
  server's key. The dialog fetches with `ssh-keyscan` (`lib/src/app/preparation_host_key.dart`), which reads no
  `known_hosts`, so it never said that the address was known with another key. The bootstrap line's own login, as the
  first login from the person's terminal, ran into the old entry.
- **Finding 6.** The bootstrap line was not run, as it is lost in the dialog's running text under the settings. Nothing
  in the dialog waits for it: the check and *Prepare* are offered beside it. Handing root's login over must be a page
  of its own, best in a terminal the window opens on the server as the provider's first login (such as `ubuntu`),
  where the person runs the line and types their own sudo password if one is asked.
- **Finding 7.** *Check this machine* greyed its button and showed no progress in view ("Checking the machine…" stands
  low in the long dialog), then said only "The check did not answer. This says nothing of the machine. The check ended
  without an answer." The cause was root's login on the Ubuntu image, whose `authorized_keys` line starts with
  `command="echo 'Please login as the user \"ubuntu\"…';sleep 10;exit 142"`: the words go to standard output, the exit
  is 142, standard error is empty, so `askHostCheck` in `packages/porelo_host/lib/src/host_check.dart` has nothing to
  name, and `HostCheckRun` in `lib/src/app/host_check_run.dart` drops `porelo-host`'s standard error as well.

- **Finding 8.** The host's token was offered in two places on one page, the machine's row (*Give it your token…*)
  and the put dialog (*Give it my … token…*), both one action, not said as one.
- **Finding 9.** *Give it my GitHub token…* showed no reaction when no token was kept: the step needed (sign in under
  *My forges*) was only the sentence already on screen.
- **Finding 10.** A token source that failed (this computer's `porelod` not answering, or a reply that could not be
  read) counted silently as no token: `thisComputersDeclarations` in `lib/src/ui/organization_access_dialogs.dart`
  turns every exception into "no declarations".
- **Finding 11.** Giving the host the token belongs in the setup as its own step, with a terminal for anything that
  must be typed (unlocking the Porelo-Vault), and the window must say which source it asked and why none fitted.

The operator decided: the wizard opens the server's terminal itself (page 5), and the token is a page of its own
(page 8); the row's button only leads there while a host still waits for its token.

Today all of it is one dialog (`HostDialog` in `lib/src/ui/host_dialog.dart`): name, address, key, fingerprint,
forge and VM choices, more settings, the bootstrap line, the check and *Prepare the machine* on one long page, with
the grey button's reason at the foot.

## The shape

Each page asks one thing; *Next* stays grey, saying why in words, until that thing holds. *Back* keeps what was
entered, and a change on an earlier page drops what the later pages proved from it.

1. **Which machine.** The organization's machine name (a choice of those listed and not set up), or a new one, which
   is listed then, so adding and setting up are one flow. Goes on when a name is chosen and the person is a verified
   Machine Admin of the organization.
2. **Where it is.** The server's address and the first login the provider gave (such as `ubuntu`). Says to wait until
   the provider reports the server ready and its installation finished. Goes on when the person says the provider
   reports it ready and the address answers SSH (a reachability probe, no key kept yet).
3. **Its SSH host key.** *Fetch SSH host key*, pressed by the person, never by itself. Shows the key and, tied to it in
   its own box, the SHA256 fingerprint, and beside it the command to run on the server, as a command with a copy
   button: `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`. A key pasted in place of fetching is shown the same.
   If the address is known with another key (in the person's `known_hosts`, as `ssh -G` names the files, or in
   `porelo-host`'s pin), the page says so plainly, as what usually happens when a rented address is given again,
   shows the old fingerprint beside the new one, and replaces the old entry only once the new one is compared.
   Goes on when *I compared this fingerprint* is ticked, and with no old entry left that the bootstrap login of page 5
   would run into.
4. **What it will run.** *This host has a forge of its own*, *This host runs VMs in its jobs*, and *More settings*
   folded. Goes on always; the choices are said back on the last page.
5. **Hand the login over.** The bootstrap line, in its own box with a copy button, saying it runs on the server as the
   first login and replaces root's keys with the Machine Admin's card key. *Open a terminal on the server* opens one in
   the window as the first login from page 2, trusting only the key compared on page 3; the person pastes the line
   there and types their sudo password if asked. *Try the root login* (also run by itself once the terminal ends)
   logs in as root with the card key and says what it found: open, refused, or still the provider's "log in as
   `ubuntu`" line, which means the line has not run. Goes on only once root logs in with that key.
6. **The check.** *Check this machine* runs the reading check, shows that it runs where the button is, and lists every
   finding. No answer says its cause in words: the machine's last line, or `porelo-host`'s own words and exit code.
   Goes on only when it passes.
7. **Prepare.** What will be done, the choices from page 4, and *Prepare the machine*; then the progress, the
   machine's words, and the end.
8. **Give it your token.** Shown when the host waits for a forge token. It lists each source in the order it is
   asked: the Porelo-Vault's declared entry for the organization's forge (by name), the token the window keeps for
   that forge, the secrets file. Beside each it says what that source answered: found, not declared, the vault
   shut, this computer's Porelo not answering (with its words), nothing kept. It offers the way on as actions, not
   sentences: *Unlock the Porelo-Vault* in a terminal here, *Sign in under My forges*, *Ask again*. *Give it the
   token* hands the one found over and ends once the host says it holds it; then the organization's row offers
   *Connect*. A source that fails is never counted as empty.

At *Prepare*, the key is fetched again as today; a key changed since page 3 leads back to page 3, saying so.

## Acceptance

- On the organization's page a machine listed but not set up says *listed, not set up yet* and offers *Set up…*;
  there is no second entry that prepares.
- Typing an address fetches nothing; only *Fetch SSH host key* does.
- Page 3 cannot be reached before the address answers SSH; page 5 not before the fingerprint is ticked; page 7 not
  before the check passes. Each grey *Next* says why.
- The fingerprint and the compare command stand together in the key's box, the command with a copy button.
- A key that changed between page 3 and *Prepare* starts nothing and returns to page 3.
- An address that the person's `known_hosts` holds with another key is said so on page 3, with both fingerprints;
  the old entry is removed only after *I compared this fingerprint*, and is untouched when the person goes back.
- Page 6 cannot be reached before root logs in with the card key; a root login answering with the provider's
  "log in as `ubuntu`" line and exit 142 is said as "the bootstrap line has not run", never as no answer.
- While the check runs, the page says so beside its button; a check without an answer names its cause, and what
  `porelo-host` wrote on standard error is shown, not dropped.
- The token is offered on page 8 and nowhere else; the row's and the put dialog's buttons lead to page 8 of that host.
- Page 8 names every source it asked and what it answered; a source whose ask threw says its words, never "none".
- A widget test walks all eight pages with a stand-in server, and one shows each *Next* grey with its reason.

## As built

- The wizard is `lib/src/ui/server_setup_wizard.dart` on the model `lib/src/app/server_setup.dart`, in the shared
  `Wizard`, which gained `goBackTo` for the key that changed since page 3. Pages 1 to 6 are its questions, *Check and
  start* says them back, and *Prepare* and *Give it your token* are its action pages.
- Page 1 offers only the machines listed and not set up. A new name is not listed from the wizard: the page says that
  an Organization Admin lists it with *Add a machine*, naming its first Machine Admin, which is the call that exists and
  the one role that may make it. One flow for both waits on that role question.
- Page 2's probe is `ssh-keyscan -T 5 -p 22` answering at all, run on *Next*; no key is kept from it. Whether the
  installation finished stays the person's word.
- Page 3 reads the person's `known_hosts` as `ssh -G` names them, counting only a key of the compared one's type, and
  the old line is taken out with `ssh-keygen -R` as *Prepare* starts, so going back leaves it. Page 5's terminal
  trusts its own pin, so the old line stands in nothing before then. `porelo-host`'s own pin is written per machine
  name by `up`, so it is not read here.
- Page 5's terminal is a terminal on this computer running `ssh` as the first login, with a `known_hosts` of its own
  holding only the compared key, never the person's. The root login is `porelo_host`'s `OpenSsh` offering the card key
  alone from the agent; exit 142 or the provider's line is "the bootstrap line has not run".
- *Give it your token…* on a row, and the put dialog's button, open the token's page for that host. The window gives
  no token by itself once a machine is ready; it says the machine waits for one.
- The organization page's heading offers *Set up a machine…* only where it is unavailable, to say why; each row sets
  its machine up.
- The widget test walks pages 1 to 6, *Check and start* and the start of *Prepare*; pages 7 and 8 are not walked to
  their end inside the wizard, since `HostRuns`' `up` does file work a widget test's clock never ends. The token's
  page is tested on its own, with each source's answer and the give.
- The old dialog's preparing form is no longer opened by the window, only by its tests; it stays for the protocol of a
  running preparation and the take-down, and its preparing part is to be removed with its tests.
- Not changed after the reading: the tests that read *listed, not set up yet* and *Set up a machine…* check which
  state a row says and which command a role is offered, not the wording, so they changed with the words.
- The walks that name the old dialog are in `porelo-project` (Part B of the rental guide) and are its to change.

## To be checked

- Which of [F365](README.md#f365), [F366](README.md#f366), [F358](README.md#f358), [F401](README.md#f401) and
  [F403](README.md#f403), in Review, this replaces in part, and what of them stays.
- How page 2 probes that SSH answers without trusting a key (`ssh-keyscan -T 5` answering at all, or a TCP connect to
  port 22), and whether "the installation finished" can be read from the server rather than only the person's word.
- Whether a new name on page 1 lists the machine through the same call as *Add a machine* today, with its *First
  Machine Admin*.
- The old entry, read in today's code: the window's `HostKeys` (`lib/src/app/host_keys.dart`) already finds a key
  changed for a plain machine (`changed`, `knownIn`, the files to take it out of) and can stand behind page 3.
  `porelo-host`'s pin is one `known_hosts` file per host name, beside the host's SSH configuration, overwritten with
  the one key by `trust` in `packages/porelo_host/lib/src/remote.dart`, so a new machine name keeps no old key, but
  the old name's file stays behind after its server is deleted. Whether the take-down removes it, and whether the
  same name on a new server is shown as known with another key, is to be read.
- The terminal of page 5: whether the window's own terminal (`lib/src/app/pty.dart`, `conpty.dart` on Windows) can run
  `ssh` as the first login with a pin of its own holding only the compared key, so the person's `known_hosts` is
  neither read nor written; and how `porelo-host check` tells the 142 line apart (its standard output, or a root login
  of its own before the check script).
- The walk's steps that name today's dialog (Part B of the rental guide, and the walks under `PORELO_WALKS`).
