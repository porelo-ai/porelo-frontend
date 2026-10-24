import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dialog_scroll.dart';
import 'tokens.dart';

/// One question, whose values and controllers belong to the wizard's caller.
@immutable
class WizardStep {
  /// Declares what is asked, how it is checked, and what is reviewed before starting.
  const WizardStep({
    required this.title,
    required this.words,
    required this.panel,
    required this.check,
    required this.summary,
    this.beforeNext,
  });

  /// The short name in the step indicator.
  final String title;

  /// What the question is for and where its answers are found.
  final String words;

  /// Builds only this step's fields; the frame supplies scrolling and focus.
  final WidgetBuilder panel;

  /// Null when this step may advance, otherwise the reason it cannot.
  final ValueGetter<String?> check;

  /// Completes an external input check while this question is still shown.
  final Future<bool> Function()? beforeNext;

  /// Lines reviewed before an external action starts; never include secret values.
  final ValueGetter<List<String>> summary;
}

/// The external action's answer, independent of any particular service or process.
enum WizardActionState {
  /// Work is under way.
  running,

  /// Work is stopped for a person or an external answer.
  waiting,

  /// The external action confirmed completion.
  done,

  /// The action refused; its panel says why.
  refused,
}

/// A step after the review, whose owner runs and reports an external action.
@immutable
class WizardActionStep {
  /// Declares the action and the panel that explains its progress and refusals.
  const WizardActionStep({
    required this.title,
    required this.words,
    required this.panel,
    required this.run,
    required this.state,
  });

  /// The short name in the step indicator.
  final String title;

  /// What is happening and what the person may need to do.
  final String words;

  /// Progress, any stop, and the action's own refusal or completion.
  final WidgetBuilder panel;

  /// Starts work on entry, after the person explicitly starts or advances.
  final AsyncCallback run;

  /// The owner's current answer; only done permits advancing or finishing.
  final ValueGetter<WizardActionState> state;
}

/// Builds additional actions; [run] opens the progress panel before running one.
typedef WizardActionsBuilder = Widget Function(BuildContext context, Future<void> Function(AsyncCallback action) run);

/// A sequence of questions, a review, and optional external actions.
///
/// Rebuild this widget or notify [changes] when checks, summaries or action states change.
/// Values stay with the caller; the frame holds only navigation and confirmation state.
class Wizard extends StatefulWidget {
  /// Declares a wizard without any knowledge of the service it acts on.
  const Wizard({
    required this.title,
    required this.steps,
    required this.action,
    this.actionKey = const Key('wizard-start'),
    this.actionSteps = const [],
    this.changes,
    this.onFinish,
    this.reviewWords,
    this.actions,
    this.scrollController,
    super.key,
  }) : assert(steps.length > 0),
       assert(actions == null || actionSteps.length > 0);

  /// The dialog's title.
  final String title;

  /// Introduces the review in the caller's own words.
  final String? reviewWords;

  /// Questions shown one at a time, followed by the generated review.
  final List<WizardStep> steps;

  /// The explicit decision on the review's start button.
  final String action;

  /// A caller's established handle for the review's start button.
  final Key actionKey;

  /// External steps run only after Check and start.
  final List<WizardActionStep> actionSteps;

  /// Optional notifications from controllers and external action owners.
  final Listenable? changes;

  /// Called after the final confirmed completion; otherwise the dialog closes.
  final VoidCallback? onFinish;

  /// Additional actions belonging to the caller, beside the frame's navigation.
  final WizardActionsBuilder? actions;

  /// Lets an action owner scroll its stop into view inside the current panel.
  final ScrollController? scrollController;

  @override
  State<Wizard> createState() => _WizardState();
}

class _WizardState extends State<Wizard> {
  int _index = 0;
  bool _executing = false;
  final _startedActions = <int>{};
  bool _asking = false;
  bool _checking = false;
  String? _failed;
  final _panel = GlobalKey();
  late final List<List<String>> _initial;

  @override
  void initState() {
    super.initState();
    _initial = [for (final step in widget.steps) List.of(step.summary())];
    widget.changes?.addListener(_changed);
    _focusFirst();
  }

  @override
  void didUpdateWidget(Wizard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) {
      oldWidget.changes?.removeListener(_changed);
      widget.changes?.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.changes?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  WizardActionStep? get _actionStep {
    final action = _index - widget.steps.length - 1;
    return action < 0 ? null : widget.actionSteps[action];
  }

  bool get _busy =>
      _executing ||
      _startedActions.any(
        (index) => switch (widget.actionSteps[index].state()) {
          WizardActionState.running || WizardActionState.waiting => true,
          _ => false,
        },
      );

  bool get _given =>
      _startedActions.isNotEmpty ||
      !listEquals(_initial.expand((lines) => lines).toList(), [for (final step in widget.steps) ...step.summary()]);

  String? get _inputProblem {
    for (final step in widget.steps) {
      final reason = step.check();
      if (reason != null) return reason;
    }
    return null;
  }

  String? get _reason {
    if (_checking) return 'Wait for the input check to answer.';
    if (_index < widget.steps.length) return widget.steps[_index].check();
    if (_actionStep case final step?) {
      if (_failed != null) return _failed;
      if (_executing) return 'Wait for the action to answer.';
      return switch (step.state()) {
        WizardActionState.running => 'Wait for the action to answer.',
        WizardActionState.waiting => 'Complete what this step asks before going on.',
        WizardActionState.refused => 'This action was refused. Read its answer before trying again.',
        WizardActionState.done => null,
      };
    }
    return _inputProblem;
  }

  void _focusFirst() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    // Focus traversal alone may choose a picker before the first editable field.
    EditableTextState? first;
    void visit(Element element) {
      if (first != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        final field = element.state as EditableTextState;
        if (field.widget.focusNode.canRequestFocus && !field.widget.readOnly) first = field;
      }
      element.visitChildren(visit);
    }

    (_panel.currentContext as Element?)?.visitChildren(visit);
    first?.widget.focusNode.requestFocus();
  });

  void _go(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _index = index;
      _failed = null;
    });
    _focusFirst();
  }

  Future<bool> _confirm(String navigation) async {
    if (_asking) return false;
    _asking = true;
    try {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(navigation == 'back' ? 'Go back while work is unfinished?' : 'Leave this wizard?'),
              content: Text(
                _busy
                    ? 'The action is unfinished and may keep running. Keep track of its progress before leaving this step.'
                    : 'The values you gave will be dropped.',
              ),
              actions: [
                TextButton(
                  key: const Key('wizard-stay'),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Stay'),
                ),
                FilledButton(
                  key: Key('wizard-confirm-$navigation'),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(navigation == 'back' ? 'Go back' : 'Leave'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      _asking = false;
    }
  }

  Future<void> _back() async {
    if (_index == 0 || _checking) return;
    if (_busy && !await _confirm('back')) return;
    if (mounted) _go(_index - 1);
  }

  Future<void> _leave() async {
    if ((_given || _busy) && !await _confirm('leave')) return;
    if (mounted) Navigator.of(context).pop();
  }

  void _finish() {
    if (widget.onFinish case final finish?) {
      finish();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _next(int shownIndex) async {
    // A second pointer on an old Next button must never accept the unseen start decision.
    if (_index != shownIndex) return;
    // Recheck at the decision too, so a changed answer never bypasses its check.
    if (_reason != null) {
      _changed();
      return;
    }
    if (_index < widget.steps.length && widget.steps[_index].beforeNext != null) {
      final check = widget.steps[_index].beforeNext!;
      setState(() => _checking = true);
      bool accepted;
      try {
        accepted = await check();
      } finally {
        if (mounted) setState(() => _checking = false);
      }
      if (!mounted || !accepted || _index != shownIndex || _reason != null) return;
    }
    final last = widget.steps.length + widget.actionSteps.length;
    if (_index == last) {
      _finish();
      return;
    }
    _go(_index + 1);
    final action = _actionStep;
    if (action != null &&
        !(_startedActions.contains(_index - widget.steps.length - 1) &&
            (action.state() == WizardActionState.running || action.state() == WizardActionState.waiting))) {
      await _run(action.run);
    }
  }

  Future<void> _run(AsyncCallback run) async {
    if (_executing) return;
    if (_actionStep == null) _go(widget.steps.length + 1);
    setState(() {
      _executing = true;
      _startedActions.add(_index - widget.steps.length - 1);
      _failed = null;
    });
    try {
      await run();
    } on Exception {
      if (mounted) setState(() => _failed = 'The action could not complete. Check its progress before trying again.');
    } finally {
      if (mounted) setState(() => _executing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _index < widget.steps.length ? widget.steps[_index] : null;
    final action = _actionStep;
    final review = question == null && action == null;
    final title = question?.title ?? action?.title ?? 'Check and start';
    final words = question?.words ?? action?.words ?? widget.reviewWords ?? 'Check every answer before starting.';
    final reason = _reason;
    final shownIndex = _index;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.all(Space.wide),
        title: Text(widget.title),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.normal,
            children: [
              Text('Step ${_index + 1} of ${widget.steps.length + widget.actionSteps.length + 1} — $title'),
              Flexible(
                child: DialogScroll(
                  key: ValueKey(_index),
                  controller: widget.scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Space.normal,
                    children: [
                      Text(words),
                      if (action != null)
                        Text(
                          (_failed != null
                                  ? WizardActionState.refused
                                  : _executing
                                  ? WizardActionState.running
                                  : action.state())
                              .name,
                        ),
                      KeyedSubtree(
                        key: _panel,
                        child:
                            question?.panel(context) ??
                            action?.panel(context) ??
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: Space.small,
                              children: [
                                for (final step in widget.steps) ...[
                                  Text(step.title, style: Theme.of(context).textTheme.titleSmall),
                                  for (final line in step.summary()) Text(line),
                                ],
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: Sizes.dialogMedium,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: Space.small,
                  runSpacing: Space.small,
                  children: [
                    if (widget.actions case final actions?) actions(context, _run),
                    TextButton(key: const Key('wizard-leave'), onPressed: _leave, child: const Text('Leave')),
                    if (_index > 0)
                      TextButton(key: const Key('wizard-back'), onPressed: _back, child: const Text('Back')),
                    FilledButton(
                      key: review ? widget.actionKey : const Key('wizard-next'),
                      onPressed: reason == null ? () => _next(shownIndex) : null,
                      child: Text(
                        review
                            ? widget.action
                            : action != null && _index == widget.steps.length + widget.actionSteps.length
                            ? 'Finish'
                            : 'Next',
                      ),
                    ),
                  ],
                ),
                if (reason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.small),
                    child: Text(reason, textAlign: TextAlign.end),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
