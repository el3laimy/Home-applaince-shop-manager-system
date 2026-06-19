# ALIkhlasPOS v2

تطبيق Flutter Desktop لإدارة محل واحد أوفلاين. المسار النشط الآن هو v2 داخل:

`Frontend/alikhlas_pos`

`Frontend/alikhlas_pos/lib/main.dart` يشغل `ALIkhlasV2App` مباشرة. لا يحتاج التطبيق إلى Backend أو Docker أو PostgreSQL أو Redis في وقت التشغيل.

## المعمارية الحالية

- Flutter Desktop + Riverpod.
- SQLite عبر drift.
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
