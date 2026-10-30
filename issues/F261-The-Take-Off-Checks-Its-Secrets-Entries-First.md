# F261 — The Take-Off Checks Its Secrets Entries First

**Status:** Accepted.
**Size:** XS - the take-off checks that the secrets file holds every entry it needs before the master password is used for the stop.

**What must be true.** Before *Take the project off* runs anything on the host, it checks under the one master password prompt that the secrets file holds every entry the take-off will feed (such as `shared/forge-central-token`). A missing entry is named, with the way to add it, and nothing is run on the host until it is there. No value is shown, logged or put on a command line.

## Why

Operator's walk 23, step 12-1 (2026-10-30): the take-off asked the master password, then failed with "no entry shared/forge-central-token" on the host admin's laptop.

Taking the project off from its own menu is [F267](README.md#f267), held as an Idea with the other GUI changes.

## Plan

- The take-off's feed (`lib/src/app/host_stop_feed.dart`) knows its acts' entries; the terminal run lists them with `keepassxc-cli ls` before the stop and stops with the missing entry's name.
- Project removal uses `SecretsFile.projectRemovalTokenLine()` before the SSH command. Since its local inputs contain no verified repository inventory, the same preflight requires `shared/forge-central-token` for every take-off.
- **Red first:** a test that a run whose file lacks `shared/forge-central-token` names it and starts no stop on the host.

## Test

Only the change: the test above and the feed's own tests. No VM run.

## Implementation

- The terminal lists, reads, and validates required entries under the same master password used by the feed before any host command, including a drive login, matrix admission, or certificate request. Missing, empty, unreadable, malformed base64, and incomplete or invalid CA entries name their remedy in KeePassXC.
- The stop feed uses the values already checked locally. Take-off requires `shared/forge-central-token` locally before SSH starts. A missing entry names the entry and how to add it in KeePassXC; an existing unusable entry also refuses locally. Values remain inside the terminal shell and standard input.
- Take-off accepts a project name and the host's connection record, which contains no project repository list. The server-menu action can name a project not followed on this computer. Bring reads `project.yml` from a verified signed revision, but take-off retains neither that revision nor its repositories. Without a verified local repository list, take-off requires the entry for every project and makes no host request to determine the requirement.
- Process tests cover missing entries, listing and reading failures, the one-password success path, and removal refusing before SSH starts. The existing secrets-file tests cover real CLI feeds and migration.

## Validation

- Red first: empty and unreadable entries were reported as absent, and malformed values let commands before the pipe reach SSH. An absent removal token also started SSH; the replacement process tests failed their no-SSH assertions before the required-entry check was restored. A kept CA for another network also reached SSH before its refusal; the process regression failed its no-SSH assertion before the network check moved into preflight.
- The required removal-entry fix reruns all four targeted files: 18 removal, 36 secrets file, 43 stop feed, and 12 take-off tests pass, 109 total with none skipped. The three replacement tests failed before the fix: the raw feed succeeded without an entry, and both removal cases started SSH. The final added code diff has a read-only review with no material findings against the four applicable Dart skills, version `2026.910.3`.
- Document tests pass: 29 with none skipped. Formatting, `dart analyze`, `check-shared`, `check-citations`, `check-readmes`, `check-doc-site`, and `check-actions` pass on the local worktree. No full workflow or VM run.
- The six process tests of the desktop composer now live in `test/app/host_stop_feed_test.dart`, with its package import. The added cases cover every command before the pipe and invalid CA halves, including the kept network.
- The final changes and the subsequent CA network fix have read-only reviews with no remaining findings against `dart-add-unit-test`, `dart-build-cli-app`, `dart-run-static-analysis`, `dart-use-pattern-matching`, and `dart-write-documentation` version `2026.910.3`, and `flutter-add-widget-test` version `2026.911.3`. Plain `dart format` and `dart analyze` pass.

## Deferred

- A repository-less project also needs `shared/forge-central-token`: take-off has no verified local repository list to establish that the entry is unnecessary. Exempting it needs a verified local record of the project's repositories.
- Replace the raw Bash substring assertion in `test/app/host_stop_feed_test.dart` with a process assertion.
- Updating the terminal's GUI explanation that describes the removal token as optional waits for the held flow review.

## Estimate

`F261 size=XS est=10 basis=median XS 10 (8 records)`
