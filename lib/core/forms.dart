import 'api.dart';

const containers = ['group', 'branch', 'readme'];
bool compareAnswer(dynamic value, Json rule, String type) {
  if (value == null) return false;
  final target = rule['comparison_value'];
  final a = num.tryParse('$value'), b = num.tryParse('$target');
  final numeric = type == 'numeric' && a != null && b != null;
  switch (rule['operator']) {
    case 'equals':
      return numeric ? a == b : value == target;
    case 'not_equals':
      return numeric ? a != b : value != target;
    case 'contains':
      return value is List
          ? value.contains(target)
          : value is String && target is String && value.contains(target);
    case 'not_contains':
      return value is List
          ? !value.contains(target)
          : value is String && target is String && !value.contains(target);
    case 'greater_than':
      return a != null && b != null && a > b;
    case 'less_than':
      return a != null && b != null && a < b;
    case 'greater_or_equal':
      return a != null && b != null && a >= b;
    case 'less_or_equal':
      return a != null && b != null && a <= b;
    default:
      return false;
  }
}

List<Json> visibleQuestions(Json form, Map<String, dynamic> answers) {
  final questions = List<Json>.from(form['questions'] ?? [])
    ..sort((a, b) {
      final c = (a['sort_order'] as num).compareTo(b['sort_order']);
      return c == 0 ? (a['id'] as num).compareTo(b['id']) : c;
    });
  final visible = <dynamic, bool>{};
  final byId = {for (final q in questions) q['id']: q};
  final result = <Json>[];
  for (final q in questions) {
    final rules = List<Json>.from(form['conditions'] ?? [])
        .where((r) => r['target_question_id'] == q['id']);
    bool match(Json r) =>
        visible[r['source_question_id']] == true &&
        compareAnswer(
          answers['${r['source_question_id']}'],
          r,
          byId[r['source_question_id']]?['type'] ?? 'text',
        );
    final show = rules.where((r) => r['action'] == 'show'),
        hide = rules.where((r) => r['action'] == 'hide');
    final yes =
        (show.isEmpty || show.any(match)) &&
        !hide.any(match) &&
        (q['parent_question_id'] == null ||
            visible[q['parent_question_id']] == true);
    visible[q['id']] = yes;
    if (yes) result.add(q);
  }
  return result;
}

List<Json> answerPayload(Json form, Map<String, dynamic> answers) =>
    visibleQuestions(form, answers)
        .where((q) => !containers.contains(q['type']))
        .map(
          (q) => <String, dynamic>{
            'question_id': q['id'],
            'value': answers['${q['id']}'],
          },
        )
        .toList();
String? validateAnswer(Json q, dynamic v) {
  final empty =
      v == null ||
      (v is String && v.trim().isEmpty) ||
      (v is List && v.isEmpty);
  if (q['is_required'] == true && empty) return 'Bu maydonni to‘ldiring';
  if (empty) return null;
  final s = q['settings'] is Map
      ? Map<String, dynamic>.from(q['settings'])
      : <String, dynamic>{};
  if (q['type'] == 'numeric') {
    final n = num.tryParse('$v');
    if (n == null) return 'To‘g‘ri son kiriting';
    if (s['min'] != null && n < num.parse('${s['min']}')) {
      return 'Eng kam qiymat: ${s['min']}';
    }
    if (s['max'] != null && n > num.parse('${s['max']}')) {
      return 'Eng katta qiymat: ${s['max']}';
    }
    if (s['decimal'] == false && n != n.roundToDouble()) {
      return 'Butun son kiriting';
    }
  }
  if (v is String) {
    if (s['min_length'] != null && v.length < num.parse('${s['min_length']}')) {
      return 'Kamida ${s['min_length']} belgi kiriting';
    }
    if (s['max_length'] != null && v.length > num.parse('${s['max_length']}')) {
      return 'Ko‘pi bilan ${s['max_length']} belgi kiriting';
    }
  }
  if (q['type'] == 'location') {
    if (v is! Map) return 'Joylashuvni kiriting';
    final lat = num.tryParse('${v['latitude']}'),
        lon = num.tryParse('${v['longitude']}');
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      return 'To‘g‘ri koordinatalarni kiriting';
    }
  }
  return null;
}

/// Question text of a submitted answer. The server stores it as
/// `question_text_snapshot`; older shapes are accepted as fallbacks.
String questionLabel(Json a) {
  final snap = a['question_snapshot'];
  return (a['question_text_snapshot'] ??
          (snap is Map ? snap['question'] : snap) ??
          a['question_text'] ??
          a['question'] ??
          'Savol ${a['question_id']}')
      .toString();
}

String answerText(Json a) {
  final options = a['option_snapshot'];
  if (options is List && options.isNotEmpty) {
    return options.map((x) => x['label']).join(', ');
  }
  final b = a['answer_boolean'];
  if (b is bool) return b ? 'Ha' : 'Yo‘q';
  final json = a['answer_json'];
  if (json is Map && json['latitude'] != null) {
    return '${json['latitude']}, ${json['longitude']}';
  }
  if (json is List) return '${json.length} ta fayl';
  final v =
      a['answer_text'] ??
      a['answer_numeric'] ??
      a['answer_date'] ??
      a['answer_time'] ??
      json;
  return v == null || '$v'.isEmpty ? '—' : v.toString();
}

/// Whether a value counts as answered for progress.
bool isAnswered(dynamic v) =>
    v != null &&
    !(v is String && v.trim().isEmpty) &&
    !(v is List && v.isEmpty) &&
    !(v is Map && v.values.every((x) => x == null));
