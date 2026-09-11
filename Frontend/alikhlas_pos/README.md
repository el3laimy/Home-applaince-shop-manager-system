# ALIkhlasPOS Flutter

هذا هو تطبيق v2 النشط. `lib/main.dart` يفتح واجهة `ALIkhlasV2App` من `lib/v2/app/v2_app.dart`.

## المتطلبات

- Flutter SDK مهيأ لتشغيل Linux Desktop أو Windows Desktop.
- لا توجد خدمة Backend مطلوبة.
- لا توجد متطلبات Docker أو PostgreSQL أو Redis.
- خط Cairo مدمج محليًا داخل `assets/fonts` ويعمل أوفلاين.

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

بعد `flutter build linux --release` يمكن بناء حزمة Debian/Ubuntu والتحقق منها قبل تثبيتها:

```bash
bash tool/build_linux_deb.sh build/linux/x64/release/bundle build/linux/x64/release/package 1.1.0
bash tool/verify_linux_deb.sh build/linux/x64/release/package/alikhlas-pos_1.1.0_amd64.deb
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
  - `PRAGMA synchronous = FULL`
- `schemaVersion` الحالي: 10.
- v5 أضاف `products.imagePath` لتخزين مسار صورة المنتج الداخلية، وv6 أضاف مستندات تسوية الجرد، وv7 أضاف الأرصدة الافتتاحية، وv8 أضاف مستندات مرتجع المشتريات وبنودها، وv9 أضاف مستندات تصحيح الخزينة والمحفظة، وv10 أضاف أساس قيمة المخزون الدقيق وتكلفة سطر البيع والمرتجع الدقيقة.
- يحتفظ التطبيق بعلامة ترحيل وحالاتها كملفات مستقلة منشورة ذريًا؛ لا يُستبدل ملف علامة قائم أثناء التحديث، وهو ما يدعم Windows عند انقطاع العملية.

## الاختبارات المهمة

- `test/v2/v2_use_cases_test.dart`: منطق v2، الدفتر، المخزون، الأقساط، المرتجعات، full owner day، backup/restore، وترقية migration من v3 إلى v8.
- `test/v2/purchase_return_idempotency_test.dart`: مرتجع الشراء، فرق متوسط التكلفة، الاستعادة، ومنع التكرار والرجوع الذري عند فشل الإيصال.
- `test/v2/financial_correction_idempotency_test.dart`: تصحيح الخزينة أو المحفظة، منع التكرار، الاستعادة، اعتماد الرصيد السالب، والرجوع الذري عند فشل الإيصال.
- `test/v2/financial_correction_ui_test.dart`: مراجعة وتسجيل تصحيح المحفظة من الإعدادات على شاشة صغيرة.
- `test/v2/v2_app_test.dart`: login، تغيير كلمة المرور، بيع POS، منع إدخال مال غير صالح، وشراء من الواجهة.
- `test/v2/v2_theme_test.dart`: خط Cairo، التباين، منع رجوع Roboto أو w800، وحصر blur الحقيقي.
- `test/v2/v2_golden_test.dart`: لقطات Golden لشاشة الدخول والـ dashboard وPOS والتقارير.
- `test/v2/money_test.dart`: تنسيق المال وparser إدخال المبالغ كـ minor units.
- `test/v2/v2_pdf_test.dart`: بناء PDF لكشف العميل/المورد باستخدام Cairo المحلي.
- `test/v2/local_image_store_test.dart`: نسخ صور المنتجات والخلفيات إلى مسار بيانات التطبيق.

## الواجهة والخط

- الثيم معرف في `lib/v2/app/app_theme.dart`.
- توكنز اللون والمسافات والزجاج موجودة في `lib/v2/app/design_tokens.dart`.
- الواجهة مستوحاة من Apple/iOS Liquid Glass بدون استخدام أصول أو شعارات Apple.
- الخلفية مرسومة بالكود بطبقات ضوء ناعمة لإظهار الزجاج بدون صور أو أصول ثقيلة.
- `BackdropFilter` opt-in ومخصص للألواح الكبيرة فقط؛ العناصر الكثيفة تستخدم glass-like styling أخف.
- ملفات Cairo المدمجة:
  - `assets/fonts/Cairo-Regular.ttf`
  - `assets/fonts/Cairo-Medium.ttf`
  - `assets/fonts/Cairo-SemiBold.ttf`
  - `assets/fonts/Cairo-Bold.ttf`
  - `assets/fonts/OFL.txt`
- لا يوجد اعتماد runtime على `google_fonts`.
- ملفات PDF تستخدم نفس ملفات Cairo المحلية من `assets/fonts`، ولا تحتاج تحميل خطوط وقت الطباعة.
- صور المنتجات والخلفيات المختارة تُنسخ إلى مسار بيانات التطبيق داخل `product-images/` و`backgrounds/` بدل الاعتماد على مكان الملف الأصلي.

## النسخ الاحتياطي والاسترجاع

من واجهة v2:

- اختار مجلد النسخ الاحتياطي.
- استخدم "نسخ الآن" لإنشاء نسخة يدوية.
- النسخ التلقائي يعمل عند بدء التشغيل ثم كل 30 دقيقة أثناء بقاء التطبيق مفتوحًا إذا حُفظ مجلد النسخ.
- يتم الاحتفاظ بآخر 30 نسخة.
- نجاح إنشاء النسخة لا يتحول إلى فشل عند تعذر حذف نسخة قديمة؛ تظهر رسالة مساحة أو تنظيف مستقلة ويُسجل وقت النجاح.
- عند الاسترجاع يتم استبدال ملف قاعدة البيانات الحالي، ثم يجب إعادة تشغيل التطبيق.

## سياسات v2

- مستخدم محلي واحد ينشئه صاحب المحل في أول تشغيل.
- قاعدة جديدة لا تنشئ كلمة مرور افتراضية منشورة؛ يحفظ المالك رمز الاستعادة خارج الجهاز بعد الإعداد.
- لا VAT في v2.
- لا serial/warranty في v2 الأولى.
- WAC هو سياسة تكلفة المخزون الحالية.
- `avgCostMinor` قيمة عرض مدورة فقط؛ القيود المالية تعتمد أساس القيمة الدقيق `inventoryValueMinor` حتى يتطابق المخزون مع دفتر الأستاذ عند تصفية الكميات.
- المرتجع مرتبط بفاتورة بيع أصلية ويدعم كمية جزئية.
- مرتجع الكاش يحتاج وردية مفتوحة.
- مرتجع التقسيط يخفض ذمة العميل حتى الرصيد المتبقي فقط، وأي فائض يرد كاش أو محفظة.
- مرتجع البيع يعيد التكلفة الدقيقة المحفوظة في `SaleItem.costMinor` ويعيد احتساب أساس قيمة المخزون، لذلك لا يخلط التكلفة التاريخية بمتوسط التكلفة اللاحق.
- مرتجع الشراء يبدأ من شاشة المرتجعات، ويعيد المخزون من فاتورة شراء محددة دون تجاوز الكمية أو المخزون الحالي. تسوية ذمة المورد تستخدم تكلفة الشراء الأصلية، بينما ينخفض المخزون بمتوسط التكلفة الحالي ويُرحّل الفرق إلى `inventory_variance`.
- التصحيح المالي مقصور على فرق عدّ الخزينة أو المحفظة، ويفرض سببًا ومراجعةً ومفتاح منع تكرار؛ لا يعدّل مبيعات أو مشتريات أو مخزون أو ذمم الأطراف. فرق الخزينة يحتاج وردية مفتوحة، ويُرحّل الفرق إلى `financial_variance`.
- لا يُعطّل الصنف ما دام له كمية أو قيمة مخزون، ولا يقبل الرصيد الافتتاحي الموجب بتكلفة صفر. الصنف المعطّل لا يدخل في شراء جديد حتى يعاد تفعيله؛ تبقى المستندات والمرتجعات والتسويات التاريخية قابلة للمراجعة.
- كلمات المرور تستخدم PBKDF2-HMAC-SHA256 مع 600,000 تكرار، وتُحجب محاولات تسجيل الدخول بعد خمس محاولات خاطئة لمدة 15 دقيقة.
