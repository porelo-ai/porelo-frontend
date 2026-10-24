# A guided walk through the interface

When the operator walks the interface as someone new to Porelo, the agent leading the walk can sit
beside it. A panel says each step, beside the window or in a window of its own. A ball and a frame
mark what to click, and he writes what he finds without leaving the interface. Each comment is
written down with the window's state as text and an image of the interface's own window, never of
the whole screen, secrets blanked: obscured fields, and the terminals where a passphrase or a
sign-in code appears. All of it is written to a folder on this computer, and nothing leaves it.

The walk is the plugin `guided_walk`, from the repository
[`fuinorg/flutter-guided-walk`](https://github.com/fuinorg/flutter-guided-walk). Its README
says how a walk file is written, which files the walk's folder holds, and how a step moves on.

**Development builds only.** A release build shows and sends nothing of it. A development build shows
it only when started with a folder:

```bash
PORELO_WALK=$HOME/.porelo/walk flutter run -d linux
```

What Porelo adds to the plugin:
- the variable `PORELO_WALK` names the folder;
- the panel's own window has Porelo's theme;
- the note about terminals is in German;
- a step waiting for `filled:<key>` sees Porelo's own choice fields;
- the terminals are wrapped in `WalkSecret`;
- a symbol beside the information button shows the walk again once it was put away.

**The walks of the MVP's paths** are in [`doc/walks/`](https://github.com/porelo-ai/porelo-frontend/tree/main/doc/walks). A test checks that every key they
name is in the interface. One is started by copying it over the walk file:

```bash
cp doc/walks/3-first-task-in-default.json ~/.porelo/walk/walk.json
```

A walk that has been walked is deleted; what it found is in the issues. A walk names no machine,
account or address: it says "the test machine" and `<Konto>`, which the agent walking it reads from
`.AGENTS.md`. Every walk in `doc/walks/` is checked against the interface's keys.

**The agent reaches the walk in one of two ways**, both described in the plugin's README:
- **through the files**, where MCP may not be used: it waits for a comment with
  `.channel/watch-walk.sh`, which prints the new lines and ends, and is re-armed after each comment,
  as with the channel;
- **through MCP**: the plugin's server, started by the agent, offers the same walk as tools. Added
  once in Claude Code, in this repository's folder, it starts in the version `pubspec.yaml` pins:

  ```bash
  claude mcp add guided-walk -- dart run guided_walk:guided_walk_mcp $HOME/.porelo/walk
  ```

  After starting Claude Code again, `/mcp` shows `guided-walk` as connected. The plugin's README
  says which scope fits whom, and how to ask for a walk.

## The host flow on this computer

The host walk uses two mock daemons and compiled stand-ins; it rents nothing. The override is
read only in development builds. Run these commands from the repository root, keeping the walk
folder short so Unix socket paths stay under 100 bytes:

```bash
walk=/tmp/porelo-walk
mkdir -p "$walk/bin"
dart compile exe tool/host_standin.dart -o "$walk/porelo-host"
dart compile exe tool/ssh_standin.dart -o "$walk/bin/ssh"
printf '%s\n' '{"situation":"stop","state":"new"}' > "$walk/host-standin.json"
cp doc/walks/17-the-host-flow.json "$walk/walk.json"
```

In two separate terminals, start the first machine and the fresh host. The host situation has only
`checkout` and nothing run yet. These deadlines also stop a daemon left at the end of a walk:

```bash
timeout 1h dart tool/mock_daemon.dart work /tmp/porelo-walk/first.sock
timeout 1h dart tool/mock_daemon.dart host /tmp/porelo-walk/host.sock
```

Then start the interface from a third terminal with its settings isolated from everyday machines.
The host dialog still uses the system secret store for its generated WireGuard key. Use invented
answers at the stop; no real host keys, provider credentials or collection are needed. Leave the
local Tresorit folder unchosen, so the dialog prepares no host files.

```bash
PATH="$walk/bin:$PATH" \
PORELO_HOST_STANDIN="$walk/porelo-host" \
PORELO_WALK_HOST_SOCKET="$walk/host.sock" \
PORELO_WALK="$walk" \
PORELO_SOCKET="$walk/first.sock" \
XDG_CONFIG_HOME="$walk/config" \
XDG_RUNTIME_DIR="$walk" \
flutter run -d linux
```

`host-standin.json` is required and is read on every run. Its `situation` is `clean`, `stop`,
`refused`, `slow` or `down`; `state` is written by the stand-in. A `stop` resumes only with
`up --answers-on-stdin`, whose input is drained and discarded. `slow` takes 60 seconds by default;
`paceMilliseconds` overrides that delay for tests. The `down` situation accepts `down`, and the
dialog's down action also works after any other situation. Reset to `{"situation":"stop","state":"new"}`
to walk the stop again. The SSH stand-in supports only config lookup and the Unix socket forward;
it refuses terminal and remote-command forms.

**Working on the plugin beside this repository:** a `pubspec_overrides.yaml` here, which git ignores,
points the dependency at the local folder:

```yaml
dependency_overrides:
  guided_walk:
    path: ../flutter-guided-walk
```
