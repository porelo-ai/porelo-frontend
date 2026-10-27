# F148 — An Agent For Each Repository, At One Click

**Status:** Analyzed; blocked by two `porelo` requirements not yet filed, raised in the channel: the agent a
repository names, and the values a project declares.
**Size:** L - a new wizard over the existing start, M on its own, but it crosses repositories: neither the agent of a
repository nor a project's declared values is on the wire yet.

**What must be true.** On a machine where the person has a project, the interface starts, at one
click, a task for each of the project's repositories that names an agent in `project.yml`, each
with that agent. The person can leave out repositories before the start and give each task the
values `issue` and `phase` (`porelo`
[B189](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b189)) where the project
declares them. An agent that is not signed in there is signed in on the way, as at a single task's
start. Tasks already running are not started twice.

## Why

`host up` no longer starts tasks (`porelo-project`
[PJ40](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj40), decided
2026-10-23): the machine and the work on it are kept apart. Starting a project's agents is the
person's step after `up`, and with a dozen repositories, one task at a time is too slow. It is the
same on the rented host as on any machine.

## Plan

- **What the contract lacks, read in `porelo` at 0b02c1b7:**
  - **No repository names an agent.** `ProjectSchema` allows a repository `upstream`, `description`, `egress`,
    `limits`, `issues` and `image`, and `Start`'s IDL says "a project file names neither an agent nor a provider";
    `porelo-project` [PJ53](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj53) calls the key
    new. `porelo` needs an `agent` key under `repositories.<repository>` and `Repository.agent` in `Projects` (`""`
    when none is named), and `Start` taking the repository's agent when none is given would be a default this
    interface must not rely on: it sends the agent it showed.
  - **A project's declared values are not readable.** `Start` and `CanStart` take `parameters` and refuse with
    `PARAMETER_REFUSED`, whose `detail` is prose; `Project` carries no declarations, and `ProjectFileSchema` describes
    keys, not this project's values. `porelo` needs `Project.parameters`: each declared name with whether it is
    required, its allowed values where they are a fixed set, and its default. Without it the interface would guess
    which fields to ask for, or parse a refusal.
  - Both are in [Contract-Gaps](../doc/Contract-Gaps.md) and come off once landed. An older daemon without either
    field gets no such command (absent, never "no agent named").
- **The command:** `project.startAgents`, *Start an agent for each repository*, in `Home.projectMenu`
  (`lib/src/app/commands.dart`), unavailable with its reason when no repository names an agent, the machine is not
  answering, or the daemon is too old to say.
- **The model:** `StartAgents` in `lib/src/app/start_agents.dart`, beside `StartWork`, holding one row per repository
  that names an agent: chosen or left out, its agent, the values given, and `CanStart`'s answer for that row. It reuses
  `StartWork`'s name rule and suggestion (moved to a shared function, not copied) and `whyNotStart`.
- **Already running:** a row whose repository has a task with the same agent and the same `issue` and `phase` values
  (`Task.repository`, `Task.parameters`) that is running is shown as running and not started; what a stopped one does
  is QF60.
- **The wizard** (`lib/src/ui/start_agents_view.dart`, on `wizard.dart`'s `WizardStep`), one step per screen:
  1. *Which repositories* - every repository naming an agent, checked; one naming none is listed as such, not
     offered.
  2. *Issue and phase* - only where the project declares them, with the declaration's allowed values; QF61 decides
     whether one value covers every row.
  3. *Sign-ins* - each distinct agent whose `CanStart` answers `CREDENTIAL_MISSING` or `CREDENTIAL_UNUSABLE`, signed
     in by the same `onLogIn` path `StartWorkView`'s *Sign in first* takes, then asked again; the step cannot advance
     while one is missing.
  4. *Summary* - every task with its repository, agent, name, mode and values, and every row left out with why.
- **The start:** `FleetBackend.startTask` per row, one after another, each with `now: true` so a build does not hold
  the next; each row shows its own outcome, and a refusal stays that row's answer and does not stop the others.
  Nothing is shown as started before `Start`'s final reply says `CREATE` or `RESUME`.
- **Red first:** `test/features/start_agents.feature`, against `FakeBackend`: a project of three repositories, two
  naming an agent, one of whose tasks runs - one task is started, the running one is not started again, and the
  repository naming no agent is not offered. Then a missing sign-in that holds the wizard on its step, and a refusal
  for one row while the other starts. The client's two new fields get a `MockDaemon` test reading them absent from an
  older daemon.

## Acceptance

- A project with three repositories, two naming an agent, one of whose tasks runs: one click and the summary start
  exactly one task, with the named agent, and the running one is shown as running.
- A repository left out in the first step gets no task; a declared `issue` and `phase` arrive in `Task.parameters` as
  given.
- An agent with no sign-in holds the wizard at *Sign-ins* until it is signed in; nothing starts before.
- One row refused by the machine keeps its refusal on screen while the others start.
- Against a daemon without `Repository.agent` the command is unavailable with its reason, never offered empty.
- Seen to fail: the feature's first scenario red before `StartAgents` exists.

## Open questions

- **QF60:** A stopped task for the same repository, agent and values: brought back (`RESUME`, its session continued),
  or a new task beside it? Recommended: brought back, said in the summary as "continues".
- **QF61:** `issue` and `phase`: one value for every task, or each row its own? Recommended: one value for all,
  changeable per row, since an issue that spans repositories is one task per repository with the same issue.
- **QF62:** The mode: every task attended (`AGENT`, a person attaches later), or unattended with one prompt for all?
  Recommended: `AGENT`; an unattended start of a dozen agents with one prompt is a separate decision.

## To be checked

- Whether `Start` with `now: true` returns before the image build on a project never prepared, measured against a
  daemon, so twelve starts do not take twelve builds in a row.
- Whether a sign-in started from the wizard returns to it, as it returns to `StartWorkView` today.
