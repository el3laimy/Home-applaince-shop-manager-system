# دفعة 11: العمليات المالية القابلة للاستعادة

تم تنفيذ اختبارات قاعدة ملفية وواجهة Flutter في 2026-09-10.

- `dart analyze lib/v2 lib/main.dart test/v2`: بلا ملاحظات.
- `flutter test --no-pub`: 108 اختبارات ناجحة.
- `flutter build linux --release --no-pub`: نجح؛ الناتج `Frontend/alikhlas_pos/build/linux/x64/release/bundle/alikhlas_pos`.

يغطي الإثبات المحلي معرّفات العمليات، إعادة التشغيل بعد فقد رد الحفظ، التحقق الصريح، والإلغاء الآمن. لا يغطي انقطاع كهرباء فعلي أو تثبيت Windows أو طابعة مادية.
