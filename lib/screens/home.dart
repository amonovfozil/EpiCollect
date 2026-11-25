import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/api.dart';
import '../core/drafts.dart';
import '../main.dart' show Appearance;
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'collect.dart';
import 'project.dart';

class HomeScreen extends StatefulWidget {
  final Api api;
  final Appearance appearance;
  final ValueChanged<Appearance> onAppearance;
  const HomeScreen({
    super.key,
    required this.api,
    required this.appearance,
    required this.onAppearance,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final tabs = CupertinoTabController();
  final draftsKey = GlobalKey<_DraftsTabState>();

  @override
  void initState() {
    super.initState();
    tabs.addListener(() {
      if (tabs.index == 1) draftsKey.currentState?.reload();
    });
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoTabScaffold(
    controller: tabs,
    tabBar: CupertinoTabBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.square_stack_3d_up),
          activeIcon: Icon(CupertinoIcons.square_stack_3d_up_fill),
          label: 'Loyihalar',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.doc_text),
          activeIcon: Icon(CupertinoIcons.doc_text_fill),
          label: 'Qoralamalar',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.person_crop_circle),
          activeIcon: Icon(CupertinoIcons.person_crop_circle_fill),
          label: 'Profil',
        ),
      ],
    ),
    tabBuilder: (context, i) => CupertinoTabView(
      builder: (_) => switch (i) {
        0 => ProjectsTab(api: widget.api),
        1 => DraftsTab(key: draftsKey, api: widget.api),
        _ => ProfileTab(
          api: widget.api,
          appearance: widget.appearance,
          onAppearance: widget.onAppearance,
        ),
      },
    ),
  );
}

// ───────────────────────────── Projects ─────────────────────────────

class ProjectsTab extends StatefulWidget {
  final Api api;
  const ProjectsTab({super.key, required this.api});
  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  final items = <Json>[];
  int page = 0, lastPage = 1, total = 0;
  bool loading = false;
  Object? error;
  String search = '';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() => fetch(reset: true);

  Future<void> fetch({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = reset ? 1 : page + 1;
      final data = await widget.api.get('/projects?page=$next');
      if (!mounted) return;
      setState(() {
        if (reset) items.clear();
        items.addAll(List<Json>.from(data['data'] ?? []));
        page = next;
        lastPage = data['meta']?['last_page'] ?? 1;
        total = data['meta']?['total'] ?? items.length;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openProject(Json p) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ProjectScreen(api: widget.api, project: p),
      ),
    );
    if (mounted) refresh();
  }

  Future<void> join() async {
    final value = await Navigator.of(context, rootNavigator: true).push<String>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const JoinScreen(),
      ),
    );
    if (value == null) return;
    try {
      await widget.api.request('POST', '/projects/$value/invitations/accept');
      if (mounted) {
        toast(context, 'Taklif qabul qilindi');
        refresh();
      }
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.api.user?['full_name']?.toString().split(' ').first ?? '';
    final shown = items
        .where(
          (p) => '${p['name']} ${p['description'] ?? ''}'
              .toLowerCase()
              .contains(search),
        )
        .toList();
    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Loyihalar'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: join,
              child: const Icon(
                CupertinoIcons.plus_circle,
                semanticLabel: 'Loyihaga qo‘shilish',
              ),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: refresh),
          SliverReadable(
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salom, $name. Bugun qaysi anketadan boshlaymiz?',
                      style: secondary(context, size: 16),
                    ),
                    const SizedBox(height: 14),
                    CupertinoSearchTextField(
                      placeholder: 'Loyiha qidirish',
                      onChanged: (v) =>
                          setState(() => search = v.trim().toLowerCase()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (error != null && items.isEmpty)
            SliverToBoxAdapter(
              child: Readable(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorBox(error!, retry: refresh),
                ),
              ),
            )
          else if (loading && items.isEmpty)
            const SliverToBoxAdapter(child: Loading())
          else if (shown.isEmpty)
            SliverToBoxAdapter(
              child: search.isNotEmpty
                  ? const EmptyView(
                      icon: CupertinoIcons.search,
                      title: 'Hech narsa topilmadi',
                      description: 'Boshqa so‘z bilan qidirib ko‘ring.',
                    )
                  : EmptyView(
                      icon: CupertinoIcons.square_stack_3d_up,
                      title: 'Hozircha loyiha yo‘q',
                      description: 'Jamoangiz yuborgan taklifni qabul qiling: sizga loyiha ID raqami kerak bo‘ladi.',
                      action: CupertinoButton.tinted(
                        onPressed: join,
                        child: const Text('Loyihaga qo‘shilish'),
                      ),
                    ),
            )
          else ...[
            SliverReadable(
              sliver: SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => ProjectTile(
                    project: shown[i],
                    onTap: () => openProject(shown[i]),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Readable(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  child: Column(
                    children: [
                      if (error != null) ErrorBox(error!, retry: fetch),
                      if (page < lastPage)
                        loading
                            ? const CupertinoActivityIndicator()
                            : CupertinoButton(
                                onPressed: fetch,
                                child: const Text('Yana yuklash'),
                              ),
                      Text(
                        '$total ta loyiha',
                        style: secondary(context, size: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProjectTile extends StatelessWidget {
  final Json project;
  final VoidCallback onTap;
  const ProjectTile({super.key, required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = project;
    return Semantics(
      button: true,
      label: '${p['name']}, ${Status.of(p['status']).label}',
      child: _Pressable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: dyn(
              context,
              CupertinoColors.secondarySystemGroupedBackground,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(tag: 'mark-${p['id']}', child: ProjectMark(p, size: 56)),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: title(context, size: 19),
                          ),
                          if (p['description'] != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              p['description'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: secondary(context),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
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
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 18,
                      color: dyn(context, CupertinoColors.tertiaryLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims slightly on press, like iOS table cells.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => down = true),
    onTapCancel: () => setState(() => down = false),
    onTapUp: (_) => setState(() => down = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: down ? .98 : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedOpacity(
        opacity: down ? .8 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    ),
  );
}

// ───────────────────────────── Drafts ─────────────────────────────

class DraftsTab extends StatefulWidget {
  final Api api;
  const DraftsTab({super.key, required this.api});
  @override
  State<DraftsTab> createState() => _DraftsTabState();
}

class _DraftsTabState extends State<DraftsTab> {
  late Future<List<Json>> drafts;
  Drafts get store => Drafts('${widget.api.user!['id']}');

  @override
  void initState() {
    super.initState();
    drafts = store.all();
  }

  void reload() {
    if (mounted) {
      setState(() {
        drafts = store.all();
      });
    }
  }

  Future<void> open(Json d) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) =>
            CollectScreen(api: widget.api, project: Json.from(d['project'])),
      ),
    );
    reload();
  }

  Future<void> remove(Json d) async {
    final yes = await confirm(
      context,
      title: 'Qoralamani o‘chirasizmi?',
      message: 'Bu qurilmadagi yuborilmagan javoblar butunlay o‘chadi.',
      action: 'O‘chirish',
      destructive: true,
    );
    if (!yes) return;
    await store.remove(d['project']['id']);
    reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: CustomScrollView(
      slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Qoralamalar')),
        SliverReadable(
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<List<Json>>(
              future: drafts,
              builder: (c, s) {
                if (s.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorBox(s.error!, retry: reload),
                  );
                }
                if (!s.hasData) return const Loading();
                if (s.data!.isEmpty) {
                  return const EmptyView(
                    icon: CupertinoIcons.doc_text,
                    title: 'Qoralamalar yo‘q',
                    description: 'Anketani to‘ldirayotganda “Saqlash”ni bosing. Javoblar shu qurilmada qoladi va shu yerdan davom ettirasiz.',
                  );
                }
                return CupertinoListSection.insetGrouped(
                  header: const Text('Shu qurilmada saqlangan'),
                  footer: Text(
                    'Qoralama yuborilmaguncha serverda ko‘rinmaydi. O‘chirish uchun chapga suring.',
                    style: secondary(context, size: 13),
                  ),
                  children: [
                    for (final d in s.data!)
                      Dismissible(
                        key: ValueKey('draft-${d['project']['id']}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await remove(d);
                          return false;
                        },
                        background: Container(
                          color: dyn(context, CupertinoColors.systemRed),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            CupertinoIcons.trash,
                            color: CupertinoColors.white,
                          ),
                        ),
                        child: CupertinoListTile(
                          padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
                          leadingSize: 40,
                          leading: ProjectMark(
                            Json.from(d['project']),
                            size: 40,
                          ),
                          title: Text(d['project']['name'] ?? ''),
                          subtitle: Text(
                            '${(d['answers'] as Map?)?.length ?? 0} ta javob · ${dateText(d['updated_at'], time: true)}',
                          ),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => open(d),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────────── Profile ─────────────────────────────

class ProfileTab extends StatelessWidget {
  final Api api;
  final Appearance appearance;
  final ValueChanged<Appearance> onAppearance;
  const ProfileTab({
    super.key,
    required this.api,
    required this.appearance,
    required this.onAppearance,
  });

  Future<void> logout(BuildContext context) async {
    final yes = await confirm(
      context,
      title: 'Hisobdan chiqasizmi?',
      message: 'Qoralamalaringiz shu qurilmada saqlanib qoladi.',
      action: 'Chiqish',
      destructive: true,
    );
    if (!yes) return;
    try {
      await api.logout();
    } catch (_) {
      // Local session is cleared in `finally` even when the server call fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = api.user ?? {};
    final name = '${u['full_name'] ?? ''}'.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Profil')),
          SliverReadable(
            sliver: SliverList.list(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dyn(context, Palette.tint),
                    ),
                    child: Text(
                      initials.isEmpty ? 'E' : initials,
                      style: TextStyle(
                        color: dyn(context, CupertinoColors.systemBackground),
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, textAlign: TextAlign.center, style: title(context)),
                const SizedBox(height: 2),
                Text(
                  '${u['email'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: secondary(context),
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('Ko‘rinish'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<Appearance>(
                          groupValue: appearance,
                          onValueChanged: (v) {
                            if (v != null) onAppearance(v);
                          },
                          children: const {
                            Appearance.system: _Seg(
                              CupertinoIcons.device_phone_portrait,
                              'Tizim',
                            ),
                            Appearance.light: _Seg(
                              CupertinoIcons.sun_max,
                              'Yorug‘',
                            ),
                            Appearance.dark: _Seg(CupertinoIcons.moon, 'Tungi'),
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('Ilova'),
                  children: const [
                    CupertinoListTile(
                      leading: IconTile(
                        CupertinoIcons.globe,
                        CupertinoColors.systemBlue,
                      ),
                      title: Text('Til'),
                      additionalInfo: Text('O‘zbekcha'),
                    ),
                    CupertinoListTile(
                      leading: IconTile(CupertinoIcons.cloud, Palette.tint),
                      title: Text('Server'),
                      additionalInfo: Text('datacollect.uz'),
                    ),
                    CupertinoListTile(
                      leading: IconTile(
                        CupertinoIcons.info,
                        CupertinoColors.systemGrey,
                      ),
                      title: Text('Versiya'),
                      additionalInfo: Text('1.0.0'),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  children: [
                    CupertinoListTile(
                      leading: const IconTile(
                        CupertinoIcons.square_arrow_left,
                        CupertinoColors.systemRed,
                      ),
                      title: Text(
                        'Hisobdan chiqish',
                        style: TextStyle(
                          color: dyn(context, CupertinoColors.systemRed),
                        ),
                      ),
                      onTap: () => logout(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Seg(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

// ───────────────────────────── Join ─────────────────────────────

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final input = TextEditingController();
  String? error;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void submit() {
    final v = input.text.trim();
    if (int.tryParse(v) == null) {
      setState(() => error = 'Loyiha ID raqamini kiriting, masalan 12');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context),
        child: const Text('Bekor'),
      ),
      middle: const Text('Loyihaga qo‘shilish'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: submit,
        child: const Text(
          'Qo‘shilish',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    child: SafeArea(
      child: Readable(
        child: ListView(
          children: [
            CupertinoFormSection.insetGrouped(
              header: const Text('TAKLIF'),
              footer: Text(
                error ?? 'Taklifdagi loyiha ID raqamini kiriting. Hisobingiz pochtasi taklif yuborilgan manzilga mos bo‘lishi kerak.',
                style: error == null
                    ? null
                    : TextStyle(color: dyn(context, CupertinoColors.systemRed)),
              ),
              children: [
                CupertinoTextFormFieldRow(
                  controller: input,
                  autofocus: true,
                  prefix: const Text('Loyiha ID'),
                  placeholder: 'Masalan, 12',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => submit(),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
