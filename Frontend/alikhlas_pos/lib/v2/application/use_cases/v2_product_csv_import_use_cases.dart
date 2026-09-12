part of '../v2_use_cases.dart';

const _productCsvArabicHeaders = [
  'اسم المنتج',
  'الباركود',
  'التصنيف',
  'سعر البيع',
  'الرصيد الافتتاحي',
  'تكلفة الوحدة',
  'حد النقص',
];

const _productCsvEnglishHeaders = [
  'name',
  'barcode',
  'category',
  'sale_price',
  'opening_qty',
  'unit_cost',
  'min_stock_qty',
];

class ProductCsvImportRow {
  const ProductCsvImportRow({
    required this.sourceRow,
    required this.name,
    required this.barcode,
    required this.category,
    required this.salePriceMinor,
    required this.openingQty,
    required this.openingCostMinor,
    required this.minStockQty,
  });

  factory ProductCsvImportRow.fromJson(Map<String, dynamic> json) =>
      ProductCsvImportRow(
        sourceRow: json['sourceRow'] as int,
        name: json['name'] as String,
        barcode: json['barcode'] as String?,
        category: json['category'] as String?,
        salePriceMinor: json['salePriceMinor'] as int,
        openingQty: json['openingQty'] as int,
        openingCostMinor: json['openingCostMinor'] as int,
        minStockQty: json['minStockQty'] as int,
      );

  final int sourceRow;
  final String name;
  final String? barcode;
  final String? category;
  final int salePriceMinor;
  final int openingQty;
  final int openingCostMinor;
  final int minStockQty;

  Map<String, Object?> toJson() => {
    'sourceRow': sourceRow,
    'name': name,
    'barcode': barcode,
    'category': category,
    'salePriceMinor': salePriceMinor,
    'openingQty': openingQty,
    'openingCostMinor': openingCostMinor,
    'minStockQty': minStockQty,
  };
}

class ProductCsvRowIssue {
  const ProductCsvRowIssue({required this.sourceRow, required this.message});

  final int sourceRow;
  final String message;
}

class ProductCsvPreview {
  const ProductCsvPreview({required this.rows, required this.issues});

  final List<ProductCsvImportRow> rows;
  final List<ProductCsvRowIssue> issues;

  bool get canImport => rows.isNotEmpty && issues.isEmpty;
}

extension V2ProductCsvImportUseCases on V2UseCases {
  static const productCsvMaxBytes = 2 * 1024 * 1024;
  static const productCsvMaxRows = 2000;

  String newProductCsvImportOperationKey() => newFinancialOperationKey();

  String productCsvTemplate() =>
      '\ufeff${_productCsvArabicHeaders.map(_csvCell).join(',')}\r\n';

  Future<ProductCsvPreview> previewProductCsv(String source) async {
    final parsed = _parseProductCsv(source);
    if (parsed.rows.isEmpty) return parsed;
    final existingBarcodes = (await db.select(db.products).get())
        .map((product) => product.barcode)
        .whereType<String>()
        .toSet();
    final issues = [...parsed.issues];
    for (final row in parsed.rows) {
      if (row.barcode != null && existingBarcodes.contains(row.barcode)) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: row.sourceRow,
            message: 'الباركود مستخدم بالفعل في المخزون.',
          ),
        );
      }
    }
    issues.sort((left, right) => left.sourceRow.compareTo(right.sourceRow));
    return ProductCsvPreview(rows: parsed.rows, issues: issues);
  }

  Future<AppResult<int>> importProductCsv({
    String? operationKey,
    required List<ProductCsvImportRow> rows,
  }) {
    if (operationKey == null) {
      return Future.value(
        const AppFailure<int>('معرّف استيراد المنتجات مطلوب لمنع تكراره.'),
      );
    }
    final payload = rows.map((row) => row.toJson()).toList(growable: false);
    return _runIdempotentFinancialOperation(
      namespace: 'product_csv_import',
      operationKey: operationKey,
      fingerprintPayload: payload,
      conflictMessage:
          'طلب استيراد المنتجات محفوظ ببيانات مختلفة. راجع المخزون قبل المحاولة.',
      execute: () => _importProductCsv(rows),
    );
  }

  Future<AppResult<int>> _importProductCsv(
    List<ProductCsvImportRow> rows,
  ) async {
    final validationIssues = _validateProductCsvRows(rows);
    if (validationIssues.isNotEmpty) {
      return AppFailure<int>(
        'تعذر الاستيراد: الصف ${validationIssues.first.sourceRow}: '
        '${validationIssues.first.message}',
      );
    }
    final existingBarcodes = (await db.select(db.products).get())
        .map((product) => product.barcode)
        .whereType<String>()
        .toSet();
    for (final row in rows) {
      if (row.barcode != null && existingBarcodes.contains(row.barcode)) {
        return AppFailure<int>(
          'تعذر الاستيراد: الصف ${row.sourceRow}: الباركود مستخدم بالفعل.',
        );
      }
    }

    return _writeTransaction(() async {
      final latestBarcodes = (await db.select(db.products).get())
          .map((product) => product.barcode)
          .whereType<String>()
          .toSet();
      for (final row in rows) {
        if (row.barcode != null && latestBarcodes.contains(row.barcode)) {
          return AppFailure<int>(
            'تعذر الاستيراد: الصف ${row.sourceRow}: الباركود مستخدم بالفعل.',
          );
        }
      }

      for (final row in rows) {
        final barcode = row.barcode ?? await _nextProductBarcode();
        final productId = await db
            .into(db.products)
            .insert(
              ProductsCompanion.insert(
                name: row.name,
                barcode: Value(barcode),
                category: Value(row.category),
                salePriceMinor: row.salePriceMinor,
                stockQty: Value(row.openingQty),
                avgCostMinor: Value(row.openingCostMinor),
                inventoryValueMinor: Value(
                  row.openingQty * row.openingCostMinor,
                ),
                minStockQty: Value(row.minStockQty),
              ),
            );
        if (row.openingQty == 0) continue;
        await db
            .into(db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                productId: productId,
                type: 'opening_stock',
                qtyDelta: row.openingQty,
                balanceAfter: row.openingQty,
                referenceType: 'opening_stock',
                referenceId: productId,
              ),
            );
        final valueMinor = row.openingQty * row.openingCostMinor;
        await _postLedger(
          referenceType: 'opening_stock',
          referenceId: productId,
          description: 'رصيد افتتاحي للمخزون من CSV',
          lines: [
            _LedgerLineDraft(AccountCodes.inventory, debitMinor: valueMinor),
            _LedgerLineDraft(AccountCodes.capital, creditMinor: valueMinor),
          ],
        );
      }
      return AppSuccess<int>(rows.length);
    });
  }

  ProductCsvPreview _parseProductCsv(String source) {
    if (utf8.encode(source).length > productCsvMaxBytes) {
      return const ProductCsvPreview(
        rows: [],
        issues: [
          ProductCsvRowIssue(
            sourceRow: 1,
            message: 'الملف أكبر من الحد المسموح وهو 2 ميجابايت.',
          ),
        ],
      );
    }
    final csvSource = source.startsWith('\ufeff')
        ? source.substring(1)
        : source;
    late final List<List<String>> records;
    try {
      records = _decodeCsvRecords(csvSource);
    } on FormatException catch (error) {
      return ProductCsvPreview(
        rows: const [],
        issues: [ProductCsvRowIssue(sourceRow: 1, message: error.message)],
      );
    }
    final nonBlank = [
      for (final (index, record) in records.indexed)
        if (record.any((cell) => cell.trim().isNotEmpty))
          (sourceRow: index + 1, cells: record),
    ];
    if (nonBlank.isEmpty) {
      return const ProductCsvPreview(
        rows: [],
        issues: [ProductCsvRowIssue(sourceRow: 1, message: 'ملف CSV فارغ.')],
      );
    }
    final header = [...nonBlank.first.cells];
    if (header.isNotEmpty) header[0] = header[0].replaceFirst('\ufeff', '');
    final normalizedHeader = header.map((cell) => cell.trim()).toList();
    if (!_sameStrings(normalizedHeader, _productCsvArabicHeaders) &&
        !_sameStrings(normalizedHeader, _productCsvEnglishHeaders)) {
      return const ProductCsvPreview(
        rows: [],
        issues: [
          ProductCsvRowIssue(
            sourceRow: 1,
            message: 'عناوين الأعمدة لا تطابق قالب منتجات الإخلاص.',
          ),
        ],
      );
    }
    if (nonBlank.length == 1) {
      return const ProductCsvPreview(
        rows: [],
        issues: [
          ProductCsvRowIssue(sourceRow: 2, message: 'لا توجد صفوف منتجات.'),
        ],
      );
    }
    if (nonBlank.length - 1 > productCsvMaxRows) {
      return const ProductCsvPreview(
        rows: [],
        issues: [
          ProductCsvRowIssue(
            sourceRow: 1,
            message: 'الملف يتجاوز الحد الأقصى وهو 2000 منتج.',
          ),
        ],
      );
    }

    final rows = <ProductCsvImportRow>[];
    final issues = <ProductCsvRowIssue>[];
    final seenBarcodes = <String>{};
    for (var index = 1; index < nonBlank.length; index += 1) {
      final sourceRow = nonBlank[index].sourceRow;
      final cells = nonBlank[index].cells;
      if (cells.length != _productCsvArabicHeaders.length) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message: 'عدد الأعمدة يجب أن يكون 7.',
          ),
        );
        continue;
      }
      final name = cells[0].trim();
      final barcode = _csvBlankToNull(cells[1]);
      final category = _csvBlankToNull(cells[2]);
      final salePriceMinor = _parseCsvMoney(cells[3]);
      final openingQty = _parseCsvInteger(cells[4]);
      final openingCostMinor = _parseCsvMoney(cells[5]);
      final minStockQty = _parseCsvInteger(cells[6]);
      if (name.isEmpty || name.length > 200) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message: 'اسم المنتج مطلوب ولا يزيد عن 200 حرف.',
          ),
        );
      }
      if (barcode != null && barcode.length > 100) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message: 'الباركود لا يزيد عن 100 حرف.',
          ),
        );
      } else if (barcode != null && !seenBarcodes.add(barcode)) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message: 'الباركود مكرر داخل الملف.',
          ),
        );
      }
      if (category != null && category.length > 100) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message: 'التصنيف لا يزيد عن 100 حرف.',
          ),
        );
      }
      if (salePriceMinor == null ||
          salePriceMinor <= 0 ||
          salePriceMinor > 999999999999) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message:
                'سعر البيع يجب أن يكون رقمًا أكبر من صفر وبحد أقصى منزلتين عشريتين.',
          ),
        );
      }
      if (openingQty == null || openingQty < 0 || openingQty > 1000000000) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message: 'الرصيد الافتتاحي يجب أن يكون عددًا صحيحًا غير سالب.',
          ),
        );
      }
      if (openingCostMinor == null ||
          openingCostMinor < 0 ||
          openingCostMinor > 999999999) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message:
                'تكلفة الوحدة يجب أن تكون رقمًا غير سالب وبحد أقصى منزلتين عشريتين.',
          ),
        );
      } else if ((openingQty ?? 0) > 0 && openingCostMinor == 0) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message: 'تكلفة الوحدة مطلوبة عندما يكون الرصيد أكبر من صفر.',
          ),
        );
      }
      if (minStockQty == null || minStockQty < 0 || minStockQty > 1000000000) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: sourceRow,
            message: 'حد النقص يجب أن يكون عددًا صحيحًا غير سالب.',
          ),
        );
      }
      if (issues.any((issue) => issue.sourceRow == sourceRow)) continue;
      rows.add(
        ProductCsvImportRow(
          sourceRow: sourceRow,
          name: name,
          barcode: barcode,
          category: category,
          salePriceMinor: salePriceMinor!,
          openingQty: openingQty!,
          openingCostMinor: openingCostMinor!,
          minStockQty: minStockQty!,
        ),
      );
    }
    return ProductCsvPreview(rows: rows, issues: issues);
  }

  List<ProductCsvRowIssue> _validateProductCsvRows(
    List<ProductCsvImportRow> rows,
  ) {
    if (rows.isEmpty || rows.length > productCsvMaxRows) {
      return const [
        ProductCsvRowIssue(
          sourceRow: 1,
          message: 'عدد صفوف المنتجات غير صالح.',
        ),
      ];
    }
    final issues = <ProductCsvRowIssue>[];
    final barcodes = <String>{};
    for (final row in rows) {
      if (row.sourceRow < 2 ||
          row.name.trim().isEmpty ||
          row.name != row.name.trim() ||
          row.name.length > 200 ||
          row.salePriceMinor <= 0 ||
          row.salePriceMinor > 999999999999 ||
          row.openingQty < 0 ||
          row.openingQty > 1000000000 ||
          row.openingCostMinor < 0 ||
          row.openingCostMinor > 999999999 ||
          (row.openingQty > 0 && row.openingCostMinor == 0) ||
          row.minStockQty < 0 ||
          row.minStockQty > 1000000000 ||
          (row.barcode?.length ?? 0) > 100 ||
          (row.category?.length ?? 0) > 100 ||
          (row.barcode != null && !barcodes.add(row.barcode!))) {
        issues.add(
          ProductCsvRowIssue(
            sourceRow: row.sourceRow,
            message: 'بيانات الصف غير صالحة أو الباركود مكرر.',
          ),
        );
      }
    }
    return issues;
  }
}

List<List<String>> _decodeCsvRecords(String source) {
  final records = <List<String>>[];
  var record = <String>[];
  var cell = StringBuffer();
  var inQuotes = false;
  var quoteClosed = false;
  for (var index = 0; index < source.length; index += 1) {
    final char = source[index];
    if (inQuotes) {
      if (char == '"') {
        if (index + 1 < source.length && source[index + 1] == '"') {
          cell.write('"');
          index += 1;
        } else {
          inQuotes = false;
          quoteClosed = true;
        }
      } else {
        cell.write(char);
      }
      continue;
    }
    if (quoteClosed && char != ',' && char != '\r' && char != '\n') {
      throw const FormatException('يوجد نص بعد علامة اقتباس مغلقة في CSV.');
    }
    if (char == '"') {
      if (cell.isNotEmpty) {
        throw const FormatException('علامة الاقتباس داخل خلية CSV غير صالحة.');
      }
      inQuotes = true;
      continue;
    }
    if (char == ',') {
      record.add(cell.toString());
      cell = StringBuffer();
      quoteClosed = false;
      continue;
    }
    if (char == '\r' || char == '\n') {
      record.add(cell.toString());
      records.add(record);
      record = <String>[];
      cell = StringBuffer();
      quoteClosed = false;
      if (char == '\r' &&
          index + 1 < source.length &&
          source[index + 1] == '\n') {
        index += 1;
      }
      continue;
    }
    cell.write(char);
  }
  if (inQuotes) {
    throw const FormatException('علامة اقتباس غير مغلقة في ملف CSV.');
  }
  if (cell.isNotEmpty || record.isNotEmpty || quoteClosed) {
    record.add(cell.toString());
    records.add(record);
  }
  return records;
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

String? _csvBlankToNull(String value) {
  final clean = value.trim();
  return clean.isEmpty ? null : clean;
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

int? _parseCsvInteger(String source) {
  final normalized = _normalizeCsvDigits(source).trim();
  if (!RegExp(r'^\d+$').hasMatch(normalized)) return null;
  return int.tryParse(normalized);
}

int? _parseCsvMoney(String source) {
  final normalized = _normalizeCsvDigits(
    source,
  ).trim().replaceAll('٬', '').replaceAll(' ', '').replaceAll('٫', '.');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) return null;
  final pounds = int.tryParse(match.group(1)!);
  if (pounds == null) return null;
  final fractionText = match.group(2) ?? '';
  final fraction = fractionText.isEmpty
      ? 0
      : int.parse(fractionText.padRight(2, '0'));
  return pounds * 100 + fraction;
}

String _normalizeCsvDigits(String source) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var result = source;
  for (var index = 0; index < 10; index += 1) {
    result = result
        .replaceAll(arabic[index], '$index')
        .replaceAll(persian[index], '$index');
  }
  return result;
}
