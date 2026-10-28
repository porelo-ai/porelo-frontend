import 'package:porelo_frontend/client.dart';

/// How long a task has been in the state it is in, in words.
///
/// Arithmetic on `since`, never a reading of `state`: the runtime's words are for a person and
/// the contract says plainly not to parse them. "Idle for forty minutes" is the question this
/// answers, and it is the one that says whether an unattended run has stopped being useful.
///
/// Answers null when the runtime could not say. A container created and never started reports a
/// zero time, which renders as a date centuries out — showing that would be worse than showing
/// nothing, so nothing is what it shows.
String? howLong(Task task, {DateTime? now}) => howLongSince(task.startedAt, now: now);

/// How long ago something was, in words, or null when nothing can say.
///
/// The same arithmetic and the same wording as a task's state, because *"four hours ago"* is the
/// same question whether it is asked of a run or of a backup.
String? howLongSince(DateTime? began, {DateTime? now}) {
  if (began == null) return null;
  final elapsed = (now ?? DateTime.now()).difference(began);
  if (elapsed.isNegative) return null;
  if (elapsed.inMinutes < 1) return 'less than a minute';
  if (elapsed.inMinutes == 1) return '1 minute';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} minutes';
  if (elapsed.inHours == 1) return '1 hour';
  if (elapsed.inDays < 1) return '${elapsed.inHours} hours';
  if (elapsed.inDays == 1) return '1 day';
  return '${elapsed.inDays} days';
}

/// The local time of day of [time], hours and minutes.
String clockTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// How long until something, in words, or null when nothing can say or it has passed.
String? howLongUntil(DateTime? end, {DateTime? now}) =>
    end == null ? null : howLongSince(now ?? DateTime.now(), now: end);
