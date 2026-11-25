import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/api.dart';

/// App colours. One interactive tint; status colours always travel with an
/// icon and a label, never alone.
abstract final class Palette {
  static const tint = CupertinoDynamicColor.withBrightness(
    color: Color(0xff2b3ba3),
    darkColor: Color(0xff9aa6ff),
  );

  /// Text and icons on a tint-filled surface (white / deep indigo).
  static const onTint = CupertinoDynamicColor.withBrightness(
    color: Color(0xffffffff),
    darkColor: Color(0xff10175a),
  );
  static const pending = CupertinoDynamicColor.withBrightness(
    color: Color(0xffb7790b),
    darkColor: Color(0xfff2be4a),
  );
  static const approved = CupertinoDynamicColor.withBrightness(
    color: Color(0xff137149),
    darkColor: Color(0xff4cc795),
  );
  static const rejected = CupertinoDynamicColor.withBrightness(
    color: Color(0xffb3293b),
    darkColor: Color(0xffff6b78),
  );

  /// Calm, deep tones for project marks: like list colours in Reminders.
  static const marks = [
    Color(0xff2b3ba3), // indigo
    Color(0xff0f7b6c), // teal
    Color(0xff3f7d20), // field green
    Color(0xffb4591a), // clay
    Color(0xff7a3f9d), // plum
    Color(0xff1f6fb2), // river blue
  ];
}

/// Icon and colour that identify a project everywhere in the app. The icon is
/// chosen from the project's own words; unknown topics fall back to a stable
/// pick from the project id.
class ProjectLook {
  final IconData icon;
  final Color color;
  const ProjectLook(this.icon, this.color);

  static const _topics = <(List<String>, IconData)>[
    (
      ['survey', 'so‘rov', "so'rov", 'anketa', 'census', 'ro‘yxat'],
      CupertinoIcons.square_list_fill,
    ),
    (['observ', 'kuzat', 'monitor'], CupertinoIcons.eye_fill),
    (
      ['field', 'dala', 'map', 'xarita', 'hudud', 'region'],
      CupertinoIcons.map_fill,
    ),
    (
      ['health', 'sog‘liq', 'tibbi', 'clinic', 'kasal', 'medic', 'epid'],
      CupertinoIcons.heart_fill,
    ),
    (['water', 'suv', 'drop'], CupertinoIcons.drop_fill),
    (
      ['school', 'maktab', 'ta’lim', 'educat', 'book'],
      CupertinoIcons.book_fill,
    ),
    (
      ['house', 'uy', 'household', 'xonadon', 'oila', 'family'],
      CupertinoIcons.house_fill,
    ),
    (
      ['community', 'mahalla', 'aholi', 'people', 'jamoa'],
      CupertinoIcons.person_3_fill,
    ),
    (
      ['agri', 'qishloq', 'crop', 'ekin', 'forest', 'o‘rmon', 'tree'],
      CupertinoIcons.tree,
    ),
    (['animal', 'hayvon', 'chorva', 'vet'], CupertinoIcons.paw),
    (['lab', 'sample', 'namuna', 'test'], CupertinoIcons.lab_flask_solid),
    (['market', 'savdo', 'bozor', 'price', 'narx'], CupertinoIcons.cart_fill),
    (['transport', 'road', 'yo‘l'], CupertinoIcons.bus),
  ];

  static const _fallback = [
    CupertinoIcons.doc_on_clipboard_fill,
    CupertinoIcons.chart_bar_alt_fill,
    CupertinoIcons.doc_text_viewfinder,
    CupertinoIcons.globe,
  ];

  static ProjectLook of(Json p) {
    final id = (p['id'] as num?)?.toInt() ?? 0;
    final text = '${p['name'] ?? ''} ${p['description'] ?? ''}'.toLowerCase();
    // Community survey is a survey first; earlier topics win.
    final icon =
        _topics
            .where((t) => t.$1.any(text.contains))
            .map((t) => t.$2)
            .firstOrNull ??
        _fallback[id % _fallback.length];
    return ProjectLook(icon, Palette.marks[id % Palette.marks.length]);
  }
}

/// Rounded-square project mark, the same shape as an app icon.
class ProjectMark extends StatelessWidget {
  final Json project;
  final double size;
  const ProjectMark(this.project, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final look = ProjectLook.of(project);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: look.color,
          borderRadius: BorderRadius.circular(size * .27),
          boxShadow: [
            BoxShadow(
              color: look.color.withValues(alpha: .28),
              blurRadius: size * .22,
              offset: Offset(0, size * .08),
            ),
          ],
        ),
        child: Icon(look.icon, color: CupertinoColors.white, size: size * .52),
      ),
    );
  }
}

/// Header for the project screen: a soft wash of the project's colour with
/// its mark and a large cropped icon that gives the page its own character.
class ProjectCover extends StatelessWidget {
  final Json project;
  final double height;
  const ProjectCover(this.project, {super.key, this.height = 132});

  @override
  Widget build(BuildContext context) {
    final look = ProjectLook.of(project);
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: look.color.withValues(alpha: dark ? .28 : .12),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -height * .18,
              bottom: -height * .3,
              child: Icon(
                look.icon,
                size: height * 1.25,
                color: look.color.withValues(alpha: dark ? .35 : .14),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 20,
              child: Hero(
                tag: 'mark-${project['id']}',
                child: ProjectMark(project, size: 64),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin progress line for the form; animates forward as answers are given.
class ProgressLine extends StatelessWidget {
  final double progress;
  const ProgressLine({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final track = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemFill,
      context,
    );
    final done = progress >= 1;
    final fill = CupertinoDynamicColor.resolve(
      done ? Palette.approved : Palette.tint,
      context,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            TweenAnimationBuilder<double>(
              tween: Tween(end: progress.clamp(0, 1)),
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: ColoredBox(color: fill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// EpiCollect's own mark: a clipboard with a check, in the app tint.
class AppMark extends StatelessWidget {
  final double size;
  const AppMark({super.key, this.size = 76});
  @override
  Widget build(BuildContext context) {
    final tint = CupertinoDynamicColor.resolve(Palette.tint, context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(size * .27),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: .3),
              blurRadius: size * .25,
              offset: Offset(0, size * .1),
            ),
          ],
        ),
        child: Icon(
          CupertinoIcons.checkmark_seal_fill,
          size: size * .54,
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.systemBackground,
            context,
          ),
        ),
      ),
    );
  }
}
