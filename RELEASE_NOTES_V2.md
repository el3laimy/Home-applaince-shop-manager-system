# ALIkhlasPOS v2 Release Notes

الإصدار المرشح الحالي: `1.1.0+10`، مخطط قاعدة البيانات `11`.

## Current v2 State

- `Frontend/alikhlas_pos/lib/main.dart` starts `ALIkhlasV2App` directly.
- Runtime is local Flutter Desktop + SQLite/drift.
- No runtime Backend, Docker, PostgreSQL, or Redis is required for v2.
- The pre-cleanup v1 state is archived locally in the ignored file `archives/pre-v1-cleanup-working-tree.tar.gz`.
- Old backend and Flutter v1 runtime code have been removed from the active tree.

## Completed

- First-run owner creation with a user-chosen password; legacy default-owner accounts are forced to change their password.
- PBKDF2-SHA256 password hashing with legacy SHA-256 upgrade on login.
- SQLite WAL with `synchronous=FULL` and drift schema version 11.
- The supported migration chain covers product images, inventory adjustments, opening balances, purchase returns, financial corrections, exact inventory value, and correction-reversal documents through schema v11.
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
- Exact inventory value is stored separately from the rounded displayed WAC so clearing the final units also clears the inventory ledger value without minor-unit drift.
- Financial corrections can be reversed through a separate immutable document and balanced reversing entry; the original history is retained.
- Product and opening-stock CSV import validates a UTF-8 Arabic template, previews row errors, and commits the reviewed batch atomically with operation-receipt protection.
- Login and recovery attempts are throttled, and current password hashes use PBKDF2-HMAC-SHA256 with 600,000 iterations.
- Unexpected failures are written to a bounded local JSONL diagnostic log that omits exception messages, customer data, file paths, and raw operation keys.
- Windows NSIS and Linux Debian packages pass automated install, upgrade, uninstall, reinstall, launch, and user-data-retention checks in `Desktop Release Build`.

## Verification

Last verified commands:

```bash
cd Frontend/alikhlas_pos
dart analyze lib test/v2 tool/production_scale_benchmark.dart
flutter test --no-pub
flutter build linux --release --no-pub --dart-define=APP_GIT_SHA=local-check
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
- backup/restore and v3/v4 to v11 migration.
- inventory-adjustment accounting, recovery, integrity checks, and minimum-window UI coverage.
- Cairo theme, glass contrast, centralized blur, and visual golden snapshots for login/dashboard/POS/reports.
- party statement PDF smoke coverage with invoice details.
- local image copy coverage for product and background images.

## Remaining before commercial release

- Run `FIELD_ACCEPTANCE_AR.md` on the actual Windows and Linux delivery devices.
- Validate sale receipts, A4 statements, barcode labels, and scanning on the target physical devices.
- Exercise an external backup destination, a representative old shop database, forced close/power loss, and a full filesystem on disposable test data.
- Complete a controlled pilot with a non-technical shop user and resolve all blocking observations.
- Approve the publisher identity, sign the Windows installer, check SmartScreen behavior, and publish the support contact and response hours.
