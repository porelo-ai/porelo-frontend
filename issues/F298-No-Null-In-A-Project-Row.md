# F298 — No "null" In A Project Row

**Status:** Idea.
**Severity:** low.
**Size:** S - one subtitle part of the projects page, with its test; no contract with another repository.

**What must be true.** A project row under *Projects* never shows the word "null"; a tunnel with nothing to say adds
nothing to the row.

## Why

A project row on a card host reads "on <host> · null · Environment not prepared". In `lib/src/ui/projects_page.dart`
the subtitle takes `tunnel.words` whenever a tunnel exists, and `Tunnel.words` (`lib/src/app/tunnel.dart`) is null for
a tunnel that is up with no vault problem; `join(' · ')` writes that as "null".

## Plan

- Take the part as `?tunnel?.words`, keeping "Tunnel not reached" and "No SSH tunnel needed" where there is no
  tunnel.
- **Red first:** a widget test with a card machine whose tunnel is up and has nothing to say: the row has no "null".

## Acceptance

- No project or machine row shows "null" for any tunnel state.
