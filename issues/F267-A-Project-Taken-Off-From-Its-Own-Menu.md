# F267 — A Project Taken Off From Its Own Menu

**Status:** Idea. Held: GUI changes wait until the whole flow has been gone through again.

**What must be true.** On a computer where the project is configured, its own menu's *Take this project off the server* is available to the host admin as to the project admin, and takes the project off the server it is on. The server menu's *Take a project off* stays for projects not configured here.

## Why

On a computer where the project is configured, the project's own *Take this project off the server* is unavailable for the host admin and points to the server menu instead. Checking the secrets entries first is [F261](README.md#f261).

## Plan

- The project menu's action opens the same take-off as the server menu, with the project and server filled.
- **Red first:** a widget test that the host admin's project menu offers the take-off.

## Estimate

`F267 size=XS est=10 basis=median XS 10 (8 records)`
