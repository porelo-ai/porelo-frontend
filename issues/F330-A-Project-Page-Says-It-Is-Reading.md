# F330 — A Project Page Says It Is Reading

**Status:** Idea.

**What must be true.** A project's page shows at once that it is reading, and what, so a person never takes the wait for
nothing happening.

In a walk a developer clicked a project under *Projects* at real GitHub, and the page opened blank and stayed so for a long
while; the operator first took it that nothing was happening. How long was not measured.

## Where the wait comes from

Read from the code, not measured. Until the first answer, `OrganizationProjectPage` shows only the way back and the
project's name, with no mark of a read under way; `OrganizationChangeMark` shows changes, not reads. The answer comes
from one `porelo project show`, a new process that:

- reads the organization from its repository, with the forge saying who holds which key;
- then fetches the project's own repository and checks its `project.yml` against the admins' keys.

So every opening goes to the forge at least twice, and the page waits for all of it. A forge that does not answer can
hold the page until the interface's limit of five minutes for a command.

## To be checked

- How long each part takes at real GitHub, which says whether words are enough or the read itself should be shorter.
- Whether the page can show what the organization's last read already holds (members, host, address) and read the
  repositories after it.
- Whether the same blank stands on a host's page and on the list of projects.
