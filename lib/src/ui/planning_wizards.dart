import 'package:flutter/material.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningWizardStep, PlanningWizards;

import 'wizard.dart';

/// Shows the planning screen's wizards, such as *Start work*, in the window's own wizard frame: one step at a time,
/// a review with *Change* beside each step, and the start on the review's button.
class WindowPlanningWizards implements PlanningWizards {
  /// Takes nothing: the steps, their values and the start are the screen's.
  const WindowPlanningWizards();

  @override
  Future<bool> show(
    BuildContext context, {
    required String title,
    required List<PlanningWizardStep> steps,
    required Listenable changes,
    required String Function() startLabel,
    required Future<bool> Function() start,
    required bool Function() canCancel,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Wizard(
          title: title,
          action: startLabel(),
          actionWords: startLabel,
          changes: changes,
          start: start,
          canLeave: canCancel,
          steps: [
            for (final step in steps)
              WizardStep(
                title: step.title,
                words: step.words,
                panel: step.panel,
                check: step.check,
                summary: step.summary,
                shown: step.shown,
              ),
          ],
        ),
      ) ??
      false;
}
