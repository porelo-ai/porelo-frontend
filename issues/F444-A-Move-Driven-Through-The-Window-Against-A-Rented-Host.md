# F444 — A Move Driven Through The Window Against A Rented Host

**Status:** Implementing.
**Size:** M - a local VM that runs the window under a virtual display, one feature file of a move's main scenarios
reusing the steps of the suite against a leased machine, its report, and one try on a rented server.

**What must be true.** The main scenarios of a move are driven through the real window, unattended, against a rented
host that is already set up, acting as one test person, and each step checks on the host itself what the window made
happen. The window runs in a local VM with no desktop, so no window, notification or keyboard focus ever reaches a
person's display.

## Why

A move's faults in the window show today only in the operator's own test, after the host is rented and set up. Every
Build already drives the window against a leased machine (`tool/e2e.sh` and the suite in `integration_test/`), but
against a single machine, not a host of an organization with its projects, tasks, builds and gate.

## What it builds against (in words)

- **The host:** a rented server on which `porelo-host`'s set-up has run, with its forge, its runner, the project's
  room and porelod; it follows a test organization whose every role (owner, machine admin of the host, project admin,
  developer) is one test person. Its address is given to the run.
- **The test person:** a login on the host and on the central forge, an ssh key and a forge token of that person
  alone, reaching that test organization and nothing else. The key is used through an ssh agent forwarded from the
  computer starting the run; the token is read from that person's own vault there and given on standard input only.
- **The agents' provider:** one reached by an API key from the test person's vault, so no browser is needed.
- **What the window sees** is the daemon's contract as served (`org.fuin.porelo.Tasks1`), nothing more.

## Plan

- **The VM:** Ubuntu 24.04 under libvirt, no desktop; Flutter from its tarball (not the snap, which needs a person's
  D-Bus session); Xvfb through `xvfb-run -a -s '-screen 0 1280x800x24'`, `GDK_BACKEND=x11`, `WAYLAND_DISPLAY` unset, and
  a `notify-send` that shows nothing first on the PATH, as `tool/e2e.sh` sets them. The test person's key never enters
  the VM.
- **`integration_test/rehearsing_a_move.feature`**, run by `tool/e2e.sh` with the host's address, each scenario checked
  on the host over ssh:
  - the host listed and connected from the organization's card; its facts page answers;
  - the organization's pages: the host, its machine admin, the project;
  - the project on the host: each repository carried or not, its state at central, its tasks, as the host says them;
  - *New work*: the start's check, the model it will run, the task's name; the task started;
  - the batch start: one task per repository, nothing signed in twice;
  - *Needs you*: a grant a start asks for, granted from there;
  - the builds on a task's tile once the host's runner built its first push;
  - the gate's review of a task's push (its commits and who made them) and the push to the host's forge;
  - *Take Porelo off* for the project, as far as the window does it.
- **The report:** one line per scenario, `OK` or `FAIL`, from `tool/test_report.dart`, with the screen's text on a
  failure, into the run's directory; fail-fast; a time budget of its own (about 60 minutes), after which the window's
  part is stopped and the run goes on without it.

## Acceptance

- One run against a rented host passes every scenario above, or names the one that failed with the screen's text and
  what the host said.
- During the run nothing appears on the display of the computer that started it: no window, no notification.
- No key leaves the computer that started the run; no token is on a command line, in a log or in the report.

## To be checked

- Whether the host's runner builds within the time budget, or the builds scenario waits longer than the rest.
- Whether a task's first push needs anything typed on the host; if it does, the scenario stops before it and says so.
