import 'dart:math';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? v) =>
    v == null || !_emailPattern.hasMatch(v.trim())
    ? 'To‘g‘ri email manzilini kiriting'
    : null;
String? validatePassword(String? v) =>
    v == null || v.isEmpty ? 'Parolni kiriting' : null;

class LoginScreen extends StatefulWidget {
  final Api api;
  const LoginScreen({super.key, required this.api});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>(),
      email = TextEditingController(),
      password = TextEditingController(),
      passwordFocus = FocusNode();
  bool busy = false, hidden = true, tried = false;
  Object? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() => tried = true);
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.login(email.text, password.text);
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void open(String path) => launchUrl(
    Uri.parse('https://datacollect.uz/#/$path'),
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final heroHeight = (size.height * .4).clamp(270.0, 380.0) + top;
    final sheet = dyn(context, CupertinoColors.systemGroupedBackground);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: sheet,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                _Hero(height: heroHeight, topInset: top),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: sheet,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Readable(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          30,
                          24,
                          MediaQuery.paddingOf(context).bottom + 8,
                        ),
                        child: buildForm(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildForm() => AutofillGroup(
    child: Form(
      key: form,
      autovalidateMode: tried
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Xush kelibsiz', style: title(context, size: 30)),
          const SizedBox(height: 6),
          Text(
            'DataCollect hisobingiz bilan kiring',
            style: secondary(context, size: 16),
          ),
          const SizedBox(height: 26),
          _Field(
            controller: email,
            enabled: !busy,
            icon: CupertinoIcons.at,
            placeholder: 'Elektron pochta',
            autofill: AutofillHints.username,
            keyboard: TextInputType.emailAddress,
            action: TextInputAction.next,
            onSubmitted: (_) => passwordFocus.requestFocus(),
            validator: validateEmail,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: password,
            focusNode: passwordFocus,
            enabled: !busy,
            icon: CupertinoIcons.lock,
            placeholder: 'Parol',
            autofill: AutofillHints.password,
            obscure: hidden,
            action: TextInputAction.go,
            onSubmitted: (_) => busy ? null : login(),
            validator: validatePassword,
            suffix: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(44, 44),
              onPressed: () => setState(() => hidden = !hidden),
              child: Icon(
                hidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                size: 20,
                color: dyn(context, CupertinoColors.secondaryLabel),
                semanticLabel: hidden
                    ? 'Parolni ko‘rsatish'
                    : 'Parolni yashirish',
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              onPressed: () => open('forgot-password'),
              child: const Text(
                'Parolni unutdingizmi?',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),
          if (error != null) ErrorBox(error!),
          const SizedBox(height: 6),
          PrimaryButton(label: 'Kirish', busy: busy, onPressed: login),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hisobingiz yo‘qmi?', style: secondary(context)),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onPressed: () => open('register'),
                child: const Text(
                  'Ro‘yxatdan o‘tish',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Filled rounded text field with its own validation line.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled, obscure;
  final IconData icon;
  final String placeholder, autofill;
  final TextInputType? keyboard;
  final TextInputAction action;
  final ValueChanged<String> onSubmitted;
  final FormFieldValidator<String> validator;
  final Widget? suffix;
  const _Field({
    required this.controller,
    this.focusNode,
    required this.enabled,
    this.obscure = false,
    required this.icon,
    required this.placeholder,
    required this.autofill,
    this.keyboard,
    required this.action,
    required this.onSubmitted,
    required this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: controller.text,
    validator: (_) => validator(controller.text),
    builder: (field) {
      final red = dyn(context, CupertinoColors.systemRed);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoTextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: obscure,
            autocorrect: false,
            autofillHints: [autofill],
            keyboardType: keyboard,
            textInputAction: action,
            placeholder: placeholder,
            onSubmitted: onSubmitted,
            onChanged: field.didChange,
            style: body(context).copyWith(fontSize: 17),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Icon(
                icon,
                size: 20,
                color: dyn(context, CupertinoColors.secondaryLabel),
              ),
            ),
            suffix: suffix,
            decoration: BoxDecoration(
              color: dyn(
                context,
                CupertinoColors.secondarySystemGroupedBackground,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: field.hasError ? red : const Color(0x00000000),
              ),
            ),
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: Text(
                field.errorText!,
                style: TextStyle(color: red, fontSize: 13),
              ),
            ),
        ],
      );
    },
  );
}

/// Tinted header: the app mark among the kinds of data the app collects,
/// drifting slowly. Still when Reduce Motion is on.
class _Hero extends StatefulWidget {
  final double height, topInset;
  const _Hero({required this.height, required this.topInset});
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  // x, y (fractions of the area below the status bar), size, tilt, phase.
  static const tiles = <(double, double, double, double, double, IconData)>[
    (.07, .10, 54, -.20, 0, CupertinoIcons.square_list_fill),
    (.80, .06, 48, .18, .3, CupertinoIcons.location_fill),
    (.86, .48, 58, -.12, .55, CupertinoIcons.camera_fill),
    (.03, .56, 46, .16, .8, CupertinoIcons.mic_fill),
    (.82, .80, 42, .22, .15, CupertinoIcons.qrcode),
    (.16, .86, 40, -.14, .65, CupertinoIcons.calendar),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? clock.stop() : clock.repeat();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = dyn(context, Palette.tint);
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final field = dark ? const Color(0xff1c2470) : tint;
    return Container(
      height: widget.height,
      color: field,
      padding: EdgeInsets.only(top: widget.topInset, bottom: 28),
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final t in tiles)
              AnimatedBuilder(
                animation: clock,
                builder: (_, child) {
                  final dy = sin((clock.value + t.$5) * 2 * pi) * 7;
                  return Positioned(
                    left: c.maxWidth * t.$1,
                    top: c.maxHeight * t.$2 - t.$3 / 2 + dy,
                    child: child!,
                  );
                },
                child: ExcludeSemantics(
                  child: Transform.rotate(
                    angle: t.$4,
                    child: Container(
                      width: t.$3,
                      height: t.$3,
                      decoration: BoxDecoration(
                        color: const Color(0x24ffffff),
                        borderRadius: BorderRadius.circular(t.$3 * .28),
                        border: Border.all(color: const Color(0x30ffffff)),
                      ),
                      child: Icon(
                        t.$6,
                        size: t.$3 * .48,
                        color: const Color(0xe6ffffff),
                      ),
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      size: 46,
                      color: dark ? const Color(0xff2b3ba3) : tint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EpiCollect',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Anketa · Joylashuv · Media',
                    style: TextStyle(
                      color: Color(0xccffffff),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
