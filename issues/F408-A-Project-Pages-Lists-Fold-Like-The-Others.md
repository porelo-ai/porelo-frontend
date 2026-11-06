# F408 — A Project Page's Lists Fold Like The Others

**Status:** Accepted.
**Size:** XS - *Repositories* and *Members* on an organization's project page made collapsible, as the window's other
list sections are, their state kept by their storage id.

**What must be true.** On an organization's project page, *Repositories* and *Members* fold and unfold like the
window's other list sections, and stay as the person left them.

## Why

The operator's walk on the rehearsal VM (2026-11-06): porelo's 17 repositories fill the project page and the section
cannot be folded, unlike the other sections.

## Plan

- `lib/src/ui/organization_project_pages.dart`: `_repositories` and `_members` pass `collapsible: true` to
  `FilteredListSection`, which keeps the state under their `storageId` already.
- No test goes red first: the folding is the shared section's, tested there; nothing is lost while folded.
