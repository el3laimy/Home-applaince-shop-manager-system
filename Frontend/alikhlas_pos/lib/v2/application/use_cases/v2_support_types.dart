part of '../v2_use_cases.dart';

class _LedgerLineDraft {
  const _LedgerLineDraft(
    this.accountCode, {
    this.debitMinor = 0,
    this.creditMinor = 0,
    this.partyType,
    this.partyId,
  });

  final String accountCode;
  final int debitMinor;
  final int creditMinor;
  final String? partyType;
  final int? partyId;
}

class _BusinessError implements Exception {
  const _BusinessError(this.message);
  final String message;
}

class _ConfirmationRequired implements Exception {
  const _ConfirmationRequired(this.result);
  final AppConfirmationRequired<int> result;
}
