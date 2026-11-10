# F382 — An Image's Settings In Work

```json
{
  "$schema": "issue-1.json",
  "id": "F382",
  "title": "An Image's Settings In Work",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 69,
  "blockedBy": [],
  "covers": "A button in *Work* shows which settings the task's image was built with, and where each comes from."
}
```

**Why this size.** a step and a dialog, once the daemon says what it was built with.

**What must be true.** In *Work*, a button shows which settings the task's image was built with: base image, packages and tools, the agent and its version, security class, and where each comes from: `project.yml`, or Porelo's settings for *Default*.

## Plan

- A step in the opened row, beside *Open its terminal*, and on *Running* in the bar beside the way of working; both open one dialog.
- Agree the daemon's answer in the room first. It gives only the security class, the agent, the commit and whether the image drifted today.

## Acceptance

- The dialog names each setting and where it comes from, on a task of a project and on one in *Default*.

## Decided while building

- The daemon's answer is `ImageSettings(task)`; an image that does not say is shown as not saying, never as empty, and an older Porelo is said.
- A whole path to a project's file on a real machine is shown as the file and where in it: the folder only repeated itself on each line. A source this window does not know is shown as it comes.

## Open questions

## To be checked

- Seen once in the real window on a real daemon's task of a project, from the row and from *Running*. A task in *Default* is held by a unit test alone.
