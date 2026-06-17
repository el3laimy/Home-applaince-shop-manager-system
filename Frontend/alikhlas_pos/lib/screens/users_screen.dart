import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../core/theme/design_tokens.dart';

class _UserModel {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;

  const _UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory _UserModel.fromJson(Map<String, dynamic> j) => _UserModel(
        id: j['id'] as String,
        username: j['username'] as String,
        fullName: j['fullName'] as String,
        role: j['role'] as String,
        isActive: j['isActive'] as bool? ?? true,
      );
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final RxList<_UserModel> users = <_UserModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    isLoading.value = true;
    try {
      final data = await ApiService.get('users');
      users.value = (data as List).map((j) => _UserModel.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _showError('خطأ في تحميل المستخدمين: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.kPagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.manage_accounts_rounded, color: const Color(0xFFFF6584), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         DesignTokens.holographicText(
                           text: 'إدارة المستخدمين',
                           style: const TextStyle(fontSize: 20),
                         ),
                        Text('إضافة وتعديل وإدارة صلاحيات المستخدمين', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showUserDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('مستخدم جديد'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                  ),
                ],
              ).animate().fadeIn(),

              const SizedBox(height: 24),

              // ── Users Table ──────────────────────────────────────
              Expanded(
                child: Obx(() {
                  if (isLoading.value) return const Center(child: CircularProgressIndicator());

                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off_rounded, size: 80, color: Colors.grey.withAlpha(80)),
                          const SizedBox(height: 16),
                          const Text('لا يوجد مستخدمون', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(15),
                          ),
                          columns: const [
                            DataColumn(label: Text('الاسم الكامل', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('اسم المستخدم', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('الدور', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('إجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: users.asMap().entries.map((entry) {
                            final u = entry.value;
                            return DataRow(cells: [
                              DataCell(Row(children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _roleColor(u.role).withAlpha(40),
                                  child: Text(u.fullName.isNotEmpty ? u.fullName[0] : '?',
                                      style: TextStyle(color: _roleColor(u.role), fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                Text(u.fullName),
                              ])),
                              DataCell(Text('@${u.username}', style: TextStyle(color: Colors.grey[500]))),
                              DataCell(_RoleBadge(role: u.role)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: u.isActive ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    u.isActive ? 'نشط' : 'موقوف',
                                    style: TextStyle(color: u.isActive ? Colors.green : Colors.red, fontSize: 12),
                                  ),
                                ),
                              ),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 18),
                                    tooltip: 'تعديل',
                                    color: Colors.blue,
                                    onPressed: () => _showUserDialog(context, user: u),
                                  ),
                                  IconButton(
                                    icon: Icon(u.isActive ? Icons.block_rounded : Icons.check_circle_rounded, size: 18),
                                    tooltip: u.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
                                    color: u.isActive ? Colors.orange : Colors.green,
                                    onPressed: () => _toggleActive(u.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.lock_reset_rounded, size: 18),
                                    tooltip: 'إعادة تعيين كلمة المرور',
                                    color: Colors.purple,
                                    onPressed: () => _showResetPasswordDialog(context, u),
                                  ),
                                ],
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showUserDialog(BuildContext context, {_UserModel? user}) {
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = user?.role ?? 'Cashier';
    final isEdit = user != null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(isEdit ? 'تعديل مستخدم' : 'مستخدم جديد'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            if (!isEdit) ...[
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.alternate_email))),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock)), obscureText: true),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'الدور'),
              items: const [
                DropdownMenuItem(value: 'Admin', child: Text('مدير')),
                DropdownMenuItem(value: 'Manager', child: Text('مشرف')),
                DropdownMenuItem(value: 'Cashier', child: Text('كاشير')),
              ],
              onChanged: (v) => selectedRole = v ?? 'Cashier',
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (isEdit) {
                await _updateUser(user!.id, nameCtrl.text, selectedRole);
              } else {
                await _createUser(usernameCtrl.text, nameCtrl.text, passCtrl.text, selectedRole);
              }
            },
            child: Text(isEdit ? 'حفظ' : 'إنشاء'),
          ),
        ],
      )),
    );
  }

  void _showResetPasswordDialog(BuildContext context, _UserModel user) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('إعادة تعيين كلمة مرور: ${user.fullName}'),
        content: TextField(
          controller: passCtrl,
          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: Icon(Icons.lock)),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetPassword(user.id, passCtrl.text);
            },
            child: const Text('تعيين'),
          ),
        ],
      ),
    );
  }

  // ── API Calls ─────────────────────────────────────────────────────────────

  Future<void> _createUser(String username, String fullName, String password, String role) async {
    try {
      await ApiService.post('users', {'username': username, 'fullName': fullName, 'password': password, 'role': role});
      _showSuccess('تم إنشاء المستخدم بنجاح');
      _loadUsers();
    } catch (e) {
      _showError('فشل إنشاء المستخدم: $e');
    }
  }

  Future<void> _updateUser(String id, String fullName, String role) async {
    try {
      await ApiService.put('users/$id', {'fullName': fullName, 'role': role});
      _showSuccess('تم تحديث بيانات المستخدم');
      _loadUsers();
    } catch (e) {
      _showError('فشل التحديث: $e');
    }
  }

  Future<void> _toggleActive(String id) async {
    try {
      await ApiService.patch('users/$id/toggle-active', {});
      _loadUsers();
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  Future<void> _resetPassword(String id, String newPass) async {
    try {
      await ApiService.post('users/$id/reset-password', {'newPassword': newPass});
      _showSuccess('تم إعادة تعيين كلمة المرور');
    } catch (e) {
      _showError('فشل إعادة التعيين: $e');
    }
  }

  Color _roleColor(String role) => switch (role) {
        'Admin' => Colors.red,
        'Manager' => Colors.orange,
        _ => Colors.blue,
      };

  void _showSuccess(String msg) => Get.snackbar('نجاح', msg, backgroundColor: Colors.green.withAlpha(200), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
  void _showError(String msg) => Get.snackbar('خطأ', msg, backgroundColor: Colors.red.withAlpha(200), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (role) {
      'Admin' => (Colors.red, 'مدير'),
      'Manager' => (Colors.orange, 'مشرف'),
      _ => (Colors.blue, 'كاشير'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
