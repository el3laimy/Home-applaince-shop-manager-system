import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/customer_model.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/toast_service.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/neo_button.dart';
import '../core/widgets/neo_text_field.dart';
import '../core/widgets/neo_data_table.dart';
import '../core/widgets/neo_dialog.dart';
import '../controllers/customer_controller.dart';
import 'customer_profile_screen.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CustomerController>();

    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.kPagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DesignTokens.holographicText(
                        text: 'إدارة العملاء',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Obx(() => Text(
                        'إجمالي: ${ctrl.totalCount.value} عميل',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      )),
                    ],
                  ).animate().fade().slideX(begin: 0.05),
                  NeoButton(
                    label: 'إضافة عميل',
                    icon: Icons.person_add_rounded,
                    color: DesignTokens.neonCyan,
                    onPressed: () => _showAddDialog(context, ctrl),
                  ).animate().fade(),
                ],
              ),
              const SizedBox(height: 24),

              // ── Customer List Panel ─────────────────────────────────
              Expanded(
                child: _buildCustomerList(context, ctrl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerList(BuildContext context, CustomerController ctrl) {
    return DesignTokens.neoGlassBox(
      borderRadius: DesignTokens.kNeoCardRadius,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Search + Sort bar ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                // Search
                Expanded(
                  child: NeoTextField(
                    hint: 'بحث بالاسم أو الهاتف...',
                    icon: Icons.search,
                    onChanged: (v) => ctrl.fetch(search: v),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort chips
                Obx(() => Row(
                  children: [
                    Icon(Icons.sort, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    _sortChip(ctrl, 'name', 'أبجدي'),
                    const SizedBox(width: 6),
                    _sortChip(ctrl, 'balance', 'أعلى رصيد'),
                    const SizedBox(width: 6),
                    _sortChip(ctrl, 'newest', 'الأحدث'),
                  ],
                )),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: Colors.white.withAlpha(10)),

          // ── Customer Tiles ─────────────────────────────────
          Expanded(
            child: Obx(() {
              if (ctrl.isLoading.value && ctrl.customers.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: DesignTokens.neonCyan));
              }
              if (ctrl.customers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: Colors.white.withAlpha(30)),
                      const SizedBox(height: 12),
                      Text('لا يوجد عملاء', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                );
              }
              return NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollEndNotification &&
                      n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                    ctrl.loadMore();
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: ctrl.customers.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == ctrl.customers.length) {
                      return Obx(() {
                        if (ctrl.isLoadingMore.value) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: DesignTokens.neonCyan)),
                          );
                        }
                        if (!ctrl.hasMore && ctrl.customers.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(child: Text(
                              'تم عرض جميع العملاء (${ctrl.totalCount.value})',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            )),
                          );
                        }
                        return const SizedBox.shrink();
                      });
                    }
                    return Obx(() {
                      final c = ctrl.customers[i];
                      return NeoListTile(
                        title: c.name,
                        subtitle: c.phone ?? 'بدون رقم',
                        icon: Icons.person_rounded,
                        iconColor: _customerColor(i),
                        isSelected: ctrl.selected.value?.id == c.id,
                        onTap: () {
                          ctrl.selected.value = c;
                          Get.to(() => CustomerProfileScreen(customer: c));
                        },
                        trailing: c.balance > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: DesignTokens.neonRed.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${AppFormatters.currency(c.balance)}',
                                  style: const TextStyle(
                                    color: DesignTokens.neonRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      );
                    });
                  },
                ),
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _sortChip(CustomerController ctrl, String value, String label) {
    final isActive = ctrl.sortBy.value == value;
    return GestureDetector(
      onTap: () => ctrl.changeSort(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? DesignTokens.neonCyan.withAlpha(25) : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? DesignTokens.neonCyan.withAlpha(80) : Colors.transparent,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 10,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? DesignTokens.neonCyan : Colors.grey[500],
        )),
      ),
    );
  }

  Color _customerColor(int index) {
    const colors = [
      DesignTokens.neonCyan,
      DesignTokens.neonPurple,
      DesignTokens.neonPink,
      DesignTokens.neonGreen,
      DesignTokens.neonBlue,
      DesignTokens.neonOrange,
    ];
    return colors[index % colors.length];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DIALOGS — using NeoDialog
  // ═══════════════════════════════════════════════════════════════════════════

  void _showAddDialog(BuildContext context, CustomerController ctrl) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    NeoDialog.showCustom(
      context,
      title: 'إضافة عميل جديد',
      accentColor: DesignTokens.neonCyan,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        NeoTextField(controller: nameCtrl, label: 'اسم العميل *', icon: Icons.person),
        const SizedBox(height: 14),
        NeoTextField(controller: phoneCtrl, label: 'رقم الهاتف', icon: Icons.phone, keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        NeoTextField(controller: addressCtrl, label: 'العنوان', icon: Icons.location_on),
        const SizedBox(height: 14),
        NeoTextField(controller: notesCtrl, label: 'ملاحظات', icon: Icons.notes, maxLines: 2),
      ]),
      actions: [
        NeoButton.outlined(
          label: 'إلغاء',
          color: Colors.grey,
          onPressed: () => Get.back(),
        ),
        const SizedBox(width: 12),
        NeoButton(
          label: 'حفظ',
          icon: Icons.save_rounded,
          color: DesignTokens.neonCyan,
          onPressed: () async {
            if (nameCtrl.text.isEmpty) {
              ToastService.showWarning('يرجى إدخال اسم العميل');
              return;
            }
            final ok = await ctrl.addCustomer(
              nameCtrl.text,
              phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
              addressCtrl.text.isEmpty ? null : addressCtrl.text,
              notesCtrl.text.isEmpty ? null : notesCtrl.text,
            );
            if (ok) Get.back();
          },
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, CustomerController ctrl, CustomerModel c) {
    final nameCtrl = TextEditingController(text: c.name);
    final phoneCtrl = TextEditingController(text: c.phone ?? '');
    final addressCtrl = TextEditingController(text: c.address ?? '');
    final notesCtrl = TextEditingController(text: c.notes ?? '');

    NeoDialog.showCustom(
      context,
      title: 'تعديل بيانات العميل',
      accentColor: DesignTokens.neonPurple,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        NeoTextField(controller: nameCtrl, label: 'اسم العميل *', icon: Icons.person),
        const SizedBox(height: 14),
        NeoTextField(controller: phoneCtrl, label: 'رقم الهاتف', icon: Icons.phone, keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        NeoTextField(controller: addressCtrl, label: 'العنوان', icon: Icons.location_on),
        const SizedBox(height: 14),
        NeoTextField(controller: notesCtrl, label: 'ملاحظات', icon: Icons.notes, maxLines: 2),
      ]),
      actions: [
        NeoButton.outlined(
          label: 'إلغاء',
          color: Colors.grey,
          onPressed: () => Get.back(),
        ),
        const SizedBox(width: 12),
        NeoButton(
          label: 'حفظ',
          icon: Icons.save_rounded,
          color: DesignTokens.neonPurple,
          onPressed: () async {
            if (nameCtrl.text.isEmpty) return;
            final ok = await ctrl.updateCustomer(
              c.id,
              nameCtrl.text,
              phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
              addressCtrl.text.isEmpty ? null : addressCtrl.text,
              notesCtrl.text.isEmpty ? null : notesCtrl.text,
            );
            if (ok) Get.back();
          },
        ),
      ],
    );
  }

  void _showDeleteConfirm(BuildContext context, CustomerController ctrl, CustomerModel c) async {
    final confirmed = await NeoDialog.confirm(
      context,
      title: 'تأكيد حذف العميل',
      message: 'هل أنت متأكد من حذف العميل "${c.name}"?\nلن يتم حذف الفواتير السابقة.',
      confirmLabel: 'حذف',
      cancelLabel: 'إلغاء',
      accentColor: DesignTokens.neonRed,
    );
    if (confirmed) {
      await ctrl.deleteCustomer(c.id);
    }
  }
}
