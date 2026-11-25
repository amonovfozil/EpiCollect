import 'package:flutter_test/flutter_test.dart';
import 'package:epicollect/core/forms.dart';
import 'package:epicollect/core/api.dart';

void main() {
  final form = <String, dynamic>{
    'questions': [
      {'id': 1, 'sort_order': 0, 'type': 'radio'},
      {'id': 2, 'sort_order': 1, 'type': 'group'},
      {
        'id': 3,
        'sort_order': 2,
        'parent_question_id': 2,
        'type': 'text',
        'is_required': true,
      },
    ],
    'conditions': [
      {
        'source_question_id': 1,
        'target_question_id': 2,
        'operator': 'equals',
        'comparison_value': 'yes',
        'action': 'show',
      },
    ],
  };
  test('hidden container hides children and excludes stale answers', () {
    expect(
      visibleQuestions(form, {'1': 'no', '3': 'stale'}).map((q) => q['id']),
      [1],
    );
    expect(answerPayload(form, {'1': 'no', '3': 'stale'}), [
      {'question_id': 1, 'value': 'no'},
    ]);
  });
  test('visible parent restores conditional required child', () {
    expect(visibleQuestions(form, {'1': 'yes'}).map((q) => q['id']), [1, 2, 3]);
    expect(
      validateAnswer(Json.from((form['questions'] as List).last), null),
      isNotNull,
    );
  });
  test('numeric comparison handles numeric string and text remains strict', () {
    final rule = {'operator': 'equals', 'comparison_value': '12'};
    expect(compareAnswer(12, rule, 'numeric'), true);
    expect(compareAnswer(12, rule, 'text'), false);
  });
  test('required, ranges, decimals and coordinates validate', () {
    expect(
      validateAnswer({'type': 'checkbox', 'is_required': true}, []),
      isNotNull,
    );
    expect(
      validateAnswer({
        'type': 'numeric',
        'settings': {'min': 2, 'max': 8},
      }, 9),
      isNotNull,
    );
    expect(
      validateAnswer({
        'type': 'numeric',
        'settings': {'decimal': false},
      }, 2.5),
      isNotNull,
    );
    expect(
      validateAnswer({'type': 'location'}, {'latitude': 91, 'longitude': 2}),
      isNotNull,
    );
    expect(
      validateAnswer(
        {'type': 'location'},
        {'latitude': 39.65, 'longitude': 66.96},
      ),
      isNull,
    );
  });

  test('submitted answers read the server question snapshot', () {
    final a = {
      'question_id': 1,
      'question_text_snapshot': 'Name of observation',
      'option_snapshot': [],
      'answer_text': 'Demo observation',
    };
    expect(questionLabel(a), 'Name of observation');
    expect(answerText(a), 'Demo observation');
    expect(
      answerText({
        'option_snapshot': [
          {'label': 'No', 'value': 'no'},
        ],
        'answer_text': 'no',
      }),
      'No',
    );
    expect(isAnswered({'latitude': null, 'longitude': null}), isFalse);
    expect(isAnswered(['x']), isTrue);
  });
}
