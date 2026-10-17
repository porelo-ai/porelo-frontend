import 'package:flutter/widgets.dart';

/// The window size classes, and the only thing layout is allowed to branch on.
///
/// Material 3's own scale rather than numbers picked to make one screen fit: a breakpoint chosen
/// for a particular pane becomes wrong the moment a second pane exists, and there is no way to
/// tell which of a dozen scattered width comparisons meant the same thing.
///
/// Layout asks the named questions below, never the raw width.
enum WindowSize {
  /// Below 600: a window squeezed into a corner, or a phone.
  compact,

  /// 600 to 839: a narrow window, or a small tablet.
  medium,

  /// 840 to 1199: an ordinary desktop window.
  expanded,

  /// 1200 and above: a wide desktop window.
  large;

  /// Classifies a width in logical pixels.
  static WindowSize of(double width) {
    if (width < 600) return WindowSize.compact;
    if (width < 840) return WindowSize.medium;
    if (width < 1200) return WindowSize.expanded;
    return WindowSize.large;
  }

  /// Classifies the window [context] is being laid out in.
  static WindowSize fromContext(BuildContext context) => WindowSize.of(MediaQuery.sizeOf(context).width);

  /// Whether the projects and the work under them fit side by side.
  ///
  /// Below this the frame shows one at a time: a dense arrangement that merely shrinks becomes
  /// unreachable before it becomes unreadable.
  bool get showsTwoPanes => this == WindowSize.expanded || this == WindowSize.large;

  /// Whether there is room for what is open *beside* the work rather than over it.
  bool get showsOpenedBeside => this == WindowSize.large;

  /// Whether the rail says what its destinations are, rather than only drawing them.
  bool get railShowsLabels => this == WindowSize.large;

  /// Whether the status line has room for words beside its icons.
  ///
  /// Below this it keeps every affordance and drops the labels: an emergency stop that fell off
  /// the edge of a narrow window would be missing exactly when somebody reached for it.
  bool get statusLineShowsLabels => this != WindowSize.compact;

  /// Whether the machines stay beside what they show, or wait behind the menu button.
  bool get showsTreeBeside => this == WindowSize.expanded || this == WindowSize.large;
}
