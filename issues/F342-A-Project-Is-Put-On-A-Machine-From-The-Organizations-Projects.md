# F342 — A Project Is Put On A Machine From The Organization's Projects

**Status:** Idea.

**What must be true.** A machine's admin who wants a project on it finds that where they think of it, and does not meet the same action in two
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

## The decision

From the organization's projects, a person puts a project on a machine that exists. Only that machine's Machine Admin may do so: its carried projects are that role's, in the table of [F335](README.md#f335). An Organization Admin does so by first naming themselves its Machine Admin, a signed change like any other.

So *Organization*'s row of a project offers *Put it on a machine…*, for a Machine Admin, choosing among those they administer, read from the organization, connected or not. No right changes and the calls stay. The admin of a machine reaches a project they are no member of there, as `porelo project show` keeps them from it under *Projects*. A project admin who is no machine's admin is offered nothing, and reads `not on a machine yet · a machine's admin puts it on one`.

*Take it off the machine…* stands in the same row for the same Machine Admin, and asks first.

The machine's page keeps a list of its projects with their progress, read only. It answers *Is this machine carrying it?* and is no second way to change it.

## What it costs

- The token's block, *Give it my `<forge>` token…*, has to be offered where the action now is, or the row sends the person on to the machine's
  page, which needs words and that admin's connection. [F341](README.md#f341) says what it says.
- The walks and tests that go through the host's page change.

## What it changes here

*Organization*'s project rows and the machine's page, which it moves between. It bears on [F335](README.md#f335), [F336](README.md#f336), whose page gets shorter,
[F338](README.md#f338), whose line above it takes, and [F343](README.md#f343), whose list becomes read only.
