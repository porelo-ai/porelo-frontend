# F266 — The Project Screen Shows Its Persons

**Status:** Accepted.
**Size:** M - a design, then its screen: a project shows the server it is on and its persons with their roles and state, and its actions are chosen from there.

**What must be true.** A project's screen shows the server it is on, its project admin and its developers, each with their state (admitted, pending sync, locked), and offers the project's actions from those rows: change or remove a developer, take the project off its server. The design is filed and agreed before it is built.

## Why

Operator's walk 23, step 12-4 (2026-10-30): a project should show its persons, and actions be chosen from those lists, not from free-text dialogs.

Decided in the morning (2026-10-30): the Project screen design is the first of two designs ([F265](README.md#f265) is the second), followed by a read-only query contract with Agent Machines.

## Plan

- A design page, written before code, with the project's server, persons, states and row actions.
- The persons from the signed access file and the last sync's answer ([F253](README.md#f253)) until the query contract gives them from the host.
- **Red first:** the built screen's widget test that a developer with a pending sync shows "pending sync".

## Test

Only the change: the screen's widget tests. On VM A: one look at the project's screen.

## Estimate

`F266 size=M est=60 basis=median M 61 (24 records)`, the query contract not included.
