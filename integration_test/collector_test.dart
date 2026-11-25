import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:epicollect/widgets/common.dart';
import 'package:epicollect/main.dart' as app;
import 'package:epicollect/core/drafts.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Live collector: login, projects, conditional form and secure draft',
    (tester) async {
      const email = String.fromEnvironment('TEST_EMAIL');
      const password = String.fromEnvironment('TEST_PASSWORD');
      expect(
        email,
        isNotEmpty,
        reason: 'Pass test credentials via --dart-define-from-file.',
      );
      await const FlutterSecureStorage().delete(key: 'session');
      app.main();
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 200));
          if (finder.evaluate().isNotEmpty) {
            await tester.pump(const Duration(milliseconds: 500));
            return;
          }
        }
        throw TestFailure('Timed out waiting for $finder');
      }

      Future<void> shot(String name) async {
        // The login header animates forever, so settle by time, not by idle.
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await binding.takeScreenshot(
          '${Platform.isIOS ? 'ios' : 'android'}-$name',
        );
      }

      await waitFor(find.text('Kirish'));
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      await shot('login');
      await tester.enterText(find.byType(CupertinoTextField).at(0), email);
      await tester.enterText(find.byType(CupertinoTextField).at(1), password);
      await tester.tap(find.text('Kirish'));
      await waitFor(find.text('Project 1'));
      await shot('projects');
      await tester.scrollUntilVisible(
        find.text('Community survey'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Community survey'));
      await waitFor(find.byType(PrimaryButton));
      await shot('project');
      await tester.tap(find.byType(PrimaryButton));
      await waitFor(find.text('Name of observation *'));
      // A leftover local draft may prompt; start from the server copy.
      if (find.text('Qoralama topildi').evaluate().isNotEmpty) {
        await tester.tap(find.byType(CupertinoDialogAction).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(find.text('Follow up details *'), findsNothing);
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'Mobile integration check — local draft only',
      );
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('Follow up details *'), findsOneWidget);
      await tester.ensureVisible(find.text('Follow up details *'));
      await shot('conditional-form');
      await tester.enterText(
        find.byType(CupertinoTextField).last,
        'Draft storage verified. No server submission.',
      );
      await tester.tap(find.text('Saqlash'));
      await waitFor(find.text('Qoralama qurilmada saqlandi'));
      // User id is obtained from the actual logged-in app, never assumed.
      final home = find.byType(app.EpiCollectApp);
      expect(home, findsOneWidget);
      final all = await const FlutterSecureStorage().readAll();
      final key = all.keys.firstWhere(
        (k) => k.startsWith('draft.') && k.endsWith('.1'),
      );
      final user = key.split('.')[1];
      expect(
        (await Drafts(user).read(1))?['answers']['1'],
        contains('integration check'),
      );
      await Drafts(user).remove(1);
      await tester.tap(find.text('Yopish'));
      await tester.pumpAndSettle();
      await shot('project-after-draft');
      await tester.tap(find.byType(CupertinoNavigationBarBackButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qoralamalar').last);
      await tester.pumpAndSettle();
      await shot('drafts');
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      await shot('profile');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tungi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loyihalar').last);
      await tester.pumpAndSettle();
      await shot('projects-dark');
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tizim'));
      await tester.pumpAndSettle();
    },
  );
}
