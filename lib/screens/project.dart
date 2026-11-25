import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/drafts.dart';
import '../core/forms.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'collect.dart';

const _filters = {
  '': 'Barchasi',
  'pending': 'Kutilmoqda',
  'approved': 'Tasdiqlangan',
  'cancelled': 'Rad etilgan',
};

class ProjectScreen extends StatefulWidget {
  final Api api;
  final Json project;
  const ProjectScreen({super.key, required this.api, required this.project});
  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  Json? form, mine;
  bool hasDraft = false, loading = true, more = false;
  Object? error;
  final subs = <Json>[];
  int page = 1, lastPage = 1;
  String status = '';

  Json get p => widget.project;
  String get path => '/projects/${p['id']}';
  bool get collector => p['role'] == 'collector';
  bool get active => p['status'] == 'active' && p['role'] != 'viewer';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  String subsPath(int page) =>
      '$path/${collector ? 'my-submissions' : 'submissions'}?page=$page${status.isEmpty ? '' : '&status=$status'}';

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Future.wait([
        widget.api.get('$path/form').catchError((e) {
          if (e is ApiException && e.status == 404) return <String, dynamic>{};
          throw e;
        }),
        widget.api.get(subsPath(1)),
        if (collector) widget.api.get('$path/my-submission'),
      ]);
      final draft = await Drafts('${widget.api.user?['id']}').read(p['id']);
      if (!mounted) return;
      setState(() {
        form = r[0]['data'];
        subs
          ..clear()
          ..addAll(List<Json>.from(r[1]['data'] ?? []));
        page = 1;
        lastPage = r[1]['meta']?['last_page'] ?? 1;
        mine = collector ? r[2]['data'] : null;
        hasDraft = draft != null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadMore() async {
    setState(() => more = true);
    try {
      final d = await widget.api.get(subsPath(page + 1));
      if (!mounted) return;
      setState(() {
        subs.addAll(List<Json>.from(d['data'] ?? []));
        page++;
        lastPage = d['meta']?['last_page'] ?? lastPage;
      });
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => more = false);
    }
  }

  Future<void> collect() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => CollectScreen(api: widget.api, project: p),
      ),
    );
    if (mounted) refresh();
  }

  Future<void> openSubmission(Json s) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            SubmissionScreen(api: widget.api, project: p, id: s['id']),
      ),
    );
    if (mounted) refresh();
  }

  ({String label, IconData icon, bool enabled}) get action {
    if (!active) {
      return (
        label: 'Yig‘ish faol emas',
        icon: CupertinoIcons.lock,
        enabled: false,
      );
    }
    if (hasDraft) {
      return (
        label: 'Qoralamani davom ettirish',
        icon: CupertinoIcons.pencil_ellipsis_rectangle,
        enabled: true,
      );
    }
    if (mine == null) {
      return (
        label: 'Anketani to‘ldirish',
        icon: CupertinoIcons.square_pencil,
        enabled: true,
      );
    }
    final editable =
        mine!['status'] == 'pending' &&
        mine!['is_editable'] != false &&
        mine!['is_deleted'] != true;
    return editable
        ? (
            label: 'Javobni tahrirlash',
            icon: CupertinoIcons.pencil,
            enabled: true,
          )
        : (
            label: 'Javob yuborilgan',
            icon: CupertinoIcons.checkmark_alt,
            enabled: false,
          );
  }

  @override
  Widget build(BuildContext context) {
    final questions =
        (form?['questions'] as List?)
            ?.where((q) => !containers.contains(q['type']))
            .length ??
        0;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Loyihalar',
        middle: Text(p['name'] ?? 'Loyiha', overflow: TextOverflow.ellipsis),
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: refresh),
          SliverReadable(
            sliver: SliverSafeArea(
              sliver: SliverList.list(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ProjectCover(p),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '', style: title(context, size: 28)),
                        if (p['description'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            p['description'],
                            style: secondary(context, size: 17),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusBadge(p['status']),
                            Text(
                              roleName(p['role']),
                              style: secondary(context, size: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (loading && form == null && error == null)
                    const Loading()
                  else if (error != null && form == null && subs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorBox(error!, retry: refresh),
                    )
                  else ...[
                    formSection(questions),
                    submissionsSection(),
                    if (['admin', 'owner'].contains(p['role']))
                      CupertinoListSection.insetGrouped(
                        children: [
                          CupertinoListTile(
                            leading: const IconTile(
                              CupertinoIcons.globe,
                              CupertinoColors.systemBlue,
                            ),
                            title: const Text('Webda boshqarish'),
                            trailing: const Icon(
                              CupertinoIcons.arrow_up_right,
                              size: 18,
                            ),
                            onTap: () => launchUrl(
                              Uri.parse(
                                'https://datacollect.uz/#/projects/${p['id']}',
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget formSection(int questions) {
    if (form == null) {
      return const EmptyView(
        icon: CupertinoIcons.doc_on_clipboard,
        title: 'Anketa hali tayyor emas',
        description: 'Administrator anketa yaratgach, shu yerdan ma’lumot yig‘ishni boshlaysiz.',
      );
    }
    final a = action;
    return CupertinoListSection.insetGrouped(
      header: const Text('Anketa'),
      footer: hasDraft
          ? Text(
              'Bu qurilmada saqlangan qoralama bor.',
              style: secondary(context, size: 13),
            )
          : null,
      children: [
        CupertinoListTile(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          leading: const IconTile(CupertinoIcons.doc_text_fill, Palette.tint),
          title: Text(form!['name'] ?? 'Anketa'),
          subtitle: Text(
            [
              '$questions ta savol',
              if (form!['description'] != null) form!['description'],
            ].join(' · '),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: PrimaryButton(
            label: a.label,
            icon: a.icon,
            onPressed: a.enabled ? collect : null,
          ),
        ),
      ],
    );
  }

  Widget submissionsSection() => CupertinoListSection.insetGrouped(
    header: Text(collector ? 'Mening javoblarim' : 'Loyiha javoblari'),
    children: [
      Padding(
        padding: const EdgeInsets.all(10),
        child: CupertinoSlidingSegmentedControl<String>(
          groupValue: status,
          onValueChanged: (v) {
            if (v == null) return;
            status = v;
            refresh();
          },
          children: {
            for (final e in _filters.entries)
              e.key: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)),
                ),
              ),
          },
        ),
      ),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(20),
          child: CupertinoActivityIndicator(),
        )
      else if (subs.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          child: Text(
            status.isEmpty
                ? 'Hali javob yuborilmagan. Yuborilgan javoblar va tekshiruv holati shu yerda ko‘rinadi.'
                : '“${_filters[status]}” holatidagi javob yo‘q.',
            textAlign: TextAlign.center,
            style: secondary(context),
          ),
        )
      else
        for (final s in subs)
          CupertinoListTile(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
            leading: IconTile(
              Status.of(s['status']).icon,
              Status.of(s['status']).color,
            ),
            title: Text('Javob №${s['id']}'),
            subtitle: Text(
              '${Status.of(s['status']).label} · ${dateText(s['submitted_at'] ?? s['created_at'], time: true)}',
            ),
            trailing: const CupertinoListTileChevron(),
            onTap: () => openSubmission(s),
          ),
      if (page < lastPage && !loading)
        CupertinoListTile(
          title: Center(
            child: more
                ? const CupertinoActivityIndicator()
                : Text(
                    'Yana yuklash',
                    style: TextStyle(color: dyn(context, Palette.tint)),
                  ),
          ),
          onTap: more ? null : loadMore,
        ),
    ],
  );
}

// ───────────────────────────── Submission ─────────────────────────────

class SubmissionScreen extends StatefulWidget {
  final Api api;
  final Json project;
  final int id;
  const SubmissionScreen({
    super.key,
    required this.api,
    required this.project,
    required this.id,
  });
  @override
  State<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends State<SubmissionScreen> {
  late Future<Json> result;

  @override
  void initState() {
    super.initState();
    result = load();
  }

  Future<Json> load() => widget.api.get(
    '/projects/${widget.project['id']}/submissions/${widget.id}',
  );
  void refresh() => setState(() {
    result = load();
  });

  Future<void> edit() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => CollectScreen(api: widget.api, project: widget.project),
      ),
    );
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      previousPageTitle: 'Orqaga',
      middle: Text('Javob №${widget.id}'),
    ),
    child: SafeArea(
      child: Readable(
        child: SingleChildScrollView(
          child: AsyncPanel(
            future: result,
            retry: refresh,
            builder: (d) {
              final s = d['data'] as Json;
              final st = Status.of(s['status']);
              final editable =
                  s['status'] == 'pending' &&
                  s['is_editable'] != false &&
                  s['is_deleted'] != true &&
                  widget.project['role'] == 'collector' &&
                  widget.project['status'] == 'active';
              final answers = List<Json>.from(s['answers'] ?? []);
              final files = List<Json>.from(s['attachments'] ?? []);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        IconTile(st.icon, st.color, size: 48),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(st.label, style: title(context, size: 22)),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.project['name']} · ${dateText(s['submitted_at'] ?? s['created_at'], time: true)}',
                                style: secondary(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s['review_comment'] != null)
                    CupertinoListSection.insetGrouped(
                      header: const Text('Tekshiruvchi izohi'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '${s['review_comment']}',
                            style: body(context),
                          ),
                        ),
                      ],
                    ),
                  CupertinoListSection.insetGrouped(
                    header: const Text('Javoblar'),
                    children: answers.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Javoblar yo‘q',
                                style: secondary(context),
                              ),
                            ),
                          ]
                        : [
                            for (final a in answers)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      questionLabel(a),
                                      style: secondary(context, size: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      answerText(a),
                                      style: body(context)
                                          .copyWith(fontSize: 17),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                  ),
                  if (files.isNotEmpty)
                    CupertinoListSection.insetGrouped(
                      header: const Text('Fayllar'),
                      children: [
                        for (final a in files)
                          CupertinoListTile(
                            leading: const IconTile(
                              CupertinoIcons.paperclip,
                              CupertinoColors.systemGrey,
                            ),
                            title: Text(a['original_name'] ?? 'Fayl'),
                            trailing: a['url'] == null
                                ? null
                                : const Icon(
                                    CupertinoIcons.arrow_up_right,
                                    size: 18,
                                  ),
                            onTap: a['url'] == null
                                ? null
                                : () async {
                                    final uri = Uri.tryParse(a['url']);
                                    if (uri != null && uri.scheme == 'https') {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                          ),
                      ],
                    ),
                  if (editable)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: PrimaryButton(
                        label: 'Javobni tahrirlash',
                        icon: CupertinoIcons.pencil,
                        onPressed: edit,
                      ),
                    )
                  else
                    const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
