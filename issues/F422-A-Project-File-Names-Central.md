# F422 — The Window Reads A Repository's Address From `central:`

**Status:** Accepted (operator, 2026-11-06).
**Size:** XS - the window's one reader of `project.yml` takes a repository's address from `central:`.

**What must be true.** A project file names each repository's central forge as `central:`; `upstream:` goes away
(operator, 2026-11-06), and porelo refuses it with words to rename it. The window reads a project file in one place,
`ProjectShape.of`, for the forge a project's waiting changes concern; it takes each repository's address from
`central:`, and from `upstream:` in a file written before the rename, so that it keeps working until the operator signs
the rename.

Everything else the window says of an upstream comes from porelo's answers and verbs, not from the file: `project
show`'s `upstream` and `central` per repository, and `--upstream` of `project init` and `project repository add`.
Those follow porelo's form as Agent Core hands it over.

## Done

`machine_binding.dart`: `ProjectShape.of` reads `central:`, else `upstream:`. Red first: a file naming `central:` read
as having no repositories.

Review reading: the end-to-end tests' project file (`integration_test/support/project_file.dart`) wrote `upstream:`, which a porelo past the rename refuses; it writes `central:` now, so `tool/e2e.sh` needs that porelo on the test machine.
