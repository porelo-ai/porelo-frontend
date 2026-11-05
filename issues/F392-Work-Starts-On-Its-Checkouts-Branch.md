# F392 — Work Starts On Its Checkout's Branch

**Status:** Idea.

**What must be true.** Work a person starts from a checkout on this computer starts from the branch that checkout is on, and its page says which branch it started from and why that one: the checkout's, one the person named, the project's base branch, or the repository's default.

## Why

The machine cannot see a checkout on this computer, so it cannot know the branch the person is working on; without being told, it starts from the project's base branch or the repository's default, which may not be what the person has in front of them. The daemon now takes the branch on `Start` as `from`, and says for each task which branch it started from (`baseBranch`) and where that came from (`baseSource`: `CHECKOUT`, `FROM`, `PROJECT` or `DEFAULT`). An older daemon says neither, which is shown as not said.

## Open questions

- Whether the person can name another branch than the checkout's when starting, or only sees which one is used.
