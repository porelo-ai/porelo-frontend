# F336 — A Host's Page Reads As A Way To Work

**Status:** Review.

**What must be true.** A person on a host's page sees at once whether this computer is connected, what that means and what
ending it does, and is led from there to working on the host.

**The operator:** built with [F335](README.md#f335).

In a walk the operator, told to click *Disconnect*, could not find it and could not tell what it belonged to: "The whole process
is hard to follow for a user."

## How it reads now

Read from the code, not run.

- **The blocks, top to bottom:** the way back, the name, a line with organization, address and host key and the admin's two
  buttons; how the host stands, for an admin; *Projects on this host*; *Host admins*; and last, under *Your connection*, one
  sentence and the button. What concerns everyone stands below what concerns only an admin.
- **Nothing says what the connection is,** or what ending it does. *Disconnect* asks nothing. It makes this computer forget the
  machine and takes down its ssh connection; the person's account, work and vault on the host stay, and *Connect* brings it back.
- **The words can disagree with the button.** While the host waits for a token the section says `Not connected yet`, and the
  button beside it says *Disconnect*, because the connection stands and only the account is missing.
- **The page leads to no work.** *Open it on <host>* under *Projects* opens this page where a project has not started on the
  host yet, as the way on, and nothing on this page starts work: its project rows offer an admin *Take off the host* and no one
  anything else. The way on is *New work* under *Work*, which nothing here says.

## The recommendation

**At the top, under the name, for everyone,** one block with the state, its meaning and its action:

| State | It says | Action |
|---|---|---|
| Not connected | This computer has no connection to `<host>` yet. You need one to work there; it is set up once, whatever number of projects the host carries. | *Connect* |
| Connected, no account yet | Connected. `<host>` makes your account once it has read the organization, up to five minutes after your project is on it, and only once its admin has given it the token. | *Disconnect* |
| Connected, ready | Connected as `<login>`. Ready to work on: `<projects>`. | *Start work*, *Disconnect* |

**Under *Disconnect*,** in small words: *Ends this computer's connection only. Your account, work and vault on the host stay, and
Connect brings it back.* It needs no question then, being that easy to undo. The button's label can stay.

**Below it, under a heading of their own such as *Managing this host*,** what only an admin does: address and key, the token,
projects and admins. A person who is no admin reads what they read today, in the same order, without the buttons.

**Each project's row** offers *Start work* where this person can, which is the step this page lacks now.

## The whole path, as a person reads it

1. *A host of mine:* its row says `Not connected`, with *Connect*.
2. *Connecting:* the row and the page say so at once, as [F331](README.md#f331) asks.
3. *Waiting:* the page says for what, and for whom: the admin's token, or up to five minutes for the account; the row does not flip,
   as [F334](README.md#f334) asks.
4. *Ready:* the row says `Connected · ready to work on <projects>`, and the page and each project's row offer *Start work*.
5. *Working:* *New work* opens with that host and project filled in, and the work stands under *Work*.

Where this page stands, and what the row is called, follows [F335](README.md#f335).

## To be checked

- That *Open it on <host>* really ends on this page with nothing to do, by walking it.
- That *New work* can be opened with a host and project already chosen, for a project the host does not list yet. A host lists
  a project only after the person's first start there.
- Whether the account's five minutes and the token's wait can be told apart from what the host answers today.
