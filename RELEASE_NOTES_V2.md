# ALIkhlasPOS v2 Release Notes

## Current v2 State

- `Frontend/alikhlas_pos/lib/main.dart` starts `ALIkhlasV2App` directly.
- Runtime is local Flutter Desktop + SQLite/drift.
- No runtime Backend, Docker, PostgreSQL, or Redis is required for v2.
- The pre-cleanup v1 state is archived in `archives/pre-v1-cleanup-working-tree.tar.gz`.
- Old backend and Flutter v1 runtime code have been removed from the active tree.

## Completed

- Local owner login with forced default password change.
- PBKDF2-SHA256 password hashing with legacy SHA-256 upgrade on login.
- SQLite WAL with `synchronous=FULL` and drift schema version 8.
- Schema v5 adds `products.imagePath`; schema v6 adds auditable inventory-adjustment documents; schema v7 adds opening-balance documents; schema v8 adds purchase-return documents and lines.
- Ledger-based sales, purchases, expenses, installments, returns, shifts, and reports.
- Sale returns handle installment over-refund correctly:
  - receivable settlement is capped at remaining customer debt;
  - overflow is refunded separately by cash or wallet;
  - cash overflow requires an open shift.
- Expense records are stored in an `expenses` table and posted to the ledger.
- Backup uses `VACUUM INTO`, keeps the latest 30 backup files, and restore clears WAL/SHM sidecar files.
- Liquid Glass daily operations UI covers dashboard, POS, inventory, parties, purchases, installments, returns, reports, backup, and settings.
- Apple/iOS-inspired Liquid Glass polish now uses bundled Cairo Arabic fonts, shared theme tokens, stronger glass contrast, opt-in real blur, and golden coverage for login/dashboard/POS/reports surfaces.
- Sale receipt, party statement, and report PDFs use the bundled Cairo font assets without loading fonts at print time.
- Product images and custom background images are copied into the application data directory before saving their paths.
- Party statements show invoice totals, paid amounts, remaining balances, invoice items, payments, and sale installment details in the UI and PDF output.
- Party statement invoice details now derive current paid/remaining values from direct payments, installment-plan payments, and sale returns instead of stale invoice snapshots.
- Barcode label printing defaults to 40x30mm, can be adjusted from Settings, and supports both incoming-stock labels and reprinting an existing product label from Inventory.
- Windows and Linux release bundles can be produced from the `Desktop Release Build` GitHub Actions workflow.
- Debian artifacts now validate their runtime dependencies, extracted launcher, desktop entry, icon, and shared-library resolution before upload; GTK is compatible with both the pre-24.04 and Ubuntu 24.04 package names.
- Sale returns keep installment interest as non-refundable by default; any interest refund must be posted later as an explicit manual settlement.
- Purchases reject zero unit cost at the use-case boundary, not only in the UI.
- Partial installment payments are shown as partial in statement details and PDFs with paid/remaining amounts.
- Money input parsing is centralized around integer minor units, accepts Arabic and English digits, and blocks invalid text before any workflow is posted.
- A full owner operating-day test covers login/change password, shift, purchase, sale, installment collection, return, close shift, and backup.
- Sale and purchase drafts survive restart without posting financial records and warn before leaving unsaved edits.
- Financial mutations use durable operation receipts and recoverable pending requests to prevent duplicate posting after rapid taps or a lost reply.
- Opening balances use the same receipt, payload-conflict, rollback, and pending-recovery contract as the other financial mutations.
- Existing shops can enter reviewed customer, supplier, cash, or wallet opening balances from Settings; customer and supplier balances create one collectible/payable installment, while cash and wallet remain separate from the physical opening-shift count.
- Inventory reconciliation records the counted quantity, reason, stock movement, ledger variance, and idempotency receipt in one transaction.
- Purchase returns select the original purchase invoice, prevent returning more than the original or current stock, and can reduce supplier debt or receive cash/wallet credit. They preserve the original supplier cost while valuing the stock removal at current WAC and post the difference to inventory variance.

## Verification

Last verified commands:

```bash
cd Frontend/alikhlas_pos
dart analyze lib/v2 lib/main.dart test/v2
flutter test
HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux
```

The v2 test suite covers:

- first launch, login, and forced password change;
- open/close shift;
- product creation and stock validation;
- cash, wallet, and installment sale paths;
- purchase and WAC update;
- installment collection and supplier payment;
- expenses;
- partial returns and installment return overflow;
- backup/restore and v3/v4 to v8 migration.
- inventory-adjustment accounting, recovery, integrity checks, and minimum-window UI coverage.
- Cairo theme, glass contrast, centralized blur, and visual golden snapshots for login/dashboard/POS/reports.
- party statement PDF smoke coverage with invoice details.
- local image copy coverage for product and background images.

## Remaining

- Validate Windows build on a Windows machine or Windows CI.
- Validate printed sale receipts and party statements on the target thermal/A4 printers.
- Sign and field-test the Windows installer and clean-install/upgrade/remove the Debian package before end-user release.
