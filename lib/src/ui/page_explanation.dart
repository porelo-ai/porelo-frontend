import 'package:flutter/material.dart';

import '../app/settings.dart';
import 'tokens.dart';

/// What a page is for, above its card. Closing it folds it and never removes it: a small block stays,
/// which opens it again, and what is folded is kept across a restart.
class PageExplanation extends StatelessWidget {
  /// Constructor taking which page's, its parts, and where the fold is kept.
  const PageExplanation({required this.id, required this.settings, required this.parts, super.key});

  /// The name the fold is kept under.
  final String id;

  /// Where the fold is kept.
  final Settings settings;

  /// The parts, each a question or a heading and its words; the first's question stands on the fold.
  final List<({String title, String words})> parts;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      if (settings.explanationsFolded.contains(id)) {
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.normal, vertical: Space.tight),
            child: TextButton.icon(
              key: ValueKey<String>('explanation-open $id'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => settings.setExplanationFolded(id, folded: false),
              icon: const Icon(Icons.info_outline, size: Sizes.rowIcon),
              label: Text(parts.first.title),
            ),
          ),
        );
      }
      final text = Theme.of(context).textTheme;
      Widget said(({String title, String words}) part) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(part.title, style: text.titleSmall),
          Text(part.words),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(left: Space.normal, top: Space.normal, right: Space.normal),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.normal),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.info_outline),
                const SizedBox(width: Space.normal),
                Expanded(
                  child: Wrap(
                    spacing: Space.normal,
                    runSpacing: Space.small,
                    children: <Widget>[
                      for (final part in parts)
                        if (parts.length == 1) said(part) else SizedBox(width: Sizes.dialogSmall, child: said(part)),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('explanation-fold $id'),
                  tooltip: 'Fold this explanation',
                  onPressed: () => settings.setExplanationFolded(id, folded: true),
                  icon: const Icon(Icons.expand_less),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
