import 'package:flutter/material.dart';

import '../app/settings.dart';
import 'tokens.dart';
import 'window_size.dart';

/// Says that a page's explanation has its `i` on the list titled [title], which draws it beside its title.
class PageExplanationScope extends InheritedWidget {
  /// Constructor taking the list's title, the page's name and where it is kept.
  const PageExplanationScope({
    required this.title,
    required this.id,
    required this.settings,
    required super.child,
    this.parts = const [],
    super.key,
  });

  /// Words drawn under the leaf head.
  final List<({String title, String words})> parts;

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
    icon: const Icon(Icons.info_outline, size: Sizes.pageInfo),
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
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: Sizes.dialogSmall),
                            child: said(part),
                          ),
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

/// One ancestor in a leaf's path; the current page is added by the head.
typedef LeafPathStep = ({String label, VoidCallback? go});

/// A leaf's wrapping path, title, total, tools and main action.
class PageHead extends StatelessWidget {
  /// Presents the page's identity before its list.
  const PageHead({
    required this.title,
    this.id,
    this.settings,
    this.path = const [],
    this.subtitle,
    this.subtitleKey,
    this.status,
    this.titleKey,
    this.controls,
    this.action,
    this.pathKeys = const {},
    super.key,
  });

  /// The full page name.
  final String title;

  /// The explanation identity, when the page has one.
  final String? id;

  /// Where the explanation's fold is kept.
  final Settings? settings;

  /// Ancestors linking back to their pages.
  final List<LeafPathStep> path;

  /// Stable targets for existing ancestor navigation.
  final Map<String, Key> pathKeys;

  /// Counts the whole list, independent of its filter.
  final String? subtitle;

  /// The total's automation target.
  final Key? subtitleKey;

  /// The person's role or access state, independent of the list total.
  final Widget? status;

  /// The title's automation target.
  final Key? titleKey;

  /// The filter and sort menu.
  final Widget? controls;

  /// The page's main action and any retained secondary actions.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final phone = WindowSize.fromContext(context) == WindowSize.compact;
    final text = Theme.of(context).textTheme;
    final info = id != null && settings != null ? PageExplanationButton(id: id!, settings: settings!) : null;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!phone)
          Row(
            children: [
              Flexible(
                child: Text(title, key: titleKey ?? const Key('leaf-title'), style: text.headlineSmall),
              ),
              ?info,
            ],
          ),
        if (subtitle != null || phone && info != null)
          Row(
            children: [
              Expanded(
                child: Text(subtitle ?? '', key: subtitleKey, style: text.bodySmall),
              ),
              if (phone) ?info,
            ],
          ),
        ?status,
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (path.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.small),
              child: Wrap(
                key: const Key('leaf-path'),
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.tight,
                children: [
                  for (final step in path) ...[
                    if (step.go != null)
                      TextButton(key: pathKeys[step.label], onPressed: step.go, child: Text(step.label))
                    else
                      Text(step.label),
                    const Text('›'),
                  ],
                  Text(title),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              if (phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    if (action != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.small),
                        child: action,
                      ),
                    if (controls != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.small),
                        child: controls,
                      ),
                  ],
                );
              }
              final inline = WindowSize.leafHeadFits(constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: heading),
                      if (inline && controls != null) SizedBox(width: Sizes.leafTools, child: controls),
                      if (action != null) ...[const SizedBox(width: Space.small), Flexible(child: action!)],
                    ],
                  ),
                  if (!inline && controls != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.small),
                      child: controls,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
