import 'api_service.dart';
import 'package:flutter/foundation.dart';

class AccountingApiService {
  static Future<List<dynamic>> getChartOfAccounts() async {
    try {
      final response = await ApiService.get('accounts/coa');
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('Error getting COA: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getTrialBalance({DateTime? from, DateTime? to}) async {
    try {
      String query = '';
      if (from != null) query += 'fromDate=${from.toUtc().toIso8601String()}&';
      if (to != null) query += 'toDate=${to.toUtc().toIso8601String()}&';
      if (query.isNotEmpty) query = '?$query';

      final response = await ApiService.get('accounts/trial-balance$query');
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting Trial Balance: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAccountLedger(String accountId, {DateTime? from, DateTime? to}) async {
    try {
      String query = '';
      if (from != null) query += 'fromDate=${from.toUtc().toIso8601String()}&';
      if (to != null) query += 'toDate=${to.toUtc().toIso8601String()}&';
      if (query.isNotEmpty) query = '?$query';

      final response = await ApiService.get('accounts/$accountId/ledger$query');
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting Account Ledger: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getIncomeStatement({DateTime? from, DateTime? to}) async {
    try {
      String query = '';
      if (from != null) query += 'fromDate=${from.toUtc().toIso8601String()}&';
      if (to != null) query += 'toDate=${to.toUtc().toIso8601String()}&';
      if (query.isNotEmpty) query = '?$query';

      final response = await ApiService.get('accounts/income-statement$query');
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting Income Statement: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getBalanceSheet({DateTime? asOf}) async {
    try {
      String query = '';
      if (asOf != null) query += '?asOfDate=${asOf.toUtc().toIso8601String()}';

      final response = await ApiService.get('accounts/balance-sheet$query');
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting Balance Sheet: $e');
      rethrow;
    }
  }

  static Future<bool> createManualJournalEntry(String description, String? reference, List<Map<String, dynamic>> lines) async {
    try {
      final response = await ApiService.post('accounts/journal-entry', {
        'description': description,
        'reference': reference,
        'lines': lines,
      });
      return response != null;
    } catch (e) {
      debugPrint('Error creating Journal Entry: $e');
      rethrow;
    }
  }
}
