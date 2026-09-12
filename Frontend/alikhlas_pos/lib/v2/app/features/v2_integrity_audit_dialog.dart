part of '../v2_app.dart';

class _IntegrityAuditDialog extends StatelessWidget {
  const _IntegrityAuditDialog({required this.audit});

  final Future<DataIntegrityAudit> audit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('فحص اتساق البيانات'),
      content: SizedBox(
        width: 640,
        child: FutureBuilder<DataIntegrityAudit>(
          future: audit,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Text(
                'تعذر إكمال الفحص الآن. لم تُعدّل أي بيانات؛ أعد المحاولة بعد حفظ نسخة احتياطية.',
              );
            }
            final result = snapshot.data!;
            if (result.isConsistent) {
              return const Text(
                'لا توجد تعارضات في القيود أو المخزون أو خطط الأقساط. الفحص للقراءة فقط ولم يغير أي بيانات.',
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'وجد الفحص ${result.issues.length} ملاحظة. لا تعدّل السجلات يدويًا؛ أنشئ نسخة احتياطية ثم راجع الدعم أو قيد تصحيح موثق.',
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: result.issues.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final issue = result.issues[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: Text(issue.record),
                        subtitle: Text(issue.message),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
