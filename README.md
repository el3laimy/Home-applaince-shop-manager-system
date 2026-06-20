# ALIkhlasPOS v2

تطبيق Flutter Desktop لإدارة محل واحد أوفلاين. المسار النشط الآن هو v2 داخل:

`Frontend/alikhlas_pos`

`Frontend/alikhlas_pos/lib/main.dart` يشغل `ALIkhlasV2App` مباشرة. لا يحتاج التطبيق إلى Backend أو Docker أو PostgreSQL أو Redis في وقت التشغيل.

## المعمارية الحالية

- Flutter Desktop + Riverpod.
- SQLite عبر drift.
- واجهة Apple/iOS-inspired Liquid Glass مبنية على Flutter Material مع أصول محلية.
- خط الواجهة العربي هو Cairo bundled داخل التطبيق ويعمل أوفلاين.
- ملفات PDF تستخدم Cairo المحلي من أصول التطبيق، بدون تحميل Google Fonts وقت الطباعة.
- قاعدة البيانات الافتراضية: `alikhlas_v2.db` داخل مسار بيانات التطبيق الذي يرجعه `path_provider`.
- كل العمليات المالية تمر عبر use-cases في `Frontend/alikhlas_pos/lib/v2/application/v2_use_cases.dart`.
- الدفتر `LedgerEntry` و`LedgerLine` هو مصدر الحقيقة للأرصدة والتقارير.
- القيم المالية محفوظة كـ integer minor units، وليست `double`.

## التشغيل

```bash
cd Frontend/alikhlas_pos
flutter pub get
flutter run -d linux
```

بيانات الدخول الافتراضية بعد أول تشغيل:

- المستخدم: `owner`
- كلمة المرور: `owner123`

التطبيق يفرض تغيير كلمة المرور الافتراضية قبل فتح شاشة التشغيل اليومية.

## Checklist تشغيل يدوي سريع

بعد أي build مهم، نفذ المسار التالي على قاعدة اختبار:

1. افتح التطبيق وسجل الدخول بالمستخدم `owner`.
2. غيّر كلمة المرور الافتراضية إذا طلب التطبيق ذلك.
3. افتح وردية برصيد افتتاحي.
4. أضف منتجًا أو نفذ شراءً لزيادة المخزون.
5. نفذ بيعًا من شاشة POS، ثم جرّب تحصيل قسط أو سداد مورد عند وجود خطة.
6. افتح كشف حساب عميل أو مورد وجرّب طباعة PDF.
7. نفذ مرتجعًا مرتبطًا بفاتورة بيع.
8. أنشئ نسخة احتياطية من شاشة النسخ.
9. أغلق الوردية وتأكد أن الفرق واضح.

## الواجهة والخط

- الواجهة تستخدم اتجاه Apple/iOS-inspired Liquid Glass: ألواح شفافة، حواف مضيئة، وخلفية هادئة غير مسطحة.
- الخلفية مرسومة بالكود بطبقات ضوء ناعمة لإظهار الزجاج بدون صور أو أصول ثقيلة.
- blur الحقيقي محدود ومركزي للألواح الكبيرة؛ الحقول والقوائم والأزرار تستخدم glass-like styling بدون `BackdropFilter`.
- الخط العربي `Cairo` مدمج محليًا داخل `Frontend/alikhlas_pos/assets/fonts`.
- الأوزان المدمجة: 400، 500، 600، 700 فقط.
- ترخيص الخط مرفق في `Frontend/alikhlas_pos/assets/fonts/OFL.txt`.
- التطبيق لا يعتمد على `google_fonts` في وقت التشغيل.
- صور المنتجات والخلفيات المختارة تُنسخ إلى مسار بيانات التطبيق داخل `product-images/` و`backgrounds/` حتى لا تختفي عند نقل الملف الأصلي.

## الاختبار والبناء

```bash
cd Frontend/alikhlas_pos
dart analyze lib/v2 lib/main.dart test/v2
flutter test
HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux
```

أمر Linux build الأخير مستخدم في هذه البيئة لأن Flutter SDK موجود في `/home/el3laimy/development/flutter`.

لبناء Windows، شغّل من جهاز Windows أو CI يدعم Windows Desktop:

```bash
cd Frontend/alikhlas_pos
flutter build windows
```

لم يتم توثيق تحقق Windows build محليًا في هذه البيئة؛ يجب تشغيله على Windows أو CI قبل إصدار Windows.

## النسخ الاحتياطي

- شاشة النسخ الاحتياطي داخل v2 تسمح باختيار مجلد النسخ.
- النسخ اليدوي يستخدم `VACUUM INTO`.
- النسخ التلقائي اليومي يعمل أثناء bootstrap/startup عند وجود مجلد محفوظ.
- الاحتفاظ الافتراضي: آخر 30 نسخة باسم يبدأ بـ `alikhlas-v2-`.
- الاسترجاع يحذف ملفات WAL/SHM القديمة ويطلب إعادة تشغيل التطبيق بعد الاسترجاع.

## المرتجعات وتكلفة المخزون

- المرتجع مرتبط بفاتورة بيع أصلية.
- يمكن إرجاع كمية جزئية من سطر البيع.
- مرتجع الكاش يحتاج وردية مفتوحة.
- مرتجع التقسيط يقفل ذمة العميل حتى الرصيد المتبقي فقط، وأي فائض يرد كاش أو محفظة.
- تكلفة المرتجع تعكس `SaleItem.unitCostMinor` التاريخية ولا تعيد حساب WAC الحالي.

## v1 Archive

تمت أرشفة حالة ما قبل حذف v1 في:

`archives/pre-v1-cleanup-working-tree.tar.gz`

بعد الأرشفة، تم حذف Backend القديم وواجهات Flutter v1 من الشجرة النشطة. v2 هو مسار التطبيق الوحيد في الكود الحالي.
