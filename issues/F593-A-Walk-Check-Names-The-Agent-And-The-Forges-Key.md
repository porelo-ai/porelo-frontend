# F593 — A Walk Check Names The Agent And The Forge's Key

```json
{
  "$schema": "issue-1.json",
  "id": "F593",
  "title": "A Walk Check Names The Agent And The Forge's Key",
  "state": "Backlog",
  "size": "XS",
  "priority": "Medium",
  "rank": 114,
  "blockedBy": [],
  "covers": "Before a walk makes any repository, its check says that the walk VM lacks the agent the project file names or git's host key for the forge, with how to add it."
}
```

**Why this size.** XS: two more lines of what `tool/walk_idea.sh check` asks the VM, and their wording.

**What must be true.** A walk on a VM without the agent its seed's project names, or without github.com's host key
where git reads it, stops at its check, before it makes and deletes repositories at the forge, and says what to add.

## Why

On a new walk VM (walk1, 15 November) the check said the VM had what the run needs, and the run failed twice after
it had made the story's repositories: first `git clone` on the VM refused github.com ("Host key verification
failed": `prepare` adds the forge's key to porelo's `known_hosts` only, not where git reads it), then the window's
first start found no agent ("install porelo-agent-pi"). Each cost a run with its repositories made and taken away.

## Plan

- `check` in `tool/walk_idea.sh`: name a missing agent where `porelo agents` on the VM does not list `pi` (the agent
  the walk seeds' project files name), with the package that installs it (`porelo-agent-pi`); name github.com's host
  key missing where `ssh-keygen -F github.com` finds it neither in the person's own known hosts file of ssh nor in
  the system's.
- `prepare --known-hosts FILE`: add the lines also to the person's own known hosts file of ssh, where git reads them, as
  it adds them to porelo's.
- The usage text at the head of the script says both.
- **Red first:** the script has no test yet. A new `test/tool/walk_idea_check_test.dart` runs `check` against a
  stand-in VM (a local shell for `on_vm`, a `porelo` printing its agents) lacking each, expecting the check to name it;
  red before the change. The size grows to S if the stand-in needs the script split.

## Acceptance

- `check` names a missing `pi` and a missing github.com host key for git, each with how to add it. Seen to fail: a
  stand-in VM lacking each, said fit to run.
- `prepare --known-hosts` leaves git able to verify github.com. Seen to fail: a stand-in VM after `prepare` without
  the key in the person's known hosts file of ssh.
