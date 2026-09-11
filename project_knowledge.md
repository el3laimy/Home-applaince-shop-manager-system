# مشروع ALIkhlasPOS v2

## الحالة الحالية

ALIkhlasPOS v2 هو تطبيق Flutter Desktop محلي لإدارة محل واحد، ويعمل بدون Backend منفصل أو Docker أو PostgreSQL أو Redis. المسار النشط الوحيد هو:

`Frontend/alikhlas_pos`

## المكدس التقني

- Flutter Desktop مستهدف لـ Linux وWindows.
- SQLite عبر drift.
- Riverpod لإدارة حالة التطبيق.
- PDF/printing للطباعة والتصدير.
- واجهة Apple/iOS-inspired Liquid Glass بخط Cairo مدمج محليًا.

## قواعد العمل الأساسية

- كل المال يُخزن كـ integer minor units، وليس `double`.
- الدفتر `LedgerEntry` و`LedgerLine` هو مصدر الحقيقة للأرصدة والتقارير.
- العمليات المالية تمر عبر use-cases في `lib/v2/application/v2_use_cases.dart`.
- لا VAT في v2.
- المستخدم الحالي مالك واحد محليًا، بدون أدوار أو صلاحيات متعددة.
- المرتجعات تعكس قيمة البضاعة وCOGS، وفائدة التقسيط لا تُرد تلقائيًا.

## وحدات v2

- POS والبيع المختلط: كاش، محفظة، تقسيط.
- المشتريات وتحديث WAC.
- المخزون وصور المنتجات وطباعة باركود الوارد.
- العملاء والموردون وكشف الحساب التفاعلي/PDF.
- الأقساط، المصروفات، التقارير، الوردية، النسخ الاحتياطي والاسترجاع.

## تعليمات التطوير

- لا تعدل schema أو قواعد ledger إلا لاختبار bug محاسبي مؤكد.
- حافظ على اشتقاق التقارير والأرصدة من `LedgerLine`.
- اختبر أي تغيير مالي على SQLite الحقيقي.
- أوامر التحقق الأساسية:

```bash
cd Frontend/alikhlas_pos
dart analyze lib/v2 lib/main.dart test/v2
flutter test
HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux
```
