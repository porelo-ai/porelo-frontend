# F566 — An SSH Console On A Machine's Page

```json
{
  "$schema": "issue-1.json",
  "id": "F566",
  "title": "An SSH Console On A Machine's Page",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 12,
  "blockedBy": [],
  "covers": "Story ST361: a remote machine's sections offer an SSH Console below Machine Admins, a terminal in the window on that server as the person's own account, by the pinned host key and the key the window already uses for the machine."
}
```

**Why this size.** A new section on a machine's page and its terminal. Both pieces exist: the pseudoterminal
(`lib/src/app/pty.dart`, ConPTY on Windows) and the terminal view that a work session by hand uses, and each machine's
ssh options (`Machine.loginSshOptions`: the card's config, its pinned host key and its identity). What is new is the
section, the ssh command line, and the guards, the Windows path included.

**What must be true.** A person checking a machine by hand during a live test opens a shell on it from the window,
without a key file, a password prompt in the window, or trusting a key the machine was not pinned with.

## Plan

- A section *SSH Console* under a remote machine, below *Machine Admins*, shown only for a machine reached over ssh
  (not this computer, not WSL).
- It opens a terminal in the window, in the same view a work session by hand uses. It runs
  `ssh <the machine's loginSshOptions> -t <account>@<address>` on this computer's pseudoterminal. The key comes from
  the agent the window already uses for the machine (the card's key, as KeePassXC adds it), and trust is the pinned
  host key alone (StrictHostKeyChecking on the card's known_hosts).
- A machine reached through a tunnel: on Linux the console goes through the card's own ssh config and its control
  master, as every other command to that machine does. On Windows it opens its own connection by the same config.
  When the machine is not reachable, the section says why, in the words its page already uses, and starts nothing.
- **User or root.** A person who is the machine's root admin (an Organization or Machine Admin with root access) sees
  a switch between their own account and root.
  - As root, the console logs in as root with the key that person has for root on that machine, from the agent, as
    for their own login. There is never a stored password, and never a sudo workaround unless the host offers one.
  - Others see no switch.
  - How the window knows who may log in as root is to be settled with Agent Machines: either the host card's admins
    and root keys, as porelo-host records them, or a new record there.

## Acceptance

- A guard that the section is offered for a remote machine and not for this computer or WSL. Another guard that the
  command line carries the machine's pinned options and no others, with no key file and no password option. A
  feature scenario that opens it against a stand-in. Each is red first.

## Built

- A machine section *SSH Console* (`MachineSection.console`), last in a machine's tree, below *Managing this machine*
  or *Machine Admins*. The tree shows it only for a machine reached over ssh (`sshConsoleOffered`: a host and a remote
  socket, of no kind or a host's); this computer, a WSL distribution and a forwarded socket show none, and their page,
  where it is opened anyway, says why.
- *Open the SSH console* runs `ssh <the machine's loginSshOptions> -t <its host>` (`sshConsoleCommand`) on this
  computer's pseudoterminal (ConPTY on Windows, by `openHere`), in the terminal view the window's other terminals
  use, in a dialog over the page. No remote command follows the host, so the account's login shell starts. The
  options are the machine's own and no others: for a card's machine its ssh config, through the card's control
  master on Linux and a connection of its own by the same config on Windows; no key file and no password option. A
  host that starts with a dash opens nothing.
- Where the machine is not reachable here, or does not answer, the button stands grey with the page's own words
  (`whyNotReachableHere`, or *<machine> does not answer.*) and nothing is started.
- A machine added by its address (no card) has no pin of its own: its console takes its options as every other
  command to it does, which are none, so ssh reads the person's own config and known_hosts and asks before it trusts
  an unknown host key, in the terminal.
- **The root switch is hidden.** The window cannot know who may log in as root on a machine: the organization's card
  names a machine's admins and their keys (`hosts[].admins`), but not whether root takes any of those keys after
  `up`, nor which. **To be recorded with Agent Machines:** per machine, whether root logs in by key after setup and
  with which persons' keys, served by `porelo org` beside the machine's admins (for example a `root` flag on each
  `hosts[].admins` row). With that, the switch shows for those persons and runs the same line with root as the login.
- Tests: `test/app/ssh_console_test.dart` (offered or not, the exact command line, a dashed host), the console case
  of *each section of a machine reads that machine* and *the SSH Console of a machine that does not answer says so
  and starts nothing* in `test/ui/machine_sections_test.dart`, and `test/features/ssh_console.feature` against the
  fake terminal; no real ssh is started.

