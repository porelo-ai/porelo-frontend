# F386 — A Short Name People Read

**Status:** Idea.

**What must be true.** A person reads a short name, not a container's name.

- A task's name stays its identity. Its first short name is simply that name, from the repository, and nothing is stored at the start.
- The window shows only the short name in lists, the project's and the real name in the details, never the container's name. The menu item says *Rename*.
- A project gets an optional short name, `title: utils4j` in `project.yml`, so `utils4j-project` is not read in the window.
- The word is "short name", since `nickname` already means the name an agent goes by.
- This changes the contract's "beside the name, never instead", for the window's lists.

**The daemon's half.** `porelo task list` shows the short name beside the name, `porelo task rename` stands beside `label`, and commands keep taking the real name, as short names need not be unique. The file a first start writes would hold the project's `title`, once this Idea is set.

## Open questions

- Where a person reads the long name in the window: to be asked once tasks run again and the running changes are done.
