import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/api.dart';
import 'brand.dart';
import 'common.dart';

const _textTypes = ['text', 'text_box', 'numeric', 'phone', 'barcode'];

class QuestionField extends StatefulWidget {
  final Json question;
  final dynamic value;
  final String? error;
  final Api api;
  final int project;
  final bool disabled;
  final ValueChanged<dynamic> onChanged;
  final ValueChanged<bool> onUploading;
  const QuestionField({
    super.key,
    required this.question,
    required this.value,
    this.error,
    required this.api,
    required this.project,
    required this.disabled,
    required this.onChanged,
    required this.onUploading,
  });
  @override
  State<QuestionField> createState() => _QuestionFieldState();
}

class _QuestionFieldState extends State<QuestionField> {
  late final TextEditingController text, lat, lon;
  bool working = false;
  Object? error;
  List<Json> members = [];
  Timer? debounce;
  int generation = 0;
  final names = <dynamic, String>{};

  Json get q => widget.question;
  String get type => q['type'];
  Json get settings => q['settings'] is Map ? Json.from(q['settings']) : {};
  List<Json> get options => List<Json>.from(q['options'] ?? []);
  bool get disabled => widget.disabled || working;
  Map get location => widget.value is Map ? widget.value as Map : const {};

  @override
  void initState() {
    super.initState();
    text = TextEditingController(
      text: _textTypes.contains(type) ? _s(widget.value) : '',
    );
    lat = TextEditingController(text: _s(location['latitude']));
    lon = TextEditingController(text: _s(location['longitude']));
  }

  String _s(dynamic v) => v == null ? '' : '$v';

  @override
  void didUpdateWidget(QuestionField old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    if (_textTypes.contains(type) &&
        type != 'numeric' &&
        text.text != _s(widget.value)) {
      text.text = _s(widget.value);
    }
    if (type == 'numeric' && num.tryParse(text.text) != widget.value) {
      text.text = _s(widget.value);
    }
    if (type == 'location') {
      for (final (c, k) in [(lat, 'latitude'), (lon, 'longitude')]) {
        if (num.tryParse(c.text) != location[k]) c.text = _s(location[k]);
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    text.dispose();
    lat.dispose();
    lon.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() fn, {bool upload = false}) async {
    setState(() {
      working = true;
      error = null;
    });
    if (upload) widget.onUploading(true);
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (upload) widget.onUploading(false);
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> locate() => action(() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw ApiException('Qurilma sozlamalarida joylashuv xizmatini yoqing.');
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      throw ApiException(
        'Joylashuvga ruxsat berilmadi. Koordinatalarni qo‘lda kiriting yoki sozlamalarda ruxsat bering.',
      );
    }
    final at = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (mounted) {
      widget.onChanged({'latitude': at.latitude, 'longitude': at.longitude});
    }
  });

  Future<void> uploadPath(String path) => action(() async {
    final existing = List<dynamic>.from(widget.value ?? []),
        maxFiles = num.tryParse('${settings['max_files'] ?? 1}') ?? 1;
    if (existing.length >= maxFiles) {
      throw ApiException('Ko‘pi bilan $maxFiles ta fayl biriktirish mumkin.');
    }
    final file = await widget.api.upload(widget.project, q['id'], path);
    names[file['id']] = file['original_name'] ?? 'Fayl';
    if (mounted) widget.onChanged([...existing, file['id']]);
  }, upload: true);

  Future<void> pick(bool camera) async {
    try {
      String? path;
      if (camera && type == 'photo') {
        path = (await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        ))?.path;
      } else if (camera && type == 'video') {
        path = (await ImagePicker().pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        ))?.path;
      } else if (camera && type == 'audio') {
        if (!mounted) return;
        path = await Navigator.of(context, rootNavigator: true).push<String>(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => const AudioScreen(),
          ),
        );
      } else {
        final files = await FilePicker.pickFiles(
          type: type == 'photo'
              ? FileType.image
              : type == 'video'
              ? FileType.video
              : FileType.audio,
        );
        path = files.isEmpty ? null : files.single.path;
      }
      if (path != null && mounted) await uploadPath(path);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> scan() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<String>(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => const ScannerScreen(),
          ),
        );
    if (result != null && mounted) {
      text.text = result;
      widget.onChanged(result);
    }
  }

  void search(String value) {
    final id = ++generation;
    debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => members = []);
      return;
    }
    debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final data = await widget.api.get(
          '/projects/${widget.project}/form/questions/${q['id']}/search?q=${Uri.encodeQueryComponent(value.trim())}',
        );
        if (mounted && generation == id) {
          setState(() {
            members = List<Json>.from(data['data']);
            error = null;
          });
        }
      } catch (e) {
        if (mounted && generation == id) setState(() => error = e);
      }
    });
  }

  Future<void> pickDate() async {
    final isDate = type == 'date';
    final now = DateTime.now();
    var picked = isDate
        ? DateTime.tryParse(_s(widget.value)) ?? now
        : _parseTime(_s(widget.value)) ?? now;
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (c) => _PickerSheet(
        title: isDate ? 'Sana' : 'Vaqt',
        child: CupertinoDatePicker(
          mode: isDate
              ? CupertinoDatePickerMode.date
              : CupertinoDatePickerMode.time,
          initialDateTime: picked,
          minimumYear: 1900,
          maximumYear: 2100,
          use24hFormat: true,
          onDateTimeChanged: (d) => picked = d,
        ),
      ),
    );
    if (ok != true || !mounted) return;
    String two(int v) => v.toString().padLeft(2, '0');
    widget.onChanged(
      isDate
          ? '${picked.year}-${two(picked.month)}-${two(picked.day)}'
          : '${two(picked.hour)}:${two(picked.minute)}${settings['format'] == 'H:i:s' ? ':00' : ''}',
    );
  }

  DateTime? _parseTime(String v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(v);
    if (m == null) return null;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, int.parse(m[1]!), int.parse(m[2]!));
  }

  Future<void> pickOption() async {
    var index = options.indexWhere((o) => o['value'] == widget.value);
    if (index < 0) index = 0;
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (c) => _PickerSheet(
        title: q['question'] ?? '',
        child: CupertinoPicker(
          itemExtent: 40,
          scrollController: FixedExtentScrollController(initialItem: index),
          onSelectedItemChanged: (i) => index = i,
          children: [
            for (final o in options)
              Center(
                child: Text('${o['label']}', overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
    if (ok == true && mounted && options.isNotEmpty) {
      widget.onChanged(options[index]['value']);
    }
  }

  // ───────────────────────── rows ─────────────────────────

  Widget field({
    TextEditingController? controller,
    String placeholder = 'Javobingiz',
    TextInputType? keyboard,
    Widget? prefix,
    Widget? suffix,
    int? minLines,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
  }) => CupertinoTextField(
    controller: controller,
    enabled: !disabled,
    placeholder: placeholder,
    keyboardType: keyboard,
    minLines: minLines,
    maxLines: maxLines,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: null,
    prefix: prefix,
    suffix: suffix,
    style: body(context).copyWith(fontSize: 17),
    onChanged: onChanged,
  );

  Widget choiceRow(
    Json o,
    bool selected, {
    required bool multi,
    required VoidCallback onTap,
  }) {
    final tint = dyn(context, Palette.tint);
    return CupertinoListTile(
      title: Text('${o['label']}'),
      leading: multi
          ? Icon(
              selected
                  ? CupertinoIcons.checkmark_square_fill
                  : CupertinoIcons.square,
              color: selected
                  ? tint
                  : dyn(context, CupertinoColors.tertiaryLabel),
            )
          : null,
      trailing: !multi && selected
          ? Icon(CupertinoIcons.checkmark_alt, color: tint)
          : null,
      onTap: disabled ? null : onTap,
    );
  }

  Widget actionRow(
    IconData icon,
    Color color,
    String label,
    VoidCallback? onTap, {
    String? info,
  }) => CupertinoListTile(
    leading: IconTile(icon, color, size: 28),
    title: Text(label, style: TextStyle(color: dyn(context, Palette.tint))),
    additionalInfo: info == null ? null : Text(info),
    onTap: disabled ? null : onTap,
  );

  List<Widget> editor() {
    switch (type) {
      case 'readme':
        return [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${settings['content'] ?? q['description'] ?? ''}',
              style: body(context).copyWith(fontSize: 16, height: 1.4),
            ),
          ),
        ];
      case 'radio' || 'dropdown' when type == 'radio' || options.length <= 6:
        if (options.isEmpty) {
          return [_note('Bu savol uchun variantlar kiritilmagan.')];
        }
        return [
          for (final o in options)
            choiceRow(
              o,
              o['value'] == widget.value,
              multi: false,
              onTap: () => widget.onChanged(o['value']),
            ),
        ];
      case 'dropdown':
        final selected = options
            .where((o) => o['value'] == widget.value)
            .firstOrNull;
        return [
          CupertinoListTile(
            title: Text(
              selected == null ? 'Variantni tanlang' : '${selected['label']}',
              style: selected == null
                  ? TextStyle(
                      color: dyn(context, CupertinoColors.placeholderText),
                    )
                  : null,
            ),
            trailing: const Icon(
              CupertinoIcons.chevron_up_chevron_down,
              size: 18,
            ),
            onTap: disabled ? null : pickOption,
          ),
        ];
      case 'checkbox':
        if (options.isEmpty) {
          return [_note('Bu savol uchun variantlar kiritilmagan.')];
        }
        final list = widget.value is List ? widget.value as List : const [];
        return [
          for (final o in options)
            choiceRow(
              o,
              list.contains(o['value']),
              multi: true,
              onTap: () {
                final next = List<dynamic>.from(list);
                next.contains(o['value'])
                    ? next.remove(o['value'])
                    : next.add(o['value']);
                widget.onChanged(next);
              },
            ),
        ];
      case 'date' || 'time':
        final v = _s(widget.value);
        return [
          CupertinoListTile(
            leading: Icon(
              type == 'date' ? CupertinoIcons.calendar : CupertinoIcons.clock,
              color: dyn(context, Palette.tint),
            ),
            title: Text(
              v.isEmpty
                  ? (type == 'date' ? 'Sanani tanlang' : 'Vaqtni tanlang')
                  : v,
              style: v.isEmpty
                  ? TextStyle(
                      color: dyn(context, CupertinoColors.placeholderText),
                    )
                  : const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
            ),
            trailing: v.isEmpty
                ? const CupertinoListTileChevron()
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: disabled ? null : () => widget.onChanged(null),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 20,
                      color: dyn(context, CupertinoColors.tertiaryLabel),
                    ),
                  ),
            onTap: disabled ? null : pickDate,
          ),
        ];
      case 'location':
        return [
          actionRow(
            CupertinoIcons.location_fill,
            CupertinoColors.systemGreen,
            'Joriy joylashuvni aniqlash',
            locate,
            info: working ? 'Aniqlanmoqda…' : null,
          ),
          for (final (c, k, label) in [
            (lat, 'latitude', 'Kenglik'),
            (lon, 'longitude', 'Uzunlik'),
          ])
            field(
              controller: c,
              placeholder: '0.000000',
              keyboard: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              prefix: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: SizedBox(
                  width: 78,
                  child: Text(label, style: body(context)),
                ),
              ),
              onChanged: (v) =>
                  widget.onChanged({...location, k: num.tryParse(v)}),
            ),
        ];
      case 'photo' || 'audio' || 'video':
        final files = List<dynamic>.from(widget.value ?? []);
        final icon = switch (type) {
          'photo' => CupertinoIcons.photo,
          'video' => CupertinoIcons.videocam,
          _ => CupertinoIcons.waveform,
        };
        return [
          for (final id in files)
            CupertinoListTile(
              leading: Icon(
                icon,
                color: dyn(context, CupertinoColors.secondaryLabel),
              ),
              title: Text(names[id] ?? 'Fayl №$id'),
              subtitle: const Text('Yuklandi'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: disabled
                    ? null
                    : () => widget.onChanged(
                        List<dynamic>.from(files)..remove(id),
                      ),
                child: Icon(
                  CupertinoIcons.minus_circle_fill,
                  color: dyn(context, CupertinoColors.systemRed),
                  semanticLabel: 'Faylni olib tashlash',
                ),
              ),
            ),
          if (working)
            const CupertinoListTile(
              leading: CupertinoActivityIndicator(),
              title: Text('Yuklanmoqda…'),
            )
          else ...[
            actionRow(
              switch (type) {
                'photo' => CupertinoIcons.camera_fill,
                'video' => CupertinoIcons.videocam_fill,
                _ => CupertinoIcons.mic_fill,
              },
              type == 'audio'
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemBlue,
              switch (type) {
                'photo' => 'Suratga olish',
                'video' => 'Video olish',
                _ => 'Ovoz yozish',
              },
              () => pick(true),
            ),
            actionRow(
              CupertinoIcons.folder_fill,
              CupertinoColors.systemIndigo,
              type == 'photo' ? 'Galereyadan tanlash' : 'Fayl tanlash',
              () => pick(false),
            ),
          ],
        ];
      case 'search':
        return [
          Padding(
            padding: const EdgeInsets.all(10),
            child: CupertinoSearchTextField(
              enabled: !disabled,
              placeholder: 'Kamida 2 harf kiriting',
              onChanged: search,
            ),
          ),
          if (widget.value != null)
            CupertinoListTile(
              leading: Icon(
                CupertinoIcons.person_crop_circle_fill,
                color: dyn(context, Palette.tint),
              ),
              title: Text(names[widget.value] ?? 'Tanlangan: ${widget.value}'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: disabled ? null : () => widget.onChanged(null),
                child: Icon(
                  CupertinoIcons.clear_circled_solid,
                  color: dyn(context, CupertinoColors.tertiaryLabel),
                  semanticLabel: 'Tanlovni tozalash',
                ),
              ),
            ),
          for (final m in members)
            CupertinoListTile(
              leading: const Icon(CupertinoIcons.person),
              title: Text('${m['full_name'] ?? m['name'] ?? m['id']}'),
              subtitle: m['email'] == null ? null : Text('${m['email']}'),
              onTap: disabled
                  ? null
                  : () {
                      names[m['id']] =
                          '${m['full_name'] ?? m['name'] ?? m['id']}';
                      widget.onChanged(m['id']);
                      setState(() => members = []);
                    },
            ),
        ];
      default:
        return [
          field(
            controller: text,
            minLines: type == 'text_box' ? 4 : null,
            maxLines: type == 'text_box' ? 8 : 1,
            keyboard: switch (type) {
              'numeric' => const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              'phone' => TextInputType.phone,
              'text_box' => TextInputType.multiline,
              _ => TextInputType.text,
            },
            placeholder: switch (type) {
              'numeric' => 'Son kiriting',
              'phone' => '+998 __ ___ __ __',
              'barcode' => 'Kodni skanerlang yoki kiriting',
              _ => 'Javobingiz',
            },
            suffix: type == 'barcode'
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(44, 44),
                    onPressed: disabled ? null : scan,
                    child: const Icon(
                      CupertinoIcons.qrcode_viewfinder,
                      semanticLabel: 'Shtrix-kodni skanerlash',
                    ),
                  )
                : null,
            onChanged: (v) => widget.onChanged(
              type == 'numeric' ? num.tryParse(v) ?? (v.isEmpty ? null : v) : v,
            ),
          ),
        ];
    }
  }

  Widget _note(String s) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(s, style: secondary(context)),
  );

  @override
  Widget build(BuildContext context) {
    if (type == 'group' || type == 'branch') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${q['question']}', style: title(context, size: 21)),
            if (q['description'] != null) ...[
              const SizedBox(height: 4),
              Text('${q['description']}', style: secondary(context)),
            ],
          ],
        ),
      );
    }
    final message = widget.error;
    final red = dyn(context, CupertinoColors.systemRed);
    return CupertinoListSection.insetGrouped(
      header: Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: '${q['question']}',
                  children: [
                    if (q['is_required'] == true)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: red),
                      ),
                  ],
                ),
                style: body(context).copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.2,
                ),
              ),
              if (q['description'] != null && type != 'readme') ...[
                const SizedBox(height: 3),
                Text(
                  '${q['description']}',
                  style: secondary(context, size: 14),
                ),
              ],
            ],
          ),
        ),
      ),
      footer: message == null && error == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message != null)
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle_fill,
                          size: 15,
                          color: red,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(color: red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (error != null) ErrorBox(error!),
              ],
            ),
      children: editor(),
    );
  }
}

/// Bottom sheet hosting a wheel picker with Cancel / Done, as in iOS forms.
class _PickerSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _PickerSheet({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    height: 300 + MediaQuery.paddingOf(context).bottom,
    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
    decoration: BoxDecoration(
      color: dyn(context, CupertinoColors.systemBackground),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
    ),
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: dyn(context, CupertinoColors.separator),
                width: .5,
              ),
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Bekor'),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(context).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              CupertinoButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Tayyor',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

// ───────────────────────────── Scanner ─────────────────────────────

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final controller = MobileScannerController();
  bool done = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.black,
    navigationBar: CupertinoNavigationBar(
      brightness: Brightness.dark,
      backgroundColor: const Color(0xcc000000),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context),
        child: const Text('Bekor'),
      ),
      middle: const Text(
        'Kodni skanerlash',
        style: TextStyle(color: CupertinoColors.white),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: controller.toggleTorch,
        child: const Icon(CupertinoIcons.bolt_fill, semanticLabel: 'Chiroq'),
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null && !done) {
              done = true;
              Navigator.pop(context, code);
            }
          },
          errorBuilder: (context, error) => const CupertinoTheme(
            data: CupertinoThemeData(brightness: Brightness.dark),
            child: Center(
              child: EmptyView(
                icon: CupertinoIcons.camera,
                title: 'Kamera ochilmadi',
                description:
                    'Kameraga ruxsatni tekshiring yoki kodni qo‘lda kiriting.',
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: CupertinoColors.white, width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 24,
          right: 24,
          bottom: 60,
          child: IgnorePointer(
            child: Text(
              'Shtrix-kod yoki QR kodni ramka ichiga joylang',
              textAlign: TextAlign.center,
              style: TextStyle(color: CupertinoColors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────────── Audio ─────────────────────────────

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});
  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final recorder = AudioRecorder();
  bool recording = false, busy = false;
  Object? error;
  Duration elapsed = Duration.zero;
  Timer? clock;

  @override
  void dispose() {
    clock?.cancel();
    recorder.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    setState(() => busy = true);
    try {
      if (recording) {
        clock?.cancel();
        final path = await recorder.stop();
        if (mounted) Navigator.pop(context, path);
      } else {
        if (!await recorder.hasPermission()) {
          throw ApiException(
            'Mikrofonga ruxsat berilmadi. Sozlamalarda ruxsat bering.',
          );
        }
        final dir = await getTemporaryDirectory();
        await recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path:
              '${dir.path}/epicollect-${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        final start = DateTime.now();
        clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
          if (mounted) {
            setState(() => elapsed = DateTime.now().difference(start));
          }
        });
        if (mounted) setState(() => recording = true);
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final red = dyn(context, CupertinoColors.systemRed);
    final m = elapsed.inMinutes.toString().padLeft(2, '0'),
        s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: busy
              ? null
              : () async {
                  if (recording) await recorder.cancel();
                  if (context.mounted) Navigator.pop(context);
                },
          child: const Text('Bekor'),
        ),
        middle: const Text('Ovoz yozish'),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$m:$s',
                  style: body(context).copyWith(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recording
                      ? 'Yozilmoqda. Tugatish uchun bosing.'
                      : 'Boshlash uchun bosing',
                  style: secondary(context, size: 16),
                ),
                const SizedBox(height: 36),
                Semantics(
                  button: true,
                  label: recording
                      ? 'Yozishni tugatish va biriktirish'
                      : 'Yozishni boshlash',
                  child: GestureDetector(
                    onTap: busy ? null : toggle,
                    child: Container(
                      width: 84,
                      height: 84,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: dyn(context, CupertinoColors.systemGrey3),
                          width: 4,
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: EdgeInsets.all(recording ? 16 : 0),
                        decoration: BoxDecoration(
                          color: red,
                          borderRadius: BorderRadius.circular(
                            recording ? 8 : 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 24),
                  ErrorBox(error!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
