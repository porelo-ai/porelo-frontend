# F148 — An Agent For Each Repository, At One Click

**Status:** Implementing; blocked by `porelo`
[B298](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b298).
**Size:** L - a new wizard over the existing start, M on its own, but it crosses repositories: the agent a repository
names is not on the wire yet.

**What must be true.** On a machine where the person has a project, the interface starts, at one
click, an attended task for each of the project's repositories that names an agent in `project.yml`,
each with that agent: the long-running agents of their repositories, each with its session and a
shell for the person, not work on one issue. The person can leave out repositories before the
start. An agent that is not signed in there is signed in on the way, as at a single task's start.
Tasks already running are not started twice.

## Why

`host up` no longer starts tasks (`porelo-project`
[PJ40](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj40), decided
2026-10-23): the machine and the work on it are kept apart. Starting a project's agents is the
person's step after `up`, and with a dozen repositories, one task at a time is too slow. It is the
same on the rented host as on any machine. An unattended agent is always started for one issue,
its phase following from that issue, which is a start of its own and not this one.

## Plan

- **What the contract lacks, read in `porelo` at 0b02c1b7:** no repository names an agent. `ProjectSchema` allows a
  repository `upstream`, `description`, `egress`, `limits`, `issues` and `image`, and `Start`'s IDL says "a project
  file names neither an agent nor a provider"; `porelo-project`
  [PJ53](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj53) calls the key new. `porelo`
  [B298](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b298) adds an `agent` key under
  `repositories.<repository>` and `Repository.agent` in `Projects` (`""` when none is named), with an optional
  nickname: `Repository` also carries `nickname` and `goesBy`, the name the daemon composes (`Agent Pi`, or
  `Agent porelo-pi` without a nickname), which each row, task and summary line shows verbatim. `Start` taking the
  repository's agent when none is given would be a default this interface must not rely on: it sends the agent it
  showed. The gap is in [Contract-Gaps](../doc/Contract-Gaps.md) and comes off once landed; an older daemon without
  the field gets no such command (absent, never "no agent named").
- **The command:** `project.startAgents`, *Start an agent for each repository*, in `Home.projectMenu`
  (`lib/src/app/commands.dart`), unavailable with its reason when no repository names an agent, the machine is not
  answering, or the daemon is too old to say.
- **The model:** `StartAgents` in `lib/src/app/start_agents.dart`, beside `StartWork`, holding one row per repository
  that names an agent: chosen or left out, its agent, and `CanStart`'s answer for that row. Every task is
  `Mode.agent`, with no prompt and no parameters. It reuses `StartWork`'s name rule and suggestion (moved to a shared
  function, not copied) and `whyNotStart`.
- **Already running:** a row whose repository has an attended (`AGENT`) task with the same agent (`Task.repository`,
  `Task.agent`, `Task.mode`) that is running is shown as running and not started; an unattended run of that agent is
  work on one issue, not the repository's agent. A stopped one is brought back (`RESUME`, its session continued), and
  the summary says it "continues" (decided).
- **The wizard** (`lib/src/ui/start_agents_view.dart`, on `wizard.dart`'s `WizardStep`), one step per screen:
  1. *Which repositories* - every repository naming an agent, checked; one naming none is listed as such, not
     offered.
  2. *Sign-ins* - each distinct agent whose `CanStart` answers `CREDENTIAL_MISSING` or `CREDENTIAL_UNUSABLE`, signed
     in by the same `onLogIn` path `StartWorkView`'s *Sign in first* takes, then asked again; the step cannot advance
     while one is missing.
  3. *Summary* - every task with its repository, agent and name, whether it is new or continues, and every row left
     out with why.
- **The start:** `FleetBackend.startTask` per row, one after another, each with `now: true` so a build does not hold
  the next; each row shows its own outcome, and a refusal stays that row's answer and does not stop the others.
  Nothing is shown as started before `Start`'s final reply says `CREATE` or `RESUME`.
- **Red first:** `test/features/start_agents.feature`, against `FakeBackend`: a project of three repositories, two
  naming an agent, one of whose tasks runs - one task is started, the running one is not started again, and the
  repository naming no agent is not offered. Then a stopped task that is brought back, a missing sign-in that holds
  the wizard on its step, and a refusal for one row while the other starts. The client's new field gets a
  `MockDaemon` test reading it absent from an older daemon.

- **Declined from its readings, with the reason:** an in-flight start is not cancelled when the wizard is left,
  since cancelling `Start`'s stream may stop a task half made, and the wizard says the start may keep running; the
  confirmation on leaving an untouched wizard after the machine answered is wording, not harm; a stopped task
  without a name is refused but not tested, since only a daemon that names agents offers the command, and every
  such daemon names its tasks.

## Acceptance

- A project with three repositories, two naming an agent, one of whose tasks runs: one click and the summary start
  exactly one task, attended, with the named agent, and the running one is shown as running.
- A stopped task of a repository's agent is brought back with its session, not started beside it.
- A repository left out in the first step gets no task.
- An agent with no sign-in holds the wizard at *Sign-ins* until it is signed in; nothing starts before.
- One row refused by the machine keeps its refusal on screen while the others start.
- Against a daemon without `Repository.agent` the command is unavailable with its reason, never offered empty.
- Seen to fail: the feature's first scenario red before `StartAgents` exists.

## To be checked

- Against a daemon with `porelo` [B298](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b298) published:
  `Repository.agent`, `nickname` and `goesBy` read as agreed, the command offered, and the walk of the acceptance
  through.
- Whether `Start` with `now: true` returns before the image build on a project never prepared, measured against a
  daemon, so twelve starts do not take twelve builds in a row.
- Whether a sign-in started from the wizard returns to it, as it returns to `StartWorkView` today.
