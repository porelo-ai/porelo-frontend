# F346 — Do You Work Alone

**Status:** Backlog.

**What must be true.** Creating a project asks "Do you work alone?". A yes writes `review: optional` for the project and its repositories, in the signed file, and it stays changeable.

## How it stands

Read from the code, not run. The window writes no `review` value, and *Add a project…* in `lib/src/ui/organization_page.dart` does not ask.

## What is needed

- From Core: how a project's creation takes the value, and how it is changed later.
- Here: the question in the dialog, and the way to change it on the project's page.
