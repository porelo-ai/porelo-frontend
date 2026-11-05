import 'package:flutter/material.dart';

import '../app/settings.dart';
import 'tokens.dart';

/// Says that a page's explanation has its `i` on the list titled [title], which draws it beside its title.
class PageExplanationScope extends InheritedWidget {
  /// Constructor taking the list's title, the page's name and where it is kept.
  const PageExplanationScope({
    required this.title,
    required this.id,
    required this.settings,
    required super.child,
    super.key,
  });

  /// The title of the list that draws the `i`.
  final String title;

  /// The name of the page's explanation.
  final String id;

  /// Where what was seen is kept.
  final Settings settings;

  /// The one above [context], if any.
  static PageExplanationScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageExplanationScope>();

  @override
  bool updateShouldNotify(PageExplanationScope oldWidget) => title != oldWidget.title || id != oldWidget.id;
}

/// The `i` beside a page's title, which opens its explanation.
class PageExplanationButton extends StatelessWidget {
  /// Constructor taking which page's.
  const PageExplanationButton({required this.id, required this.settings, super.key});

  /// The name of the page's explanation.
  final String id;

  /// Where it is told to open.
  final Settings settings;

  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey<String>('explanation-open $id'),
    tooltip: 'What this page is',
    visualDensity: VisualDensity.compact,
    onPressed: () => settings.setExplanationOpen(id, open: !settings.explanationOpen(id)),
    icon: const Icon(Icons.info_outline, size: Sizes.rowIcon),
  );
}

/// What a page is for. It stands open once, the first time the page is opened, which is kept across a
/// restart; after that only its [PageExplanationButton] opens it, until it is closed or the page is left.
class PageExplanation extends StatefulWidget {
  /// Constructor taking which page's, its parts, and where what was seen is kept.
  const PageExplanation({required this.id, required this.settings, required this.parts, super.key});

  /// The name it is kept under.
  final String id;

  /// Where what was seen is kept.
  final Settings settings;

  /// The parts, each a question or a heading and its words.
  final List<({String title, String words})> parts;

  @override
  State<PageExplanation> createState() => _PageExplanationState();
}

class _PageExplanationState extends State<PageExplanation> {
  @override
  void initState() {
    super.initState();
    widget.settings.showExplanationTheFirstTime(widget.id);
  }

  @override
  void dispose() {
    widget.settings.forgetExplanationOpen(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) {
      if (!widget.settings.explanationOpen(widget.id)) return const SizedBox.shrink();
      final text = Theme.of(context).textTheme;
      Widget said(({String title, String words}) part) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(part.title, style: text.titleSmall),
          Text(part.words),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(left: Space.normal, top: Space.small, right: Space.normal),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.normal),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: Space.normal,
                    runSpacing: Space.small,
                    children: <Widget>[
                      for (final part in widget.parts)
                        if (widget.parts.length == 1)
                          said(part)
                        else
                          SizedBox(width: Sizes.dialogSmall, child: said(part)),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('explanation-fold ${widget.id}'),
                  tooltip: 'Close this explanation',
                  onPressed: () => widget.settings.setExplanationOpen(widget.id, open: false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// A page's title with its `i`, where no list of the page carries the title.
class PageHead extends StatelessWidget {
  /// Constructor taking the title and which page's explanation.
  const PageHead({required this.title, required this.id, required this.settings, super.key});

  /// The page's title.
  final String title;

  /// The name of the page's explanation.
  final String id;

  /// Where it is told to open.
  final Settings settings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: Space.normal, top: Space.small, right: Space.normal),
    child: Row(
      children: <Widget>[
        Flexible(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
        ),
        PageExplanationButton(id: id, settings: settings),
      ],
    ),
  );
}
