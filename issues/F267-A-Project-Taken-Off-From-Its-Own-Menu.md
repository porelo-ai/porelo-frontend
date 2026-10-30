# F267 — A Project Taken Off From Its Own Menu

**Status:** Idea. Held as an Idea (operator, 2026-10-30, after walk 23): GUI changes wait until he has gone through the whole flow again.

**What must be true.** On a computer where the project is configured, its own menu's *Take this project off the server* is available to the host admin as to the project admin, and takes the project off the server it is on. The server menu's *Take a project off* stays for projects not configured here.

## Why

Operator's walk 23, step 12-1 (2026-10-30): the project's own *Take this project off the server* was unavailable for the host admin and pointed to the server menu. Checking the secrets entries first is [F261](README.md#f261).

## Plan

- The project menu's action opens the same take-off as the server menu, with the project and server filled.
- **Red first:** a widget test that the host admin's project menu offers the take-off.

## Estimate

`F267 size=XS est=10 basis=median XS 10 (8 records)`
