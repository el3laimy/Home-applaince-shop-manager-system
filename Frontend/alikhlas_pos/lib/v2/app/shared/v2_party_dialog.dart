part of '../v2_app.dart';

class _PartyDialog extends StatefulWidget {
  const _PartyDialog({required this.title});
  final String title;

  @override
  State<_PartyDialog> createState() => _PartyDialogState();
}

class _PartyDialogState extends State<_PartyDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'الهاتف'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _PartyFormData(_name.text, _phone.text)),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _PartyFormData {
  const _PartyFormData(this.name, this.phone);
  final String name;
  final String phone;
}
