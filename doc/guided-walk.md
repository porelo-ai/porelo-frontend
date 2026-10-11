# A guided walk through the interface

When the operator walks the interface as someone new to Sokar, the agent leading the walk can sit
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
SOKAR_WALK=$HOME/.sokar/walk flutter run -d linux
```

What Sokar adds to the plugin:
- the variable `SOKAR_WALK` names the folder;
- the panel's own window has Sokar's theme;
- the note about terminals is in German;
- a step waiting for `filled:<key>` sees Sokar's own choice fields;
- the terminals are wrapped in `WalkSecret`;
- a symbol beside the information button shows the walk again once it was put away.

**The walks of the MVP's paths** are in [`doc/walks/`](https://github.com/sokar-ai/sokar-frontend/tree/main/doc/walks). A test checks that every key they
name is in the interface. One is started by copying it over the walk file:

```bash
cp doc/walks/3-first-task-in-default.json ~/.sokar/walk/walk.json
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
  claude mcp add guided-walk -- dart run guided_walk:guided_walk_mcp $HOME/.sokar/walk
  ```

  After starting Claude Code again, `/mcp` shows `guided-walk` as connected. The plugin's README
  says which scope fits whom, and how to ask for a walk.

**Working on the plugin beside this repository:** a `pubspec_overrides.yaml` here, which git ignores,
points the dependency at the local folder:

```yaml
dependency_overrides:
  guided_walk:
    path: ../flutter-guided-walk
```
