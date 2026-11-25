import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epicollect/main.dart';
import 'package:epicollect/core/api.dart';
import 'package:epicollect/screens/login.dart';

void main() {
  testWidgets('login validates before sending credentials', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        theme: appTheme(Brightness.light),
        home: LoginScreen(api: Api()),
      ),
    );
    await tester.ensureVisible(find.text('Kirish'));
    await tester.tap(find.text('Kirish'));
    await tester.pump();
    expect(find.text('To‘g‘ri email manzilini kiriting'), findsOneWidget);
    expect(find.text('Parolni kiriting'), findsOneWidget);
  });

  test('email and password validators', () {
    expect(validateEmail(' a@b.uz '), isNull);
    expect(validateEmail('ab.uz'), isNotNull);
    expect(validatePassword(''), isNotNull);
  });
}
