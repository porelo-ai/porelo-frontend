# F121 — The Interface In Porelo's Look

**Status:** Review.
**Size:** M - one colour scheme per brightness in place of a seed colour, the state colours by
brightness, the terminal's palette, the corners and buttons, the logo as the application's icon, and
a test that holds every pair to its contrast.

**What must be true.** The interface looks like Porelo's website: the same near-black ground, the
same cyan, magenta, lime and amber, the same rounded surfaces with a fine border and the same logo,
so a person moving from the website to the interface sees one product. Unlike the website it keeps
a light mode beside the dark one, chosen as today (light, dark, or as the system says), and every
text and mark in either is readable at WCAG AA.

## Plan

- **The palette, `lib/src/ui/tokens.dart`:** the website's values as primitives - ground `#05050c`
  and `#0b0b1a`, text `#e8ecff`, muted `#9aa3c7`, cyan `#00f0ff`, magenta `#ff2bd6`, lime `#b6ff3b`,
  amber `#ffb020` - and the light mode's, derived from them: the same hues darkened until they read on
  a pale blue-grey ground (petrol for cyan, a deep magenta, an olive lime, a brown amber). The brand
  indigo goes.
- **The theme, `lib/src/ui/theme.dart`:** a full `ColorScheme` for each brightness in place of
  `ColorScheme.fromSeed` - cyan primary, magenta secondary, lime tertiary, a pink red for errors;
  surfaces from the ground up through four steps of the website's frosted glass, opaque, since a blur
  costs a desktop tool more than it gives; outlines from the glass border. Cards and dialogs with the
  website's larger corners and a hairline border, buttons as pills, a focused field's border cyan.
- **The state colours:** working, waiting and stopped become lime, amber and muted, each in a light
  and a dark tone, picked by the scheme's brightness (`StateColours.of`), since a lime that reads on
  black vanishes on white.
- **The terminal, `lib/src/ui/terminal_look.dart`:** one `TerminalTheme` in the website's colours,
  dark in both modes as today, given to every `TerminalView` (session, unlock, new machine,
  diagnosis) and read by the tile's console and the log; the four hard-coded greys and blacks go.
- **The icon:** the website's `logo.svg` as `packaging/porelo-frontend.svg` and, rendered, as the
  Windows `app_icon.ico`; the MSIX's tiles follow from the same file.
- **The README's picture:** the old demo, which still showed the old name, gives way to a
  screenshot of the interface in its new look, `images/porelo-frontend.png`.
- **What is not carried over:** the website's moving background (grid, colour clouds, scan lines),
  its glitch and typing effects and its thumb bar, which suit a page read once, not a tool open all
  day.
- **The test that goes red first:** `test/ui/theme_contrast_test.dart` computes the WCAG contrast of
  every text colour against every surface it is drawn on, in both modes - at least 4.5:1 for text,
  3:1 for marks and outlines - and fails on today's seed scheme for the state colours, whose amber on
  white is below 3:1.

## Acceptance

- **The contrast test** red before, green after, in both modes.
- **`dart analyze` clean and the whole suite green**, the widget tests unchanged in what they assert.
- **Seen by eye** in the release bundle, light and dark: the machines and their tiles, a task's
  detail, a session's terminal, the start dialog, the settings.
