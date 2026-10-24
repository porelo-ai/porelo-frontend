import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
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
}
