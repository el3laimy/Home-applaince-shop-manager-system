# Implementation batch 36 — Financial correction reversal documents

## Scope

- Added schema v11 and an immutable `financial_correction_reversals` document linked uniquely to its source correction.
- Added a reviewed owner flow in Settings that lists only unreversed corrections, requires a reason, preserves the source, and posts an exact inverse ledger entry.
- Added durable operation receipts, pending-operation recovery, negative-balance approval, and integrity-audit coverage for the reversal.

## Safety properties

- A correction can be reversed only once, even when a different operation key is used later.
- Replaying the same operation key returns the original reversal result; changing its payload is rejected.
- The original correction is never deleted or edited. The reversal has its own reason, optional note, timestamp, and ledger reference.
- Cash reversals require an open shift. If the inverse entry would make cash or wallet negative, the owner must approve that outcome explicitly.
- Failure to save the idempotency receipt rolls back the reversal document and both ledger lines in the same transaction.

## Validation

- `flutter analyze`: no issues found.
- Focused correction, UI, operation-key, and migration tests: 16 tests passed.
- Full `flutter test --reporter compact`: 183 tests passed.
- `flutter build linux`: release bundle built successfully.
- `git diff --check`: clean.

## Boundary

This batch reverses the dedicated cash/wallet financial-correction document. Sales, purchases, stock adjustments, installments, expenses, and returns retain their specialized document flows and are not editable through this command. Safe CSV import and field acceptance on clean Windows/Linux machines, physical printers/scanners, power loss, disk-full behavior, and a real shop pilot remain open.
