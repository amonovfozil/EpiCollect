# EpiCollect

Android va iOS uchun Flutter ilovasi. DataCollect mobil kollektor ish jarayonining yangidan yozilgan talqini.

## Ishga tushirish

Talablar: Flutter 3.50 / Dart 3.14, Android SDK; iOS uchun Xcode 27 va iOS 15+.

```sh
flutter pub get
flutter run
```

Server standart manzili: `https://api.datacollect.uz/api/v1`.
Boshqa mos API bilan: `flutter run --dart-define=API_URL=https://your-server/api/v1`.
Test hisob ma’lumotlari manba kodida saqlanmagan. O‘z DataCollect hisobingiz bilan kiring.

## Tayyor funksiyalar

- Xavfsiz token saqlash, sessiyani tiklash, chiqish va sessiya muddati tugashini boshqarish.
- Haqiqiy loyihalar, joriy sahifada qidiruv, paginatsiya va taklif qabul qilish.
- Dinamik anketa: text, text_box, numeric, phone, date, time, radio, checkbox, dropdown, location, barcode, photo, audio, video, search, readme, group va branch sarlavhalari.
- Server formatidagi shartli ko‘rsatish/yashirish, yashirilgan javoblarni yubormaslik, majburiy maydonlar va diapazon tekshiruvi.
- GPS, qo‘lda koordinata, kamera, shtrix-kod skaneri, media tanlash va audio yozish. Ruxsatlar faqat kerak bo‘lganda so‘raladi.
- Javob yuborish, pending javobni tahrirlash, idempotency kaliti, o‘z javoblarini ko‘rish va holat filtrlari.
- Foydalanuvchi va loyiha bo‘yicha ajratilgan shifrlangan mahalliy qoralamalar. Qoralama yuborilmaguncha server javobi yaratilmaydi.
- O‘zbekcha interfeys, yorug‘/tungi/tizim mavzusi; telefon navigatsiyasi va keng ekran uchun yon navigatsiya.

## Chegaralar

Bu APK ichidagi asl Dart manba kodining tiklangan nusxasi emas. API va ko‘rinadigan ish jarayoni asosida qayta yozilgan kod.
Asosiy tekshirilgan rol — collector. Administratorning form builder, a’zolar, eksport, audit va loyiha sozlamalari mavjud web tizimida ochiladi; ularning to‘liq native nusxasi bu versiyada yo‘q.
Branch hozir server web mijozidagi kabi guruh sarlavhasi sifatida ishlaydi; takrorlanadigan ichki yozuv muharriri yo‘q.
Qoralamalarni saqlash lokal, lekin anketa ochish va yuborish internet talab qiladi; fon sinxronizatsiyasi yoki to‘liq offline katalog mavjud emas.
Sana/vaqt tanlagichlarining matni qurilma tizim tiliga bog‘liq. Ilova matnlari hozir o‘zbekcha.
Media, GPS va mikrofonning real apparatdagi ishlashi yakuniy qurilmada tekshirilishi kerak.

## Build

```sh
flutter analyze
flutter test
flutter build apk --release --split-per-abi
flutter build ios --simulator --debug
flutter build ios --release --no-codesign
```

Android APK hozir lokal tekshirish uchun debug sertifikati bilan release rejimida imzolanadi. Play Store uchun o‘z release keystore konfiguratsiyangizni qo‘shing.
iPhone qurilmasi/TestFlight uchun `ios/Runner.xcworkspace` ni Xcode’da ochib, o‘z Team, bundle ID va provisioning profilini tanlang. Simulyator `.app` fayli iPhone’ga o‘rnatiladigan IPA emas.

## Testlar

`test/`: shartli savollar, ota-guruh ko‘rinishi, validatsiya, API xatolari, idempotency va kirish validatsiyasi.
`integration_test/collector_test.dart`: haqiqiy serverga kirish va o‘qish, shartli anketa, lokal qoralama. Serverga javob yubormaydi.

Credential JSON faylini loyiha tashqarisida yarating: `TEST_EMAIL` va `TEST_PASSWORD` kalitlari. Uni Git’ga qo‘shmang.

```sh
flutter drive --driver=test_driver/integration.dart --target=integration_test/collector_test.dart -d DEVICE_ID --dart-define-from-file=/absolute/path/test-credentials.json
```

Kod: `lib/core` API, forma qoidalari va qoralamalar; `lib/screens` sahifalar; `lib/widgets` qayta ishlatiladigan komponentlar.
