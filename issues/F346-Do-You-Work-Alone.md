# F346 — Do You Work Alone

**Status:** Review.

**What must be true.** Creating a project asks "Do you work alone?". A yes writes `review: optional` for the project and its repositories, in the signed file, and it stays changeable.

## How it stands

Read from the code, not run. The window writes no `review` value, and *Add a project…* in `lib/src/ui/organization_page.dart` does not ask.

## What is needed

- From Core: how a project's creation takes the value, and how it is changed later.
- Here: the question in the dialog, and the way to change it on the project's page.

## To be checked

- The question stands at *Open the project*, where `project.yml` is made, not at *Add a project…*.
- Core's answer names no current value yet, so the project's ⋮ offers both and its page says it cannot say. It reads `review` the moment Core names it.
- Against real Core; fixtures stand for `--review` and `project review`.
