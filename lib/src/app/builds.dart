import 'package:porelo_frontend/client.dart';

/// What the builds of a task's pushes say, in words, as the machine follows them at the forge.
///
/// **Three states before any build, never guessed:** no reader follows this task (nothing is said),
/// a reader follows it and nothing was pushed yet, and a reader is named but does not work. The
/// machine says which through `buildReader` and `buildProblem`; a machine older than both says
/// nothing, which is not *no builds*.
abstract final class BuildsSaid {
  /// What a work tile says about builds, or null when there is nothing to say: a headline that
  /// stands out, and the commit, the jobs and the age under it: the build is a step that matters, and
  /// the jobs are only extra.
  static BuildLine? onTheTile(Task task, {DateTime? now}) {
    final reader = task.buildReader;
    if (reader == null || reader.isEmpty) return null;
    final problem = task.buildProblem ?? '';
    if (problem.isNotEmpty) return BuildLine(BuildLook.none, 'Builds not followed', problem);
    final latest = task.builds?.firstOrNull;
    if (latest == null) {
      return BuildLine(BuildLook.none, 'No build yet', 'no push yet; its builds are read from $reader');
    }
    final (look, headline) = switch (latest.verdict) {
      'success' => (BuildLook.passed, 'Build passed'),
      'failure' => (BuildLook.failed, 'Build failed'),
      'queued' => (BuildLook.running, 'Build queued'),
      'running' => (BuildLook.running, 'Build running'),
      '' => (BuildLook.none, 'Build: no verdict given'),
      // Said as it comes, never mapped onto one of the three: a verdict this interface does not
      // know is not a pass, a failure or a run.
      'cancelled' || 'unknown' => (BuildLook.none, 'Build ${latest.verdict}'),
      final other => (BuildLook.none, 'Build: $other'),
    };
    final failed = latest.jobs.where((job) => job.result == 'failure').length;
    final age = _age(latest.since, now ?? DateTime.now().toUtc());
    return BuildLine(
      look,
      headline,
      <String>[
        latest.short,
        if (latest.jobs.isNotEmpty)
          '${latest.jobs.length} ${latest.jobs.length == 1 ? 'job' : 'jobs'}${failed > 0 ? ', $failed failed' : ''}',
        if (latest.detail.isNotEmpty) latest.detail,
        ?age,
      ].join(' · '),
    );
  }

  /// How long ago, from the time the machine wrote; null when it wrote none this can read.
  static String? _age(String since, DateTime now) {
    final then = DateTime.tryParse(since);
    if (then == null) return null;
    final gone = now.difference(then);
    if (gone.inMinutes < 1) return 'just now';
    if (gone.inHours < 1) return '${gone.inMinutes} min ago';
    if (gone.inDays < 1) return '${gone.inHours} h ago';
    return '${gone.inDays} d ago';
  }

  /// The lines the work's detail shows, newest build first; empty when there is nothing to say.
  static List<String> inTheDetail(Task task) {
    final reader = task.buildReader;
    if (reader == null || reader.isEmpty) return const [];
    final problem = task.buildProblem ?? '';
    final builds = task.builds ?? const <Build>[];
    return <String>[
      if (problem.isNotEmpty) 'not followed: $problem',
      if (problem.isEmpty && builds.isEmpty) 'no push yet; read from $reader',
      for (final build in builds) ...<String>[
        '${build.short}: ${_verdict(build)}${build.since.isEmpty ? '' : ', since ${build.since}'}',
        if (build.underway)
          '  no jobs yet'
        else
          for (final job in build.jobs)
            '  ${job.name}: ${job.result}, ${job.log.isEmpty ? 'no log here' : 'log in /porelo/files/${job.log}'}',
      ],
    ];
  }

  static String _verdict(Build build) {
    final failed = build.jobs.where((job) => job.result == 'failure').length;
    final verdict = build.verdict.isEmpty ? 'no verdict given' : build.verdict;
    return <String>[
      verdict,
      if (build.jobs.isNotEmpty) '${build.jobs.length} ${build.jobs.length == 1 ? 'job' : 'jobs'}',
      if (failed > 0) '$failed failed',
      if (build.detail.isNotEmpty) build.detail,
    ].join(', ');
  }
}

/// How a build reads at a glance: each drawn with its own shape and colour, and said in a word.
enum BuildLook {
  /// Every job passed.
  passed,

  /// A job failed, or the build did.
  failed,

  /// It has not ended.
  running,

  /// There is no build to show.
  none,
}

/// What a work tile says about the build of its last push.
final class BuildLine {
  /// Constructor taking how it looks, its headline and its detail.
  const BuildLine(this.look, this.headline, this.detail);

  /// Passed, failed, running, or none of them.
  final BuildLook look;

  /// The word that stands out, such as "Build failed".
  final String headline;

  /// The commit, the jobs and the age, or why there is no build.
  final String detail;
}
