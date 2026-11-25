import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:uuid/uuid.dart';

import '../core/api.dart';
import '../core/drafts.dart';
import '../core/forms.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/question.dart';

class CollectScreen extends StatefulWidget {
  final Api api;
  final Json project;
  const CollectScreen({super.key, required this.api, required this.project});
  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> {
  Json? form, current;
  Map<String, dynamic> answers = {};
  bool loading = true, busy = false, dirty = false, leaving = false;
  bool showErrors = false;
  Object? error;
  String requestId = const Uuid().v4();
  final uploads = <String>{};
  final keys = <String, GlobalKey>{};

  int get projectId => widget.project['id'];
  Drafts get drafts => Drafts('${widget.api.user?['id']}');
  bool get locked =>
      widget.project['status'] != 'active' ||
      (current != null &&
          (current!['status'] != 'pending' ||
              current!['is_deleted'] == true ||
              current!['is_editable'] == false));

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.get('/projects/$projectId/form'),
        widget.api.get('/projects/$projectId/my-submission'),
      ]);
      final f = results[0]['data'] as Json, c = results[1]['data'] as Json?;
      final values = <String, dynamic>{};
      for (final a in List<Json>.from(c?['answers'] ?? [])) {
        values['${a['question_id']}'] =
            a['answer_json'] ??
            a['answer_text'] ??
            a['answer_numeric'] ??
            a['answer_date'] ??
            a['answer_time'] ??
            a['answer_boolean'];
      }
      final draft = await drafts.read(projectId);
      if (!mounted) return;
      setState(() {
        form = f;
        current = c;
        answers = values;
        loading = false;
      });
      if (draft != null && !locked && mounted) {
        final restore = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Qoralama topildi'),
            content: Text(
              '${dateText(draft['updated_at'], time: true)} da saqlangan javoblarni davom ettirasizmi?',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  current == null ? 'Yangidan boshlash' : 'Serverdagi javob',
                ),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Davom etish'),
              ),
            ],
          ),
        );
        if (restore == true && mounted) {
          setState(() {
            answers = Map<String, dynamic>.from(draft['answers']);
            requestId = draft['request_id'] ?? const Uuid().v4();
            dirty = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  void change(String key, dynamic value) {
    setState(() {
      answers[key] = value;
      dirty = true;
      requestId = const Uuid().v4();
      final ids = visibleQuestions(
        form!,
        answers,
      ).map((q) => '${q['id']}').toSet();
      answers.removeWhere((k, v) => !ids.contains(k));
    });
  }

  Future<bool> save() async {
    try {
      await drafts.save(projectId, {
        'project': widget.project,
        'form_id': form!['id'],
        'answers': answers,
        'request_id': requestId,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        setState(() => dirty = false);
        toast(context, 'Qoralama qurilmada saqlandi');
      }
      return true;
    } catch (e) {
      if (mounted) setState(() => error = e);
      return false;
    }
  }

  void close() {
    setState(() => leaving = true);
    Navigator.pop(context);
  }

  Future<void> leave() async {
    if (busy || uploads.isNotEmpty) return;
    if (!dirty) return close();
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: const Text('Saqlanmagan javoblar bor'),
        message: const Text(
          'Qoralamani saqlasangiz, keyin shu joydan davom ettirasiz.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(c, 'save'),
            child: const Text('Qoralamani saqlash'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, 'discard'),
            child: const Text('Saqlamasdan chiqish'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(c),
          child: const Text('Davom etish'),
        ),
      ),
    );
    if (result == 'save' && !await save()) return;
    if ((result == 'save' || result == 'discard') && mounted) close();
  }

  Map<String, String> errorsFor(List<Json> questions) => {
    for (final q in questions)
      if (!containers.contains(q['type']))
        if (validateAnswer(q, answers['${q['id']}']) case final String e)
          '${q['id']}': e,
  };

  Future<void> submit() async {
    final questions = visibleQuestions(form!, answers);
    final errors = errorsFor(questions);
    FocusScope.of(context).unfocus();
    if (errors.isNotEmpty) {
      setState(() => showErrors = true);
      final first = questions.firstWhere(
        (q) => errors.containsKey('${q['id']}'),
      );
      final ctx = keys['${first['id']}']?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: .1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
      toast(
        context,
        errors.length == 1
            ? '1 ta savolni tekshiring'
            : '${errors.length} ta savolni tekshiring',
        error: true,
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final path =
          '/projects/$projectId/submissions${current == null ? '' : '/${current!['id']}'}';
      await widget.api.request(
        current == null ? 'POST' : 'PATCH',
        path,
        body: {'answers': answerPayload(form!, answers)},
        idempotencyKey: requestId,
      );
      await drafts.remove(projectId);
      if (mounted) {
        dirty = false;
        toast(
          context,
          current == null ? 'Javob yuborildi' : 'O‘zgarishlar saqlandi',
        );
        close();
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = form == null
        ? <Json>[]
        : visibleQuestions(form!, answers);
    final fields = questions
        .where((q) => !containers.contains(q['type']))
        .toList();
    final answered = fields
        .where((q) => isAnswered(answers['${q['id']}']))
        .length;
    final errors = showErrors ? errorsFor(questions) : const <String, String>{};
    final blocked = busy || uploads.isNotEmpty;
    final ready = form != null && !locked;

    return PopScope(
      canPop: leaving || (!dirty && !blocked),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: blocked ? null : leave,
            child: Text(dirty ? 'Bekor' : 'Yopish'),
          ),
          middle: Text(
            current == null ? 'Ma’lumot yig‘ish' : 'Javobni tahrirlash',
          ),
          trailing: ready
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: blocked ? null : save,
                  child: const Text('Saqlash'),
                )
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: loading
              ? const Loading()
              : form == null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: ErrorBox(error ?? 'Anketa mavjud emas', retry: load),
                )
              : locked
              ? const Center(
                  child: EmptyView(
                    icon: CupertinoIcons.lock,
                    title: 'Javobni tahrirlab bo‘lmaydi',
                    description: 'Faqat faol loyihadagi, tekshiruv kutilayotgan javobni o‘zgartirish mumkin.',
                  ),
                )
              : Column(
                  children: [
                    _ProgressHeader(answered: answered, total: fields.length),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            Readable(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  20,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      form!['name'] ?? '',
                                      style: title(context, size: 26),
                                    ),
                                    if ((form!['description'] ??
                                            widget.project['name']) !=
                                        form!['name']) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        form!['description'] ??
                                            widget.project['name'],
                                        style: secondary(context, size: 16),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            for (final q in questions)
                              Readable(
                                child: QuestionField(
                                  key: keys.putIfAbsent(
                                    '${q['id']}',
                                    () => GlobalKey(debugLabel: 'q${q['id']}'),
                                  ),
                                  question: q,
                                  value: answers['${q['id']}'],
                                  error: errors['${q['id']}'],
                                  api: widget.api,
                                  project: projectId,
                                  disabled: busy,
                                  onChanged: (v) => change('${q['id']}', v),
                                  onUploading: (v) {
                                    if (mounted) {
                                      setState(() {
                                        v
                                            ? uploads.add('${q['id']}')
                                            : uploads.remove('${q['id']}');
                                      });
                                    }
                                  },
                                ),
                              ),
                            Readable(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  0,
                                ),
                                child: Text(
                                  'Qoralama faqat shu qurilmada saqlanadi. Yuborish uchun internet kerak.',
                                  textAlign: TextAlign.center,
                                  style: secondary(context, size: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _SubmitBar(
                      error: error,
                      busy: busy,
                      uploading: uploads.isNotEmpty,
                      editing: current != null,
                      onSubmit: blocked ? null : submit,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Form progress: fills as answers are given, turns green when complete.
class _ProgressHeader extends StatelessWidget {
  final int answered, total;
  const _ProgressHeader({required this.answered, required this.total});
  @override
  Widget build(BuildContext context) {
    final v = total == 0 ? 1.0 : answered / total;
    return Semantics(
      label: 'Javob berildi: $answered / $total',
      excludeSemantics: true,
      child: Container(
        color: dyn(context, CupertinoColors.systemGroupedBackground),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Readable(
          child: Row(
            children: [
              Expanded(child: ProgressLine(progress: v)),
              const SizedBox(width: 12),
              Text(
                '$answered / $total',
                style: secondary(context, size: 13).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final Object? error;
  final bool busy, uploading, editing;
  final VoidCallback? onSubmit;
  const _SubmitBar({
    required this.error,
    required this.busy,
    required this.uploading,
    required this.editing,
    required this.onSubmit,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: dyn(context, CupertinoTheme.of(context).barBackgroundColor),
      border: Border(
        top: BorderSide(
          color: dyn(context, CupertinoColors.separator),
          width: .5,
        ),
      ),
    ),
    padding: EdgeInsets.fromLTRB(
      16,
      10,
      16,
      10 + MediaQuery.paddingOf(context).bottom,
    ),
    child: Readable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ErrorBox(error!),
          PrimaryButton(
            busy: busy,
            icon: uploading
                ? CupertinoIcons.cloud_upload
                : CupertinoIcons.paperplane_fill,
            label: uploading
                ? 'Fayl yuklanmoqda…'
                : editing
                ? 'O‘zgarishlarni saqlash'
                : 'Javobni yuborish',
            onPressed: onSubmit,
          ),
        ],
      ),
    ),
  );
}
