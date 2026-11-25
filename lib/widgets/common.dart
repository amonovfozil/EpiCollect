import 'dart:async';
import 'dart:ui';

import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/api.dart';
import 'brand.dart';

Color dyn(BuildContext context, Color c) =>
    CupertinoDynamicColor.resolve(c, context);

TextStyle body(BuildContext context) =>
    CupertinoTheme.of(context).textTheme.textStyle;

TextStyle secondary(BuildContext context, {double size = 15}) => body(
  context,
).copyWith(fontSize: size, color: dyn(context, CupertinoColors.secondaryLabel));

TextStyle title(BuildContext context, {double size = 22}) => body(context)
    .copyWith(fontSize: size, fontWeight: FontWeight.w700, letterSpacing: -.4);

/// Keeps content at a readable width on tablets.
class Readable extends StatelessWidget {
  final Widget child;
  const Readable({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class SliverReadable extends StatelessWidget {
  final Widget sliver;
  const SliverReadable({super.key, required this.sliver});
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, c) {
      final pad = max0((c.crossAxisExtent - 720) / 2);
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        sliver: sliver,
      );
    },
  );
}

double max0(double v) => v < 0 ? 0 : v;

class Brand extends StatelessWidget {
  final double size;
  const Brand({super.key, this.size = 22});
  @override
  Widget build(BuildContext context) => Text(
    'EpiCollect',
    style: title(context, size: size).copyWith(letterSpacing: -.8),
  );
}

class ErrorBox extends StatelessWidget {
  final Object error;
  final VoidCallback? retry;
  const ErrorBox(this.error, {super.key, this.retry});
  @override
  Widget build(BuildContext context) {
    final red = dyn(context, CupertinoColors.systemRed);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: red.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: red,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error.toString(),
                style: body(context).copyWith(fontSize: 15, color: red),
              ),
            ),
            if (retry != null)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(44, 44),
                onPressed: retry,
                child: const Text('Qayta', style: TextStyle(fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Widget? action;
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 44,
          color: dyn(context, CupertinoColors.tertiaryLabel),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: body(context)
              .copyWith(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          style: secondary(context),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class Status {
  final String label;
  final IconData icon;
  final Color color;
  const Status(this.label, this.icon, this.color);
  static Status of(String? s) => switch (s) {
    'approved' => const Status(
      'Tasdiqlangan',
      CupertinoIcons.checkmark_seal_fill,
      Palette.approved,
    ),
    'cancelled' => const Status(
      'Rad etilgan',
      CupertinoIcons.xmark_octagon_fill,
      Palette.rejected,
    ),
    'active' => const Status(
      'Faol',
      CupertinoIcons.circle_fill,
      Palette.approved,
    ),
    'archived' => const Status(
      'Arxivlangan',
      CupertinoIcons.archivebox_fill,
      CupertinoColors.systemGrey,
    ),
    _ => const Status('Kutilmoqda', CupertinoIcons.clock_fill, Palette.pending),
  };
}

class StatusBadge extends StatelessWidget {
  final String? status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = Status.of(status), c = dyn(context, s.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 13, color: c),
          const SizedBox(width: 5),
          Text(
            s.label,
            style: body(context)
                .copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}

/// iOS Settings-style rounded icon tile.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconTile(this.icon, this.color, {super.key, this.size = 30});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: dyn(context, color),
      borderRadius: BorderRadius.circular(size * .26),
    ),
    child: Icon(icon, color: CupertinoColors.white, size: size * .6),
  );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(child: CupertinoActivityIndicator(radius: 13)),
  );
}

class AsyncPanel extends StatelessWidget {
  final Future<Json> future;
  final Widget Function(Json) builder;
  final VoidCallback retry;
  const AsyncPanel({
    super.key,
    required this.future,
    required this.builder,
    required this.retry,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (c, s) {
      if (s.hasError) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBox(s.error!, retry: retry),
        );
      }
      if (!s.hasData) return const Loading();
      return builder(s.data!);
    },
  );
}

/// Full-width primary action with loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CupertinoButton.filled(
      borderRadius: BorderRadius.circular(14),
      minimumSize: const Size(44, 52),
      onPressed: busy ? null : onPressed,
      child: busy
          ? CupertinoActivityIndicator(color: dyn(context, Palette.onTint))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool destructive = false,
}) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Bekor qilish'),
          ),
          CupertinoDialogAction(
            isDefaultAction: !destructive,
            isDestructiveAction: destructive,
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ==
    true;

String roleName(dynamic role) =>
    {
      'collector': 'Ma’lumot yig‘uvchi',
      'admin': 'Administrator',
      'owner': 'Loyiha egasi',
      'viewer': 'Kuzatuvchi',
    }[role] ??
    '$role';

const _months = [
  'yan',
  'fev',
  'mar',
  'apr',
  'may',
  'iyn',
  'iyl',
  'avg',
  'sen',
  'okt',
  'noy',
  'dek',
];

String dateText(dynamic value, {bool time = false}) {
  final d = DateTime.tryParse('$value')?.toLocal();
  if (d == null) return '—';
  final s = '${d.day} ${_months[d.month - 1]} ${d.year}';
  return time
      ? '$s, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
      : s;
}

OverlayEntry? _toast;
Timer? _toastTimer;

/// Small floating confirmation. Cupertino has no snackbar, so this mirrors the
/// system HUD: a blurred pill that fades away on its own.
void toast(BuildContext context, String text, {bool error = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _toastTimer?.cancel();
  _toast?.remove();
  final entry = OverlayEntry(
    builder: (c) => Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.paddingOf(c).bottom + 72,
      child: IgnorePointer(
        child: Center(
          child: Semantics(
            liveRegion: true,
            child: _ToastPill(text: text, error: error),
          ),
        ),
      ),
    ),
  );
  _toast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(const Duration(milliseconds: 2600), () {
    if (_toast == entry) {
      entry.remove();
      _toast = null;
    }
  });
}

class _ToastPill extends StatelessWidget {
  final String text;
  final bool error;
  const _ToastPill({required this.text, required this.error});
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (c, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - v)),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            color: dyn(
              context,
              CupertinoColors.secondarySystemBackground,
            ).withValues(alpha: .86),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  error
                      ? CupertinoIcons.exclamationmark_circle_fill
                      : CupertinoIcons.checkmark_circle_fill,
                  size: 20,
                  color: dyn(
                    context,
                    error ? Palette.rejected : Palette.approved,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: body(context)
                        .copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
