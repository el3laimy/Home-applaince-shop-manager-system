class Shift {
  final String id;
  final String cashierId;
  final DateTime startTime;
  final DateTime? endTime;
  final double openingCash;
  final double totalSales;
  final double totalCashIn;
  final double totalCashOut;
  final double expectedCash;
  final double actualCash;
  final double difference;
  final int status; // 0 = Open, 1 = Closed
  final String? notes;

  Shift({
    required this.id,
    required this.cashierId,
    required this.startTime,
    this.endTime,
    required this.openingCash,
    required this.totalSales,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.expectedCash,
    required this.actualCash,
    required this.difference,
    required this.status,
    this.notes,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      cashierId: json['cashierId'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      openingCash: (json['openingCash'] as num).toDouble(),
      totalSales: (json['totalSales'] as num).toDouble(),
      totalCashIn: (json['totalCashIn'] as num).toDouble(),
      totalCashOut: (json['totalCashOut'] as num).toDouble(),
      expectedCash: (json['expectedCash'] as num).toDouble(),
      actualCash: (json['actualCash'] as num).toDouble(),
      difference: (json['difference'] as num).toDouble(),
      status: json['status'],
      notes: json['notes'],
    );
  }
}
