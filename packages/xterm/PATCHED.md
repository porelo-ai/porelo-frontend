# xterm 4.0.0, patched

This is `xterm` 4.0.0 from pub.dev with two changes, in `lib/src/ui/custom_text_edit.dart` and
`lib/src/core/mouse/button.dart`. Nothing else differs.

It is based on the package whose archive has the SHA-256
`168dfedca77cba33fdb6f52e2cd001e9fde216e398e89335c19b524bb22da3a2`, from https://github.com/TerminalStudio/xterm.dart.
Its `lib`, `LICENSE` and `pubspec.yaml` are kept as published, under that MIT license; `example`, `test` and the like
are left out.

**Why.** The package answered each typed character by resetting the engine's text, which is asynchronous. A key pressed
before the reset arrived was added to the old text, and the whole of it was sent again: typing fast into a terminal gave
`RReRep...`. Key events alone would avoid it, but lose dead keys, such as the backtick on a German keyboard.

**The change.** The engine's text is kept, and only what was added since the last answer is sent. It is reset only when
it has grown long and typing has paused, or when the connection opens.

Drop this copy, and the override in the root `pubspec.yaml`, when a released `xterm` fixes it.

**The wheel.** The package reported the mouse wheel to a program that asked for the mouse as button 68 and 69, which is
the wheel with Shift held: the wheel's bit (64) plus the Shift bit (4). tmux binds no Shift+wheel, so the wheel did
nothing in a task's terminal. The wheel is reported as xterm does, 64 to 67, so tmux scrolls.
