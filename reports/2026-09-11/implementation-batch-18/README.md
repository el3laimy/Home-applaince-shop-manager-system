# دفعة 18: مُثبّت Windows رسومي أولي

- `tool/alikhlas_pos.nsi` يغلّف Flutter Windows Release في مُثبّت لكل مستخدم ويضيف اختصارات Start وسطح المكتب.
- CI يثبت NSIS 3.12 عبر winget، يبني المخرج، يتحقق من وجوده، ويرفع artifact باسم `alikhlas-pos-windows-installer`.
- تم تحليل YAML ونجح `git diff --check` محليًا.

لا توجد بيئة Windows أو مترجم NSIS محليًا، لذلك لم يُبن المُثبّت أو يُثبت. الحزمة غير موقعة؛ يلزم تشغيل CI واختبار تثبيت وترقية وإزالة فعليًا قبل إصدارها للمستخدمين.
