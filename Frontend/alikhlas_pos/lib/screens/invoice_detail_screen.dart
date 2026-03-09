// Invoice Detail Screen — Redesigned to match mockup
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/invoice_model.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  InvoiceModel? _invoice;
  bool _loading = true;
  String? _error;
  bool _reprinting = false;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.get('invoices/${widget.invoiceId}');
      setState(() {
        _invoice = InvoiceModel.fromJson(data as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'تعذّر تحميل الفاتورة'; _loading = false; });
    }
  }

  Future<void> _reprint() async {
    final inv = _invoice;
    if (inv == null) return;
    setState(() => _reprinting = true);
    try {
      await ReceiptService.printReceipt(
        invoiceNo: inv.invoiceNo,
        date: inv.createdAt,
        items: inv.items.map((i) => CartItemModel(
          barcode: '', productId: i.productId, productName: i.productName,
          unitPrice: i.unitPrice, quantity: i.quantity.toInt(),
        )).toList(),
        subTotal: inv.subTotal,
        discountAmount: inv.discountAmount ?? 0,
        vatAmount: inv.vatAmount,
        totalAmount: inv.totalAmount,
        paidAmount: inv.paidAmount,
        remaining: inv.remainingAmount,
        paymentType: inv.paymentType.index.toString(),
        customerName: inv.customerName,
      );
      if (mounted) {
        Get.snackbar('طباعة', 'تم إرسال الفاتورة للطابعة ✓',
            backgroundColor: Colors.green, colorText: Colors.white);
      }
    } catch (_) {
      if (mounted) {
        Get.snackbar('خطأ', 'تعذّر الاتصال بالطابعة',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } finally {
      if (mounted) setState(() => _reprinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? DesignTokens.bgDark : const Color(0xFFF0F4F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_invoice == null ? 'تفاصيل الفاتورة' : _invoice!.invoiceNo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadInvoice,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    final inv = _invoice!;
    final paymentLabels = ['نقدي', 'بطاقة', 'آجل/تقسيط'];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.kCardRadius),
            border: Border.all(color: isDark ? DesignTokens.neonPurple.withAlpha(30) : Colors.grey.withAlpha(20)),
            boxShadow: [
              BoxShadow(
                color: isDark ? DesignTokens.neonPurple.withAlpha(15) : Colors.black.withAlpha(8),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Invoice Header with Branding ──
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [DesignTokens.surfaceDark, DesignTokens.cardDark]
                        : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Invoice Info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('فاتورة رقم: ', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                            Text(inv.invoiceNo,
                                style: const TextStyle(color: DesignTokens.neonCyan, fontWeight: FontWeight.w900, fontSize: 22)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('التاريخ: ${_formatDate(inv.createdAt)}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            const SizedBox(width: 16),
                            Text('العميل: ${inv.customerName ?? 'عميل مباشر'}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    // Brand Logo
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: DesignTokens.neonPurple, size: 24),
                            const SizedBox(width: 8),
                            const Text('ALIkhlas POS',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.05),

              // ── Items Table ──
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('الاسم', style: _headerStyle(isDark))),
                          Expanded(flex: 1, child: Text('الكمية', style: _headerStyle(isDark), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('السعر', style: _headerStyle(isDark), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('الإجمالي', style: _headerStyle(isDark), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Table Rows
                    ...inv.items.map((item) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15))),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text(item.productName,
                              style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                          Expanded(flex: 1, child: Text('${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)}',
                              style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('${item.unitPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('${item.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        ],
                      ),
                    )),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),

              // ── Summary + QR ──
              Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(8),
                  borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
                  border: Border.all(color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Financial Summary
                    Expanded(
                      child: Column(
                        children: [
                          _summaryRow('المجموع الفرعي', '${inv.subTotal.toStringAsFixed(2)}', isDark),
                          if (inv.discountAmount != null && inv.discountAmount! > 0)
                            _summaryRow('الخصم', '- ${inv.discountAmount!.toStringAsFixed(2)}', isDark,
                                valueColor: DesignTokens.neonRed),
                          if (inv.vatAmount > 0)
                            _summaryRow('الضريبة (${inv.vatRate.toStringAsFixed(0)}٪)', '${inv.vatAmount.toStringAsFixed(2)}', isDark),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text('${inv.totalAmount.toStringAsFixed(2)} ج.م',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 26,
                                    color: DesignTokens.neonGreen,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: inv.invoiceNo,
                        version: QrVersions.auto,
                        size: 90,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),

              // ── Print Button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _reprinting ? null : _reprint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.neonPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.kButtonRadius)),
                    ),
                    icon: const Icon(Icons.print_rounded),
                    label: _reprinting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('طباعة الفاتورة',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(value, style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          )),
        ],
      ),
    );
  }

  TextStyle _headerStyle(bool isDark) => TextStyle(
    fontWeight: FontWeight.w700, fontSize: 12,
    color: isDark ? Colors.grey[400] : Colors.grey[600],
  );

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
