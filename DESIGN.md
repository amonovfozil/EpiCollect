# EpiCollect: dizayn tizimi

Collector mobil ilovasi. Platforma: Android va iOS, ikkalasida ham Cupertino (buyurtmachi talabi). Rejim: Operate.

## G'oya
Har bir loyihaning o'z belgisi bor: iOS ilova ikonkasi shaklidagi yumaloq kvadrat, bitta to'q rang va mavzuga mos `CupertinoIcons` ikonkasi (`ProjectLook`, `ProjectMark`). Ikonka loyiha nomi va tavsifidagi so'zlardan tanlanadi: so'rovnoma, kuzatuv, dala, sog'liq, suv, maktab, xonadon, mahalla va hokazo. Mos so'z topilmasa, `id` bo'yicha barqaror tanlanadi. Belgi ro'yxatda, qoralamalarda va loyiha muqovasida bir xil ko'rinadi, ro'yxatdan sahifaga `Hero` bilan o'tadi.

Loyiha sahifasi muqovasi (`ProjectCover`) loyiha rangining yengil fonida joylashgan belgi va chetidan kesilgan katta, xira ikonkadan iborat. Anketa progressi (`ProgressLine`) ingichka chiziq: tint rangida to'ladi, hamma savolga javob berilganda yashilga aylanadi. Kirish ekranida ilova belgisi (`AppMark`) turadi.

## Rang
- Loyiha belgilari (`Palette.marks`): indigo, teal, dala yashili, loy, olxo'ri, daryo ko'ki. Har bir loyihaga bittadan rang beriladi.
- Interaktiv tint: `Palette.tint` (yorug' rejimda `#2B3BA3`, tungi rejimda `#9AA6FF`). Faqat shu rang bosiladigan elementlarni bildiradi.
- Holatlar (dinamik): `pending` za'faron, `approved` yashil, `cancelled` qizil. Holat ikonka va matn bilan birga beriladi, faqat rangga tayanmaydi.
- Qolgan hammasi iOS semantik ranglari: `systemGroupedBackground`, `secondarySystemGroupedBackground`, `label`, `secondaryLabel`, `separator`.

## Tipografiya
Tizim shrifti (SF / Roboto) Cupertino text theme orqali beriladi. Katta sarlavhalar `CupertinoSliverNavigationBar` bilan. Ekran sarlavhasi 26–28/w700, karta sarlavhasi 19/w700, asosiy matn 17, ikkilamchi matn 15/13. Hisoblagichlarda tabular raqamlar ishlatiladi.

## Komponentlar
- Navigatsiya: `CupertinoTabScaffold` uchta bo'lim bilan (Loyihalar, Qoralamalar, Profil). Anketa, skaner va audio ekranlari root navigator orqali ochiladi, ya'ni tab bar ko'rinmaydi.
- Ro'yxatlar: `CupertinoListSection.insetGrouped`. Sarlavhalar oddiy yozuvda, chunki tizim ularni katta qalin shriftda chiqaradi.
- Loyiha kartasi: chapda belgi, o'ngda nom, tavsif, holat va rol. Bosilganda biroz kichrayadi.
- Bo'lim izohlari (footer) 13pt ikkilamchi rangda, chunki tizim ularni asosiy matn o'lchamida chiqaradi.
- Savollar: har bir savol alohida inset bo'lim. Tanlov iOS checkmark bilan, ko'p tanlov kvadrat belgi bilan. Ko'p variantli dropdown, sana va vaqt pastdan chiquvchi picker sheet'da ochiladi. Xato bo'lim footerida qizil rangda ko'rsatiladi.
- Tugmalar: `PrimaryButton` (`CupertinoButton.filled`, 52pt balandlik, 14 radius). Ikkilamchi amallar `CupertinoButton` matn tugmasi.
- Tasdiqlash uchun `CupertinoAlertDialog`, tanlov uchun `CupertinoActionSheet`, qisqa xabar uchun `toast()` (xiralashtirilgan HUD).
- Ikonkalar: faqat `CupertinoIcons`. Sozlamalar qatorida `IconTile` ishlatiladi.

## Qoidalar
- Bosish maydoni kamida 44×44.
- Mazmun planshetda 720pt kenglikda chegaralanadi (`Readable`, `SliverReadable`).
- Yorug' va tungi rejim teng darajada qo'llab-quvvatlanadi. Mavzu profildan tanlanadi va saqlanadi.
