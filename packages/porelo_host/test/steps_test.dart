import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  // Harm: losing timestamps across the host protocol corrupts a rented run's step history.
  test('host step timestamps survive writing and reading alongside older lines', () {
    const instant = '2000-02-29T12:34:56.123456Z';
    for (final step in [
      const Step('plan', StepState.plan, steps: [PlannedStep('rent', 'Rent the server', seconds: 300)]),
      const Step('rent', StepState.started),
      const Step('prepare-account', StepState.done, text: 'Prepare the account'),
    ]) {
      final output = StringBuffer();
      writeHostStep(step, output: output, errors: StringBuffer(), now: () => DateTime.parse(instant));
      final fields = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(fields['at'], instant, reason: 'every emitted step carries its UTC instant');
      final read = Step.fromLine(output.toString());
      expect(read, isNotNull);
      expect((jsonDecode(read!.toLine()) as Map<String, Object?>)['at'], instant);
      fields.remove('at');
      final older = Step.fromLine(jsonEncode(fields));
      expect(older, isNotNull, reason: 'older hosts still deliver valid steps');
      expect(older!.state, step.state);
      expect((jsonDecode(older.toLine()) as Map<String, Object?>)['at'], isNull);
    }
    final offset = Step.fromLine('{"step":"rent","state":"started","at":"2000-02-29T14:34:56.123456+02:00"}');
    expect((jsonDecode(offset!.toLine()) as Map<String, Object?>)['at'], instant);
  });

  // Harm: malformed host timestamps crash the protocol or turn a lost line into accepted progress.
  test('malformed timestamps lose only their own line without throwing', () {
    final accepted = <Object?>[];
    for (final at in [
      null,
      42,
      true,
      <Object>[],
      <String, Object>{},
      '',
      'not a time',
      '2000-02-29',
      '2000-02-29T12:34:56',
      '2000-02-30T12:34:56Z',
      '2000-13-01T12:34:56Z',
      '2000-02-29T24:34:56Z',
      '2000-02-29T12:60:56Z',
      '2000-02-29T12:34:99Z',
      '2000-02-29T12:34:56+24:00',
      '2000-02-29T12:34:56+02:60',
    ]) {
      for (final fields in [
        {'step': 'rent', 'state': 'started', 'at': at},
        {'v': 1, 'state': 'plan', 'steps': <Object>[], 'at': at},
      ]) {
        if (Step.fromLine(jsonEncode(fields)) != null) accepted.add(fields);
      }
    }
    expect(accepted, isEmpty, reason: 'a malformed known field invalidates the entire line');
    expect(Step.fromLine('{"step":"rent","state":"done"}')?.state, StepState.done);
  });

  // Harm: losing the stop destination sends a terminal to the wrong host.
  test('a step line reads back as the step it was', () {
    const step = Step(
      'person',
      StepState.waiting,
      needs: <String>['drive', 'vault-new'],
      words: 'needed',
      address: '203.0.113.7',
      account: 'porelo',
    );
    final read = Step.fromLine(step.toLine())!;
    expect(read.step, 'person');
    expect(read.state, StepState.waiting);
    expect(read.needs, <String>['drive', 'vault-new']);
    expect(read.words, 'needed');
    expect(read.address, '203.0.113.7');
    expect(read.account, 'porelo');
  });

  test('a line that is not a step reads as none', () {
    expect(Step.fromLine('PLAY [first]'), isNull);
    expect(Step.fromLine('{"step": "x", "state": "dancing"}'), isNull);
    expect(Step.fromLine('[1, 2]'), isNull);
  });

  // Harm: a plan of an unknown version is read as this one and shows wrong steps and times.
  test('a plan line of another version reads as none', () {
    const steps = '"steps":[{"task":"first","text":"First","seconds":20}]';
    expect(Step.fromLine('{"v":1,"state":"plan",$steps}')?.state, StepState.plan);
    expect(Step.fromLine('{"v":2,"state":"plan",$steps}'), isNull);
    expect(Step.fromLine('{"state":"plan",$steps}'), isNull);
  });
}
