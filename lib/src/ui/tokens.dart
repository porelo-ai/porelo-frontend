/// The numbers this interface is allowed to use.
///
/// Nothing outside this file may spell out a spacing, a width or a radius. A widget that writes
/// `EdgeInsets.all(16)` has made a decision this file was supposed to hold, and the next widget
/// makes a slightly different one — which is how an interface stops looking like one thing.
library;

import 'package:flutter/material.dart' show Brightness, Color, ColorScheme;

/// Raw values, named for what they are rather than what they are for. Only the tokens below and
/// the theme read these; a widget reads the tokens.
abstract final class Primitives {
  /// The website's ground, near black.
  static const Color ground = Color(0xFF05050C);

  /// The website's second ground, a shade lighter.
  static const Color ground2 = Color(0xFF0B0B1A);

  /// The website's text.
  static const Color text = Color(0xFFE8ECFF);

  /// The website's muted text.
  static const Color muted = Color(0xFF9AA3C7);

  /// The website's cyan: links, focus, the first accent.
  static const Color cyan = Color(0xFF00F0FF);

  /// The website's magenta: the second accent.
  static const Color magenta = Color(0xFFFF2BD6);

  /// The website's lime: code, and what works.
  static const Color lime = Color(0xFFB6FF3B);

  /// The website's amber: what waits.
  static const Color amber = Color(0xFFFFB020);

  /// The website's red for what failed.
  static const Color red = Color(0xFFFF5F7A);

  /// Cyan darkened until it reads on a light ground: petrol.
  static const Color petrol = Color(0xFF006872);

  /// Magenta darkened until it reads on a light ground.
  static const Color deepMagenta = Color(0xFFA3127F);

  /// Lime darkened until it reads on a light ground: olive.
  static const Color olive = Color(0xFF3B6600);

  /// Amber darkened until it reads on a light ground: brown.
  static const Color brown = Color(0xFF8A5300);

  /// Red darkened until it reads on a light ground.
  static const Color deepRed = Color(0xFFB3123A);

  /// The light mode's ground, a pale blue-grey.
  static const Color paleGround = Color(0xFFF6F7FC);

  /// The light mode's muted text.
  static const Color slate = Color(0xFF464E70);

  /// What a stopped piece of work is drawn in, and an outline, in either mode.
  static const Color steel = Color(0xFF6B7396);

  /// A deep cyan, behind cyan text in the dark mode.
  static const Color cyanContainer = Color(0xFF00474E);

  /// A pale cyan, the text on [cyanContainer].
  static const Color onCyanContainer = Color(0xFFA6F9FF);

  /// A deep magenta, behind magenta text in the dark mode.
  static const Color magentaContainer = Color(0xFF5A1149);

  /// A pale magenta, the text on [magentaContainer].
  static const Color onMagentaContainer = Color(0xFFFFD0F4);

  /// A deep lime, behind lime text in the dark mode.
  static const Color limeContainer = Color(0xFF2C4410);

  /// A pale lime, the text on [limeContainer].
  static const Color onLimeContainer = Color(0xFFDDFFAD);

  /// A deep red, behind what failed in the dark mode.
  static const Color redContainer = Color(0xFF561020);

  /// A pale red, the text on [redContainer].
  static const Color onRedContainer = Color(0xFFFFD0D8);

  /// Below the ground: the lowest surface in the dark mode.
  static const Color groundLowest = Color(0xFF030308);

  /// The website's frosted glass laid opaque over the ground: the first step.
  static const Color glass1 = Color(0xFF0F1122);

  /// The frosted glass, the second step.
  static const Color glass2 = Color(0xFF15172C);

  /// The frosted glass, the third and highest step; the light mode's inverse surface.
  static const Color glass3 = Color(0xFF1C1F38);

  /// The dark mode's outline, and the terminal's bright black.
  static const Color dusk = Color(0xFF6E77A0);

  /// The glass's fine border, in the dark mode.
  static const Color glassBorder = Color(0xFF2A2F50);

  /// A pale petrol, behind petrol text in the light mode.
  static const Color petrolContainer = Color(0xFFC2F6FA);

  /// A near-black petrol, the text on [petrolContainer].
  static const Color onPetrolContainer = Color(0xFF00262A);

  /// A pale magenta, behind deep magenta text in the light mode.
  static const Color deepMagentaContainer = Color(0xFFFFD5F3);

  /// A near-black magenta, the text on [deepMagentaContainer].
  static const Color onDeepMagentaContainer = Color(0xFF3A002D);

  /// A pale olive, behind olive text in the light mode.
  static const Color oliveContainer = Color(0xFFD6F5A4);

  /// A near-black olive, the text on [oliveContainer].
  static const Color onOliveContainer = Color(0xFF112000);

  /// A pale red, behind what failed in the light mode.
  static const Color deepRedContainer = Color(0xFFFFD9DF);

  /// A near-black red, the text on [deepRedContainer].
  static const Color onDeepRedContainer = Color(0xFF3F0011);

  /// The light mode's surfaces over its ground: the first step.
  static const Color pale1 = Color(0xFFF0F2FA);

  /// The light mode's surfaces, the second step.
  static const Color pale2 = Color(0xFFEAEDF7);

  /// The light mode's surfaces, the third step.
  static const Color pale3 = Color(0xFFE3E7F3);

  /// The light mode's surfaces, the fourth and highest step.
  static const Color pale4 = Color(0xFFDCE1F0);

  /// The light mode's fine border.
  static const Color paleBorder = Color(0xFFC9CFE3);

  /// Cyan at a third, what the terminal draws behind a selection.
  static const Color cyanSelection = Color(0x5500F0FF);

  /// The terminal's blue, which the website has none of.
  static const Color terminalBlue = Color(0xFF6E8BFF);

  /// The terminal's white, a shade below the text.
  static const Color terminalWhite = Color(0xFFC9D0F0);

  /// The terminal's bright red.
  static const Color brightRed = Color(0xFFFF8FA2);

  /// The terminal's bright green, a paler lime.
  static const Color brightLime = Color(0xFFD4FF8A);

  /// The terminal's bright yellow, a paler amber.
  static const Color brightAmber = Color(0xFFFFCB6B);

  /// The terminal's bright blue.
  static const Color brightBlue = Color(0xFF9DB0FF);

  /// The terminal's bright magenta.
  static const Color brightMagenta = Color(0xFFFF7AE5);

  /// The terminal's bright cyan.
  static const Color brightCyan = Color(0xFF7CF9FF);

  /// One logical pixel, the thinnest line a screen draws.
  static const double hairline = 1;

  /// The border of what has the focus, as the website draws it.
  static const double focusLine = 2;

  /// Four logical pixels.
  static const double space1 = 4;

  /// Eight logical pixels.
  static const double space2 = 8;

  /// Twelve logical pixels.
  static const double space3 = 12;

  /// Sixteen logical pixels.
  static const double space4 = 16;

  /// Twenty-four logical pixels.
  static const double space6 = 24;

  /// A small corner, as the website's badges have.
  static const double radiusSm = 8;

  /// A card's corner, the website's small radius.
  static const double radiusMd = 12;

  /// A dialog's corner, the website's large radius.
  static const double radiusLg = 18;
}

/// The colours of a piece of work's state, each paired with a shape so it reads without colour too
/// (walk 8: running, waiting, needing a person and stopped told apart at a glance).
///
/// Each comes in a dark and a light tone, since the lime and amber that glow on black vanish on white.
abstract final class StateColours {
  /// Working, waiting or quiet, and stopped, for the brightness of [scheme].
  static ({Color working, Color waiting, Color stopped}) of(ColorScheme scheme) => scheme.brightness == Brightness.dark
      ? (working: Primitives.lime, waiting: Primitives.amber, stopped: Primitives.muted)
      : (working: Primitives.olive, waiting: Primitives.brown, stopped: Primitives.steel);
}

/// Space between things, in logical pixels.
abstract final class Space {
  /// Above and below each line of a block that reads as one, such as a diff.
  static const hairline = Primitives.hairline;

  /// Hairline separation, inside a row.
  static const tight = Primitives.space1;

  /// Between a mark and the words beside it.
  static const small = Primitives.space2;

  /// Between rows, and inside a dense control.
  static const normal = Primitives.space3;

  /// Inside a pane, around its content.
  static const wide = Primitives.space4;

  /// Around something that stands on its own.
  static const loose = Primitives.space6;
}

/// Fixed sizes that carry a decision rather than a measurement.
abstract final class Sizes {
  /// The filter in each independent list header.
  static const listFilter = 240.0;

  /// The scrollable verified-person picker.
  static const personPicker = 320.0;

  /// The collapsed line shared by every expandable list entry.
  static const listRowHeight = 64.0;

  /// The main action leaves room for the name and disclosure on a phone.
  static const listActionCompact = 88.0;

  /// Long action names cannot crowd the item name on a desktop.
  static const listAction = 200.0;

  /// The projects column. Wide enough for a project name and its counts, no wider.
  static const projectsPane = 260.0;

  /// What is open, when there is room for it beside the work rather than over it.
  static const openedPane = 420.0;

  /// A mark saying whether something is running.
  static const mark = 16.0;

  /// The dot beside a task or a project.
  static const dot = 8.0;

  /// An icon inside a row.
  static const rowIcon = 18.0;

  /// A dialog that asks several things at once, wide enough for a URL or a key on one line.
  static const dialog = 620.0;

  /// A dialog that explains before it asks: a paragraph, a command line or a list, then the choice.
  static const dialogMedium = 560.0;

  /// Widening or narrowing what a running task can reach.
  static const reachDialog = 540.0;

  /// The emergency stop, before it acts and after.
  static const emergencyStopDialog = 520.0;

  /// A short question with one field or one short list under it.
  static const dialogSmall = 460.0;

  /// A dialog holding a single field or a single sentence of answer.
  static const dialogNarrow = 420.0;

  /// The command finder's width.
  static const finder = 560.0;

  /// The command finder's height at most, so its list scrolls rather than filling the window.
  static const finderHeight = 460.0;

  /// How far below the window's top edge the command finder opens.
  static const finderInset = 72.0;

  /// The tree of machines when it slides in over a narrow window.
  static const drawer = 300.0;

  /// The tree of machines beside the work, while the rail shows its labels.
  static const treeWithLabels = 280.0;

  /// The tree of machines beside the work, while the rail shows icons only.
  static const tree = 240.0;

  /// The name column of a list of names and values in small print.
  static const label = 110.0;

  /// The name column of a detail's fields.
  static const fieldName = 140.0;

  /// A tile in a wall of them: a task, a failed operation, the tile that starts work.
  static const tile = 320.0;

  /// How tall the tile that starts work is.
  static const startTileHeight = 120.0;

  /// The mark on the tile that starts work.
  static const startMark = 32.0;

  /// A saved job's tile.
  static const jobTile = 220.0;

  /// How tall a saved job's tile is.
  static const jobTileHeight = 48.0;

  /// A running operation's spinner, in place of its mark.
  static const operationSpinner = 14.0;

  /// The line a spinner is drawn with.
  static const spinnerStroke = 2.0;

  /// The status line's bar, saying something is under way.
  static const progressBar = 2.0;

  /// The border of the selected tile.
  static const selectedBorder = 2.0;

  /// The border around what the finder has taken you to.
  static const highlightBorder = 3.0;

  /// A divider takes no more room than its line.
  static const divider = Primitives.hairline;

  /// A terminal inside a dialog: enough rows for a prompt, an answer and what came of it.
  static const terminal = 240.0;

  /// What an agent writes, in the terminal's look: on a tile, and enlarged.
  static const terminalText = 12.0;

  /// The same, small, on a tile.
  static const terminalTextSmall = 11.0;

  /// The line height of terminal text, as a terminal spaces its rows.
  static const terminalLineHeight = 1.25;

  /// The terminal pane of the terminal diagnosis: a dozen rows to type into, the log below it.
  static const diagnosisTerminal = 220.0;

  /// A stable reading area keeps host setup actions still as its protocol grows.
  static const hostProtocolHeight = 400.0;

  /// A reader this close to the protocol's end follows incoming entries.
  static const hostProtocolEndThreshold = Space.small;
}

/// Corner radii.
abstract final class Radii {
  /// Inside a pane: a card, a summary, a block of output.
  static const small = Primitives.radiusSm;

  /// A card that stands on its own.
  static const medium = Primitives.radiusMd;
}

/// Dimensions and feedback shared by every action tile.
abstract final class ActionTiles {
  /// The width of each grid column.
  static const width = 280.0;

  /// The height of every action, including unavailable ones.
  static const height = 136.0;

  /// The prominent outlined mark above the title.
  static const icon = 40.0;

  /// The maximum title lines before truncation keeps every tile the same size.
  static const titleLines = 2;

  /// The shadow at rest.
  static const elevation = 8.0;

  /// The shadow under the pointer.
  static const hoverElevation = 14.0;

  /// The shadow while pressed.
  static const pressedElevation = 4.0;

  /// Unavailable actions lie flat.
  static const disabledElevation = 0.0;

  /// The maximum width of an explanation or refusal.
  static const tooltipWidth = 360.0;

  /// The bubble sits beyond the tile instead of over its title.
  static const tooltipOffset = height / 2 + Space.small;

  /// The delay before showing an explanation on hover.
  static const tooltipDelay = Duration(milliseconds: 500);

  /// Muted ink for unavailable actions.
  static const disabledInk = 0.60;

  /// The hover state layer.
  static const hoverInk = 0.08;

  /// The pressed state layer.
  static const pressedInk = 0.16;

  /// No state layer at rest.
  static const noInk = 0.0;
}
