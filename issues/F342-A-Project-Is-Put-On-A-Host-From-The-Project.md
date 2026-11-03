# F342 — A Project Is Put On A Host From The Project

**Status:** Idea.

**What must be true.** A person who wants a project on a host finds that where they think of it, and does not meet the same action in two
places that disagree.

In a walk the operator said: "*Put a project on the host* belongs under *Projects*: there I should choose a project and put it on a host. I
am not sure *Projects on this host* belongs on the machine's page at all. Perhaps as an additional function, but having it in two places
could confuse. I suspect that putting a project on a host and taking it off is a function of the project."

## How it stands

Read from the code, not run. *Put a project on the host* and *Take off the host* are on the host's page alone, for a host admin, as was
decided: a host admin decides which projects a host carries, never which persons. A project admin may be no host admin, and the
reverse: *Projects* lists only a person's own projects, and `porelo project show` refuses someone who is no member, so a host admin
who is in no project cannot open that project's page at all. After it is put on, the token and the host's progress are on the host's
page, over the host admin's own connection to the host.

## The options

1. **As it stands.** The host's page alone. Nothing to build; it is what the operator doubts.
2. **On the project, for the host admin, same right.** The project's row and page offer *Put it on a host…*, choosing among the hosts this
   person administers, and *Take it off the host…*. The host's page keeps a list of its projects with their progress, read-only. No right
   changes and the calls stay. A host admin outside the project reaches it from *Organization*'s row, as they cannot from *Projects*.
3. **On the project, for the project admin.** The project admin decides. That reverses who decides what a host carries: a project admin could
   load someone else's server, the host's signed state changes its rule, and the token is then whose?
4. **The project admin asks, the host admin agrees.** Both are heard, and it needs a new state, a question on the host's side, and a change in
   Core. The largest.
5. **Both pages offer it.** What the operator warned against.

**Recommended: option 2.** It puts the action where the operator looks for it and changes no one's right, and a host admin still decides. The
list on the host's page stays read-only, as it says what the host carries and how far each has come. It answers *Is this host carrying
it?* and is no second way to change it.

## What it costs

- The token's block, *Give it my `<forge>` token…*, has to be offered where the action now is, or the page sends the person on to the host's
  page, which needs words. [F341](README.md#f341) says what it says.
- A project admin who is no host admin sees why nothing is offered: `not on a host yet · <admins of a host> put it on one`, as in
  [F338](README.md#f338).
- The walks and tests that go through the host's page change.

## What it changes here

The project's and the host's pages, which it moves between. It bears on [F335](README.md#f335) and
[F336](README.md#f336), whose host's page gets shorter.

## Open questions

- Which of the options? Recommended: 2.
- Does taking a project off still ask first, now that it stands among a project's own actions? Recommended: yes, as today.
