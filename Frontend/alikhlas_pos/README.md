# ALIkhlasPOS Flutter

هذا هو تطبيق v2 النشط. `lib/main.dart` يفتح واجهة `ALIkhlasV2App` من `lib/v2/app/v2_app.dart`.

## المتطلبات

- Flutter SDK مهيأ لتشغيل Linux Desktop أو Windows Desktop.
- لا توجد خدمة Backend مطلوبة.
- لا توجد متطلبات Docker أو PostgreSQL أو Redis.

## أوامر التطوير

```bash
flutter pub get
flutter run -d linux
```

## أوامر التحقق

```bash
dart analyze lib/v2 lib/main.dart test/v2
flutter test
```

بناء Linux المستخدم في بيئة التطوير الحالية:

```bash
HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux
```

الناتج يكون في:

`build/linux/x64/release/bundle/alikhlas_pos`

لبناء Windows، استخدم جهاز Windows أو CI مناسب:

```bash
flutter build windows
```

## قاعدة البيانات

- الاتصال الافتراضي معرف في `lib/v2/data/app_database.dart`.
- اسم ملف SQLite الافتراضي: `alikhlas_v2.db`.
- drift يفعّل:
  - `PRAGMA foreign_keys = ON`
  - `PRAGMA journal_mode = WAL`
  - `PRAGMA synchronous = NORMAL`
- `schemaVersion` الحالي: 4.

## الاختبارات المهمة

- `test/v2/v2_use_cases_test.dart`: منطق v2، الدفتر، المخزون، الأقساط، المرتجعات، backup/restore، وترقية migration من v3 إلى v4.
- `test/v2/v2_app_test.dart`: login، تغيير كلمة المرور، بيع POS، وشراء من الواجهة.
- `test/v2/money_test.dart`: تنسيق المال.

## النسخ الاحتياطي والاسترجاع

من واجهة v2:

- اختار مجلد النسخ الاحتياطي.
- استخدم "نسخ الآن" لإنشاء نسخة يدوية.
- النسخ التلقائي اليومي يستخدم نفس المجلد أثناء bootstrap/startup.
- يتم الاحتفاظ بآخر 30 نسخة.
- عند الاسترجاع يتم استبدال ملف قاعدة البيانات الحالي، ثم يجب إعادة تشغيل التطبيق.

## سياسات v2

- مستخدم محلي واحد: `owner`.
- كلمة المرور الافتراضية: `owner123`، ويجب تغييرها عند أول دخول.
- لا VAT في v2.
- لا serial/warranty في v2 الأولى.
- WAC هو سياسة تكلفة المخزون الحالية.
- المرتجع مرتبط بفاتورة بيع أصلية ويدعم كمية جزئية.
- مرتجع الكاش يحتاج وردية مفتوحة.
- مرتجع التقسيط يخفض ذمة العميل حتى الرصيد المتبقي فقط، وأي فائض يرد كاش أو محفظة.
- المرتجع يعكس تكلفة البيع التاريخية المخزنة في `SaleItem.unitCostMinor` ولا يعيد حساب WAC الحالي.
