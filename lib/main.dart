import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'widgets/brand.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EpiCollectApp());
}

/// Appearance choice persisted in preferences: 0 system, 1 light, 2 dark.
enum Appearance { system, light, dark }

CupertinoThemeData appTheme(Brightness? brightness) => CupertinoThemeData(
  brightness: brightness,
  primaryColor: Palette.tint,
  primaryContrastingColor: Palette.onTint,
  scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
  barBackgroundColor: const CupertinoDynamicColor.withBrightness(
    color: Color(0xeef2f2f7),
    darkColor: Color(0xee000000),
  ),
);

class EpiCollectApp extends StatefulWidget {
  const EpiCollectApp({super.key});
  @override
  State<EpiCollectApp> createState() => _EpiCollectAppState();
}

class _EpiCollectAppState extends State<EpiCollectApp> {
  final api = Api();
  Appearance mode = Appearance.system;
  late Future<bool> ready;

  @override
  void initState() {
    super.initState();
    ready = api.restore();
    api.addListener(changed);
    SharedPreferences.getInstance().then((p) {
      final i = p.getInt('theme') ?? 0;
      if (mounted && i < Appearance.values.length) {
        setState(() => mode = Appearance.values[i]);
      }
    });
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> setAppearance(Appearance v) async {
    setState(() => mode = v);
    await (await SharedPreferences.getInstance()).setInt('theme', v.index);
  }

  @override
  void dispose() {
    api.removeListener(changed);
    api.client.close();
    api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoApp(
    title: 'EpiCollect',
    debugShowCheckedModeBanner: false,
    locale: const Locale('uz'),
    supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
    localizationsDelegates: GlobalCupertinoLocalizations.delegates,
    theme: appTheme(switch (mode) {
      Appearance.system => null,
      Appearance.light => Brightness.light,
      Appearance.dark => Brightness.dark,
    }),
    home: FutureBuilder<bool>(
      future: ready,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const CupertinoPageScaffold(
            child: Center(child: Brand(size: 30)),
          );
        }
        if (s.hasError) {
          return CupertinoPageScaffold(
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorBox(
                        s.error!,
                        retry: () => setState(() {
                          ready = api.restore();
                        }),
                      ),
                      CupertinoButton(
                        onPressed: () async {
                          await api.clear();
                          setState(() {
                            ready = Future.value(false);
                          });
                        },
                        child: const Text('Qayta kirish'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 350),
          child: api.user == null
              ? LoginScreen(key: const ValueKey('login'), api: api)
              : HomeScreen(
                  key: ValueKey('home-${api.user!['id']}'),
                  api: api,
                  appearance: mode,
                  onAppearance: setAppearance,
                ),
        );
      },
    ),
  );
}
