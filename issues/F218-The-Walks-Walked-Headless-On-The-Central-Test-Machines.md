# F218 — The Walks Walked Headless On The Central Test Machines

**Status:** Estimated; placed after sprint 6i, since nothing new is built before the operator's tests of 6 to 6i close.
**Size:** M - a runner that walks each sprint walk through its panel under `Xvfb`, the display set up by the run itself on a leased host and on a GitHub runner, and its job.

**What must be true.** Every sprint walk in `doc/walks/` is walked headless on the central test machines before the operator meets it: the interface on a hidden display, driven step by step through the walk's panel, each step's pointer checked on screen and each move of the panel checked, as `tool/walk_18_e2e.sh` walks walk 18 on the laptop. The run installs and starts the display itself; no hand sets it up.

## Why

A walk the operator met before an agent had walked it stalled on values it never gave, a second machine it never named and steps already done; the operator broke it off. A walk is walked by the agent before it reaches the operator, and on the central machines that walking cannot depend on a display somebody set up by hand.

## Plan

- **One runner per walk, from `tool/walk_18_e2e.sh`:** a home, settings, secrets file and keyring of the run's own; the real `keepassxc-cli`; the test machine reached through an agent holding its key.
- **The display by the run itself:** on a GitHub runner the job step installs `xvfb` and starts the walk under `xvfb-run`; on a leased host its setup script does the same before the walk.
- **A job for the walks**, run on a change to `doc/walks/` or to the interface they point at.
- **Red first:** a walk step pointing at a key the interface does not show on that step fails the run.

## Acceptance

- Each sprint walk is walked headless from its first step to its last on a GitHub runner, with no display prepared by hand.
- The same runner walks it on a leased host.
- Seen to fail: a step whose pointer is off screen stops the run at that step, naming it.
