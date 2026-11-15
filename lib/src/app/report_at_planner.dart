import 'dart:async';

import 'package:porelo_planning/porelo_planning.dart';

/// A planning source that tells [ReportAtPlanner] of each task report it sends, by [ReportAtPlanner.told]: only through
/// such a source does the window know whether a report it sent through the planning screen's run reached the planner,
/// since that run answers one failure for the report and for what it starts after the planner's answer.
abstract interface class TellsTaskReports implements PlanningSource {}

/// What one task report, sent within [watch], came to at its planner: whether the planner was asked, and whether it
/// answered.
final class ReportAtPlanner {
  /// Watches the report of [offer].
  ReportAtPlanner(this.offer);

  /// The offer the watched report is of.
  final String offer;

  bool _asked = false, _answered = false;

  /// Whether a [TellsTaskReports] source asked the planner to take the report.
  bool get asked => _asked;

  /// Whether the planner answered the report: it took it, whatever failed after its answer.
  bool get answered => _answered;

  static final _key = Object();

  /// Runs [send], which reports [offer], told of what the report came to at its planner.
  Future<T> watch<T>(Future<T> Function() send) => runZoned(send, zoneValues: {_key: this});

  /// Sends [send], a report of [offer] to the planner, as a [TellsTaskReports] source sends each: told asked before,
  /// and answered once the planner answered, to the [watch] it is sent within.
  static Future<T> told<T>(String offer, Future<T> Function() send) async {
    final at = switch (Zone.current[_key]) {
      final ReportAtPlanner at when at.offer == offer => at,
      _ => null,
    };
    at?._asked = true;
    final answer = await send();
    at?._answered = true;
    return answer;
  }
}
