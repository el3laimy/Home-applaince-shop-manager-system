# دفعة 16: حزمة Debian/Ubuntu أولية

- `tool/build_linux_deb.sh` يحوّل Linux bundle إلى حزمة Debian ‏amd64 تحتوي التطبيق وملفات البيانات وقائمة التطبيقات والأيقونة.
- يبني GitHub Actions الحزمة ويفحص وجود التطبيق وملف desktop ثم يرفع artifact باسم `alikhlas-pos-linux-deb`.
- بنيت محليًا الحزمة `alikhlas-pos_1.0.0_amd64.deb` وفُحصت بنيتها ومحتوياتها.
- `dart analyze lib/v2 lib/main.dart test/v2`: بلا ملاحظات.
- `flutter test --no-pub`: 115 اختبارًا ناجحًا.
- `flutter build linux --release --no-pub`: نجح.

يلزم تثبيت نظيف وتشغيل وترقية فعلية على Ubuntu/Debian، وتظل حزمة Windows الموقعة واختبار أجهزة المستخدمين متبقية قبل إصدار نهائي.
