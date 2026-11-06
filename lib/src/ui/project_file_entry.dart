import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/organization_source.dart';
import 'tokens.dart';

/// The entry a project admin writes into a project file and commits: Porelo changes no project file that exists.
class ProjectFileEntry extends StatelessWidget {
  /// Shows [byHand]'s entry, the file it goes in, and what the person does with it.
  const ProjectFileEntry(this.byHand, {super.key});

  /// What Porelo said to write, and for which project.
  final ProjectFileByHand byHand;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('project-file-entry'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (byHand.entry == null)
        // Nothing to write, only something to take out: Porelo's own words say what.
        Text(byHand.words, key: const Key('project-file-entry-words'))
      else ...[
        Text(
          'Porelo changes no project file that exists, so nothing was changed. '
          'Write this into ${byHand.file}, keeping all else it holds, and commit it signed with the key of an admin '
          'of the project.',
        ),
        const SizedBox(height: Space.small),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              // Verbatim: Porelo wrote it from the file's own model, and a copy reworded here could be refused.
              child: SelectableText(
                byHand.entry!,
                key: const Key('project-file-entry-text'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            IconButton(
              key: const Key('copy-project-file-entry'),
              icon: const Icon(Icons.copy, size: Sizes.rowIcon),
              tooltip: 'Copy the entry',
              onPressed: () => Clipboard.setData(ClipboardData(text: byHand.entry!)),
            ),
          ],
        ),
      ],
      const Text('Once it is committed, the project page shows it on its next read.'),
    ],
  );
}
