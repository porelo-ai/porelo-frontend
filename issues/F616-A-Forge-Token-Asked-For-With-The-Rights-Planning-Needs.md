# F616 — A Forge Token Asked For With The Rights Planning Needs

```json
{
  "$schema": "issue-1.json",
  "id": "F616",
  "title": "A Forge Token Asked For With The Rights Planning Needs",
  "state": "Analyzed",
  "size": "XS",
  "priority": "High",
  "rank": 2,
  "blockedBy": [],
  "covers": "Where the window asks for the person's forge token, it names the rights planning in GitHub Issues needs beside Contents; a GitHub refusal for a missing Issues or Projects right names that right and where to give it"
}
```

**Why this size.** XS: the words of one function and one hint in two files, with their unit tests; no contract.

**What must be true.** A person making the one token Porelo asks for gives it, at once, every right planning in
GitHub Issues needs, so the planner never refuses for a right the window did not name.

## The contract this builds against

- The person's one forge token carries git and planning. It needs, on the project's repositories, Issues (read and
  write), Contents (read and write) and Metadata (read), and on the organization Projects (read and write).

## Plan

- `lib/src/ui/forges_view.dart`, `tokenRightsWords`: names Issues (read and write) and Metadata (read) on the
  repositories and Projects (read and write) on the organization, beside Contents, saying they are for planning.
- `lib/src/app/forge.dart`, the 403 hint for a fine-grained token: names `Issues: Read and write` for an `/issues`
  path, and Projects under the organization's permissions for a GraphQL project refusal.
- `CHANGELOG.md`.
- Red first: unit tests that `tokenRightsWords` names Issues, Metadata and Projects, and that a 403 "not accessible by
  personal access token" on `/repos/o/r/issues` names Issues.

## Acceptance

- The *Connect* terminal's words and the forge list name the four rights; a refusal for a missing Issues right names
  it with where to give it.

## To be checked

- Whether a fine-grained token waiting for the organization's approval of Projects is said as waiting, as for
  Contents.
