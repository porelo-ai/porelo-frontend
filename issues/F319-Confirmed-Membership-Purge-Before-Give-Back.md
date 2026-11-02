# F319 — Confirmed Membership Purge Before Give-Back

**Status:** Analyzed.
**Size:** S - one host command, its session and confirmation dialog, with behavioral tests.

**What must be true.** Giving a server back shows every person who still holds host administration or project
memberships and explicitly confirms permanent removal of those accounts and their contents. Only the displayed
logins may be purged. With an unreadable status nothing is purged and the ordinary give-back stays, whose play still
refuses while anyone holds a membership; a failed purge keeps the server.

## Plan

- `packages/porelo_host/bin/porelo_host.dart` accepts read-only `down --memberships` and repeatable `--purge LOGIN`.
  Purge logins match `^[a-z][a-z0-9-]{0,31}$`, exclude `porelo` and `porelo-` service accounts, and are checked
  before connection setup. Reading memberships, purging and forced give-back are mutually exclusive modes.
- `packages/porelo_host/lib/src/host_run.dart` reads `/usr/local/sbin/porelo-host-person org status` through the
  rental lookup, pinned host key and plan login. Its `persons` list requires each login, known state,
  boolean `host_admin`, project and role pairs, and a nonempty string for `purge_on` when present.
  A holder has host administration or at least one project. Missing or malformed data refuses the read.
- Status uses an `org-status` Step with the validated JSON in `words`. A purge uses `purge-<login>` Steps and
  runs as root after trust and before the down play. The first failed purge stops without a play or release.
  Failed status and purge diagnostics retain both output streams.
- `lib/src/app/host_session.dart` reads the status Step and passes confirmed logins to down. The take-down path
  in `lib/src/ui/host_dialog.dart` shows holders before enabling the destructive choice and reads them again after
  a refusal. Closing the dialog starts no destructive command.
- The first regression tests cover purge ordering and failure retention in `host_run_test.dart`, rejected shell
  input in `down_cli_test.dart`, and displayed-name confirmation and admission races in `host_dialog_test.dart`.

## Acceptance

- Status reads rent nothing, release nothing, and run no setup or teardown play, including for a host not connected
  in the interface. Malformed status never becomes an empty holder list.
- Each named login is purged once before the play, and an unlisted login is never added automatically. A failed
  purge stops subsequent purges, the play and release; its diagnostics remain visible.
- No holders preserves ordinary teardown. A new holder after a refused play requires another explicit choice.
  An unreadable status, as on a server whose setup stopped before the helper, leaves the ordinary give-back. Any
  failed give-back, a lost root login among them, then offers the separate loss-confirmed one.
- CLI and widget tests assert commands, effects and names without fixing whole sentences in assertions.
