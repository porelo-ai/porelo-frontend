# F616 — A Forge Token Asked For With The Rights Planning Needs

```json
{
  "$schema": "issue-1.json",
  "id": "F616",
  "title": "A Forge Token Asked For With The Rights Planning Needs",
  "state": "Review",
  "size": "XS",
  "priority": "High",
  "rank": 2,
  "blockedBy": [],
  "covers": "Where the window asks for the person's forge token, it names the rights planning in GitHub Issues needs beside Contents, so the one token is made with all of them"
}
```

**Why this size.** XS: the words of one function in one file; no contract, and no test, as only a wording changes.

**What must be true.** A person making the one token Porelo asks for gives it, at once, every right planning in
GitHub Issues needs, so the planner never refuses for a right the window did not name.

## The contract this builds against

- The person's one forge token carries git and planning. It needs, on the project's repositories, Issues (read and
  write), Contents (read and write) and Metadata (read), and on the organization Projects (read and write).

## Plan

- `lib/src/ui/forges_view.dart`, `tokenRightsWords`: names Issues (read and write) and Metadata (read) on the
  repositories and Projects (read and write) on the organization, beside Contents, saying they are for planning.
- `CHANGELOG.md`.
- No hint in `lib/src/app/forge.dart`: the window itself calls no issue or project API of GitHub, so a refusal for a
  missing Issues or Projects right reaches the person as the planner's own words.
- No test: only a wording changes, and a test holding it verbatim guards no harm.

## Acceptance

- The words under a forge using a token in *My forges* name Contents for git and Issues, Metadata and organization
  Projects for planning.
