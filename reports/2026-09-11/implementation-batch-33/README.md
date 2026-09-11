# Implementation batch 33 — Financial correction documents

## Scope

- Added schema v9 and a `financial_corrections` document for counted cash-drawer or wallet differences.
- Added the reviewed end-user flow in Settings, durable idempotency receipts, pending-operation recovery, a balanced ledger entry, integrity-audit coverage, and report/PDF visibility.

## Accounting policy

The document is limited to cash and wallet. A counted increase debits the selected liquid account and credits `financial_variance`; a shortage reverses those sides. The variance is included in profit calculations. A cash correction requires an open shift. A shortage that would make a liquid account negative requires explicit owner approval.

The flow cannot edit sales, purchases, stock, customer balances, or supplier balances. Each of those changes must use its specialized source document.

## Verified behavior

- Replaying a correction key returns the original document; a changed payload is rejected.
- A staged correction survives a database reopen and replays once.
- Receipt-write failure rolls back the document and both ledger lines.
- The data-integrity audit requires exactly one document and two partyless ledger lines with the expected amounts.
- The Settings flow reviews and saves a wallet correction on the compact desktop layout.

## Validation

- `dart analyze lib test/v2/financial_correction_idempotency_test.dart test/v2/financial_correction_ui_test.dart test/v2/financial_operation_key_required_test.dart test/v2/migration_safety_test.dart`: no issues found.
- `flutter test --no-pub test/v2/financial_correction_idempotency_test.dart --reporter expanded`: 4 tests passed.
- `flutter test --no-pub test/v2/financial_correction_ui_test.dart --reporter expanded`: 1 test passed.
- `flutter test --no-pub test/v2/financial_operation_key_required_test.dart test/v2/migration_safety_test.dart --reporter expanded`: 5 tests passed.

## Boundary

This is code and widget validation. Safe CSV import/export, a clean-device installer/upgrade/removal run for both desktop targets, physical printer and power-loss checks, Windows signing, and the end-user pilot remain release-acceptance work.
