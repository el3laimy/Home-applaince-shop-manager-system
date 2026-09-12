# إجراء إصدار إخلاص POS للمستخدم النهائي

هذا الإجراء يحول commit مقبولًا إلى حزم تنزيل ثابتة. لا يُنشئ الـworkflow إصدارًا عامًا تلقائيًا؛ ينشئ **Draft Release** حتى تظل مراجعة الجهاز والعتاد والتوقيع خطوة إلزامية قبل النشر.

## 1. تجهيز هوية الناشر مرة واحدة

يحتاج المستودع إلى شهادة Windows Code Signing سارية بصيغة PFX ومفتاحها الخاص. تُحفظ القيمتان في GitHub Actions Secrets ولا تدخلان Git أو ملفات المشروع:

- `WINDOWS_SIGNING_CERTIFICATE_BASE64`: محتوى ملف PFX بعد تحويله إلى Base64.
- `WINDOWS_SIGNING_CERTIFICATE_PASSWORD`: كلمة مرور ملف PFX.

ينفذ المسؤول على جهاز Windows موثوق:

```powershell
$bytes = [IO.File]::ReadAllBytes('C:\secure\publisher-code-signing.pfx')
[Convert]::ToBase64String($bytes) | Set-Clipboard
```

يلصق الناتج في السر الأول وكلمة المرور في السر الثاني من إعدادات GitHub. لا تُطبع القيمتان في سجل، ولا تحفظ شهادة PFX داخل مجلد المشروع أو الحزمة المسلّمة.

## 2. تجهيز الإصدار المرشح

1. حدّث `version` في `Frontend/alikhlas_pos/pubspec.yaml` وملاحظات الإصدار.
2. شغّل `Desktop Release Build` على الفرع، ثم ادمج commit المقبول إلى `main` وتأكد أن تشغيل `main` أخضر.
3. نفذ تجربة قبول مبدئية على حزم نفس commit حتى لا يُنشأ tag لعيب معروف، لكن لا توزع build غير موقّع على المستخدم النهائي.
4. اعتمد اسم جهة الدعم وساعات الاستجابة وهوية الناشر المكتوبة في شهادة Windows، وجهّز أجهزة القبول النهائي والعتاد المطلوب.

## 3. إنشاء tag الإصدار

اسم tag يجب أن يساوي حرف `v` ثم قيمة `version` كاملة، بما فيها رقم البناء بعد `+`. للإصدار الحالي:

```bash
git switch main
git pull --ff-only origin main
git tag -a 'v1.1.0+10' -m 'ALIkhlasPOS 1.1.0+10'
git push origin 'v1.1.0+10'
```

يرفض الـworkflow tag لا يطابق `pubspec.yaml`. كما يرفض tagged build إذا غابت شهادة التوقيع أو كلمة مرورها، أو فشل ختم الوقت، أو لم ينجح التحقق من توقيع EXE.

## 4. ما ينفذه GitHub Actions

بعد نجاح التحليل والاختبارات يبني المسار حزمتي Windows وDebian، ثم:

1. يوقّع `alikhlas_pos.exe` قبل إدخاله في مُثبّت NSIS.
2. يوقّع مُثبّت Windows النهائي ويتحقق من توقيعي التطبيق والمُثبّت عبر `signtool`.
3. يعيد دورة التثبيت والترقية والإزالة وإعادة التثبيت وبقاء بيانات المستخدم على Windows وLinux.
4. يتحقق أن tag يطابق نسخة التطبيق الكاملة.
5. ينشئ `SHA256SUMS` ويتحقق منه قبل الرفع.
6. ينشئ Draft Release يحتوي فقط على مُثبّت Windows وحزمة Debian وملف البصمات.

## 5. مراجعة المسودة ثم النشر

قبل الضغط على **Publish release**:

- طابق commit ونسخة شاشة المساعدة مع tag وGitHub Actions run.
- نزّل الملفات الثلاثة من المسودة وتحقق من `SHA256SUMS`.
- على Windows، افتح خصائص المُثبّت وتحقق من Digital Signatures، ثم جرّب SmartScreen بحساب مستخدم عادي.
- على Linux، ثبّت ملف Debian من واجهة النظام الرسومية على التوزيعة والجهاز المعتمدين.
- نفذ `FIELD_ACCEPTANCE_AR.md` كاملًا على ملفات المسودة نفسها؛ سجل أسماء الملفات وبصماتها ونتائج العتاد والمستخدم.
- أرفق نموذج `FIELD_ACCEPTANCE_AR.md` المكتمل وقرار القبول في سجل الإصدار الداخلي.
- تأكد أن صفحة الإصدار تذكر جهة الدعم وساعات الاستجابة وخطوات النسخ قبل التحديث.

إذا لم يكتمل أي بند، تظل المسودة غير منشورة. إصلاح الكود ينتج نسخة وtag جديدين؛ لا تُستبدل ملفات إصدار نُشر للمستخدمين بصمت.

## 6. تحقق المستخدم من الملف

Windows PowerShell:

```powershell
Get-FileHash .\ALIkhlasPOS-Setup-1.1.0-x64.exe -Algorithm SHA256
Get-AuthenticodeSignature .\ALIkhlasPOS-Setup-1.1.0-x64.exe
```

Linux:

```bash
sha256sum --check SHA256SUMS
```

يجب أن تطابق البصمة الملف المنشور، وأن تكون حالة توقيع Windows `Valid` باسم الناشر المعتمد.
