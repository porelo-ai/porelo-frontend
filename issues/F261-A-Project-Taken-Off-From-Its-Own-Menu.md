# F261 — A Project Taken Off From Its Own Menu

**Status:** Accepted.
**Size:** S - *Take this project off the server* in the project's own menu works for the host admin too, and the take-off checks its secrets entry before asking anything.

**What must be true.** On a computer where the project is configured, its own menu's *Take this project off the server* is available to the host admin as to the project admin, and takes the project off the server it is on. The server menu's *Take a project off* stays for projects not configured here. Before the master password is asked, the take-off checks that the secrets file holds every entry it will need (such as `shared/forge-central-token`); a missing one is named with a way to add it, and nothing is asked or run until it is there.

## Why

Operator's walk 23, step 12-1 (2026-10-30): the project's own *Take this project off the server* was unavailable for the host admin and pointed to the server menu. There the take-off asked the master password, then failed with "no entry shared/forge-central-token" on the host admin's laptop.

The server menu's project name as free text is [F239](README.md#f239)'s (a list of the projects on that server).

## Plan

- The project menu's action (`lib/src/ui/`, the project's menu) opens the same take-off as the server menu, with the project and server filled.
- The take-off lists its needed entries and checks them with `keepassxc-cli ls` under the one master password prompt, before the stop is run; a missing one offers to add it in the same terminal.
- **Red first:** a widget test that the host admin's project menu offers the take-off; a test that a missing entry stops before the stop runs, naming the entry.

## Test

Only the change: the tests above. On VM A or the Laptop: one take-off attempt with the entry missing.

## Estimate

`F261 size=S est=15 basis=median S 15 (11 records)`
