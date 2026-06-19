# ALIkhlasPOS v2 Tasks

This task list is derived from `IMPLEMENTATION_PLAN.md`.

Status legend:

- `[ ]` Not started.
- `[~]` In progress.
- `[x]` Done.
- `[!]` Blocked or needs decision.

## Phase 0: Preparation

- [x] Confirm the current branch is correct for v2 work.
- [x] Confirm `git status --short` and note any unrelated user changes before editing.
- [x] Run or inspect the current baseline checks before the first fix when practical.
- [x] Keep `IMPLEMENTATION_PLAN.md` as the strategy document and this file as the execution tracker.

## Phase 1: Critical Data Correctness

Review skill after implementation:

- `clean-code-guard`
- `test-guard`

### 1.1 Fix Installment Sale Returns

- [x] Inspect the current `createSaleReturn` implementation.
- [x] Locate the installment plan and installment payment schema in drift.
- [x] Add logic to detect installment sales during returns.
- [x] Calculate the exact return amount in minor units.
- [x] Calculate the customer's remaining receivable before applying the return.
- [x] Split the return into `receivableSettlementMinor = min(returnAmount, remainingReceivable)` and `overflowRefundMinor = returnAmount - receivableSettlementMinor`.
- [x] Reduce the installment plan total by `receivableSettlementMinor`, not by the full return amount when the return is greater than the remaining receivable.
- [x] If `overflowRefundMinor > 0`, route the excess to a separate cash or wallet refund path.
- [x] Require an open shift when the excess refund path uses cash.
- [x] Keep already paid installment payments unchanged.
- [x] Recalculate unpaid installments from the new remaining balance.
- [x] Put any rounding difference into the last unpaid installment.
- [x] Close the installment plan when remaining balance reaches zero.
- [x] Ensure ledger receivable reduction equals the installment plan reduction and never exceeds the remaining receivable.
- [x] Add tests for partial installment return.
- [x] Add tests for full installment return.
- [x] Add tests for return after one or more installment payments.
- [x] Add test for return amount greater than remaining customer receivable.
- [x] Add test proving customer statement matches installment remaining balance.

Acceptance:

- [x] Partial return reduces both ledger receivable and installment remaining balance.
- [x] Full return closes the installment plan.
- [x] Return greater than remaining receivable only closes the receivable up to the remaining balance.
- [x] Return excess above remaining receivable is refunded through cash or wallet separately.
- [x] Cash excess refund requires an open shift.
- [x] Installment plan reduction equals the receivable ledger reduction, not the full return amount when there is an excess refund.
- [x] Ledger entries remain balanced.

### 1.2 Require Open Shift For Cash Returns

- [x] Add open-shift validation when sale return refund method is cash.
- [x] Return a clear business error if there is no open shift.
- [x] Ensure cash return affects close-shift expected cash.
- [x] Add test for cash return without open shift.
- [x] Add test for cash return with open shift.
- [x] Add test for close-shift calculation after sale and return.

Acceptance:

- [x] Cash behavior is consistent across sales, purchases, expenses, and returns.

### 1.3 Document And Test WAC Return Policy

- [x] Add a short code comment explaining the v2 sale-return WAC policy.
- [x] Confirm return inventory reversal uses original `SaleItem.unitCost`.
- [x] Add test proving COGS reversal uses historical unit cost.
- [x] Add or update documentation text for the WAC return policy.

Acceptance:

- [x] Return cost policy is explicit.
- [x] Return cost policy is covered by test.

## Phase 2: Safe Backup And Restore

Review skill after implementation:

- `clean-code-guard`
- `test-guard`

### 2.1 Make Restore Safe With SQLite WAL

- [x] Inspect current `backupToDirectory` and `restoreFromBackup`.
- [x] Confirm the app database path resolution method.
- [x] Run `PRAGMA wal_checkpoint(TRUNCATE)` before restore.
- [x] Close the active database before file replacement.
- [x] Create a temporary rollback copy of the current database before overwrite.
- [x] Delete target `<database>-wal` file if it exists.
- [x] Delete target `<database>-shm` file if it exists.
- [x] Copy the backup database over the target database.
- [x] Reopen the database safely or require application restart.
- [x] Restore the rollback copy if replacement fails.
- [x] Return clear success and failure results to the UI.
- [x] Add test for backup then restore.
- [x] Add test for restore with stale WAL and SHM files.
- [x] Add test for failed restore rollback.
- [x] Add or verify test for keeping the last 30 automatic backups.

Acceptance:

- [x] Restore cannot be polluted by old WAL/SHM files.
- [x] Restore returns the exact backed-up state.
- [x] Failed restore does not leave the app unusable.

## Phase 3: Password Security

Review skill after implementation:

- `clean-code-guard`
- `test-guard`

### 3.1 Replace Legacy SHA-256 With Versioned PBKDF2

- [x] Inspect current password hash, login, bootstrap, and change-password code.
- [x] Implement PBKDF2-HMAC-SHA256 hashing.
- [x] Use hash format `pbkdf2_sha256$120000$base64Salt$base64Hash`.
- [x] Generate a random salt per password.
- [x] Verify PBKDF2 hashes on login.
- [x] Keep legacy SHA-256 verification for existing users.
- [x] Upgrade legacy hashes after successful login.
- [x] Ensure `changePassword` always writes PBKDF2 format.
- [x] Ensure bootstrap user creation writes PBKDF2 format.
- [x] Add test that the same password creates different hashes.
- [x] Add test for PBKDF2 login success.
- [x] Add test for legacy login and automatic upgrade.
- [x] Add test for wrong password rejection.

Acceptance:

- [x] No new password is stored as plain SHA-256.
- [x] Existing local owner accounts still work.

## Phase 4: Database Performance And Query Correctness

Review skill after implementation:

- `clean-code-guard`
- `test-guard`

### 4.1 Add Useful Indexes

- [x] Inspect current drift schema version and migration strategy.
- [x] Confirm the actual ledger date column before adding date indexes or date-range aggregate queries; as of this plan update, the verified column is `LedgerEntries.createdAt`.
- [x] Add index for `LedgerLines.entryId`.
- [x] Add index for `LedgerLines.accountCode`.
- [x] Add composite index for `LedgerLines.partyType + partyId`.
- [x] Add index for `LedgerEntries.createdAt`.
- [x] Add composite index for `LedgerEntries.referenceType + referenceId`.
- [x] Add index for `StockMovements.productId`.
- [x] Add composite index for `StockMovements.referenceType + referenceId`.
- [x] Add composite index for `Payments.ownerType + ownerId`.
- [x] Add composite index for `InstallmentPayments.planId + dueDate`.
- [x] Add index for `SaleItems.saleId`.
- [x] Add migration coverage for the new indexes.
- [x] Add or update schema migration tests if available.

Acceptance:

- [x] Existing databases upgrade cleanly.
- [x] Indexes exist after migration.

### 4.2 Use SQL Aggregates For Balances

- [x] Inspect current account balance helpers.
- [x] Replace account balance row folding with SQL `SUM`.
- [x] Replace account net since/between calculations with SQL `SUM`.
- [x] Replace party balance calculations with grouped SQL aggregates.
- [x] Preserve existing debit/credit sign conventions.
- [x] Add account balance equivalence tests.
- [x] Add party balance equivalence tests.
- [x] Add daily summary equivalence tests.
- [x] Add a larger fixture test for basic performance confidence.

Acceptance:

- [x] User-facing balances stay the same.
- [x] Balance queries avoid loading unnecessary ledger rows into Dart.

## Phase 5: Expense Entity

Review skill after implementation:

- `clean-code-guard`
- `test-guard`

### 5.1 Add First-Class Expenses Table

- [x] Add `Expenses` drift table.
- [x] Add fields: `id`, `description`, `amountMinor`, `method`, `createdAt`.
- [x] Add migration for the new table.
- [x] Update `recordExpense` to insert an expense row first.
- [x] Use `expense.id` as the ledger `referenceId`.
- [x] Keep ledger as the financial source of truth.
- [x] Add expense list/query support if needed by UI reports.
- [x] Add test for cash expense.
- [x] Add test for wallet expense.
- [x] Add test for cash expense without shift.
- [x] Add test for balanced expense ledger entry.
- [x] Add test that expense report totals match ledger totals.

Acceptance:

- [x] Every new expense has a real expense row.
- [x] Expense reports can show actual expense records.

## Phase 6: UI Test Stabilization

Review skill after implementation:

- `frontend-design`
- `clean-code-guard`
- `test-guard`

### 6.1 Fix `ListTile` Material Assertion

- [x] Reproduce or confirm the current `ListTile` assertion.
- [x] Add `Material(type: MaterialType.transparency)` inside `_GlassPane`.
- [x] Cover affected `ListTile` widgets through the shared Liquid Glass pane.
- [x] Avoid redesigning the UI in this fix.
- [x] Run widget tests.

Acceptance:

- [x] Dashboard and affected screens render without `ListTile` assertion.
- [x] No visible Liquid Glass regression is introduced.

## Phase 7: Liquid Glass Daily Operations UI

Primary skill:

- `frontend-design`

Review skills:

- `clean-code-guard`
- `test-guard`

### 7.1 App Shell And Navigation

- [x] Confirm all v2 daily sections are reachable from the main shell.
- [x] Keep the first screen as the working dashboard, not a landing page.
- [x] Ensure navigation includes POS, inventory, customers, suppliers, installments, reports, backup, and settings.
- [x] Keep layout dense, readable, and suitable for repeated shop use.

### 7.2 POS Improvements

- [x] Improve product search speed and clarity.
- [x] Prioritize barcode-first entry flow.
- [x] Make cart quantity editing stable.
- [x] Make item removal obvious.
- [x] Support mixed payment clearly.
- [x] Show clear errors for insufficient stock.
- [x] Show clear errors for missing shift when cash is used.
- [x] Show clear errors for invalid amount and overpayment.
- [x] Add or improve simple invoice preview.

### 7.3 Inventory Improvements

- [x] Add inventory search.
- [x] Add filter for all products.
- [x] Add filter for low stock products.
- [x] Add filter for disabled products.
- [x] Add fast sorting.
- [x] Support add product.
- [x] Support edit product.
- [x] Support disable product.
- [x] Show barcode, selling price, minimum stock, stock quantity, and WAC.

### 7.4 Customers And Suppliers

- [x] Improve customer statement readability.
- [x] Improve supplier statement readability.
- [x] Show balances derived from ledger.
- [x] Add quick customer installment collection action.
- [x] Add quick supplier installment payment action.

### 7.5 Reports

- [x] Improve daily summary report.
- [x] Improve profit period report.
- [x] Improve low stock report.
- [x] Improve inventory valuation report.
- [x] Improve customer statement report.
- [x] Improve supplier statement report.
- [x] Improve due and overdue installments report.
- [x] Add export or print for a short report if needed.

### 7.6 Backup UI

- [x] Add or polish backup folder selection.
- [x] Show last backup date.
- [x] Add manual backup action.
- [x] Show automatic backup retention state.
- [x] Add strong restore confirmation.

Acceptance:

- [x] The owner can complete a normal workday without technical screens.
- [x] Main workflows are obvious.
- [x] Errors are understandable.
- [x] UI remains responsive and readable.

## Phase 8: Acceptance Tests

Primary skill:

- `test-guard`

### 8.1 Full-Day Flow

- [x] Test first launch.
- [x] Test login.
- [x] Test password change when needed.
- [x] Test open shift.
- [x] Test add or edit product.
- [x] Test purchase creation.
- [x] Test cash sale.
- [x] Test wallet sale.
- [x] Test installment sale.
- [x] Test installment collection.
- [x] Test expense recording.
- [x] Test partial return.
- [x] Test close shift.
- [x] Test backup.
- [x] Test restore.
- [x] Verify balances and reports after restore.

### 8.2 Required Invariants

- [x] Assert no unbalanced ledger entries.
- [x] Assert stock cannot go negative.
- [x] Assert cash shift equation is correct.
- [x] Assert wallet is separate from cash drawer.
- [x] Assert customer balances match ledger.
- [x] Assert supplier balances match ledger.
- [x] Assert backup and restore preserve state.

### 8.3 Verification Commands

- [x] Run `dart analyze lib/v2 lib/main.dart test/v2`.
- [x] Run `flutter test`.
- [x] Run `flutter build linux`.
- [x] If needed, run `HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux`.

Acceptance:

- [x] All required tests pass.
- [x] Linux build succeeds.

## Phase 9: Code Quality Review

Primary skill:

- `clean-code-guard`

Checklist:

- [x] Business logic stays in use cases, not UI widgets.
- [x] Database writes are transactional where needed.
- [x] Ledger posting is centralized and validated.
- [x] Financial values do not use `double`.
- [x] Validation logic is not duplicated unnecessarily.
- [x] Errors are business-friendly.
- [x] No broad speculative abstractions were added.
- [x] No unrelated refactors were mixed with correctness fixes.
- [x] Migrations are explicit and tested.
- [x] High-risk findings are fixed or explicitly accepted.

## Phase 10: Documentation

Primary skill:

- `docs-guard`

Tasks:

- [x] Update root `README.md`.
- [x] Update `Frontend/alikhlas_pos/README.md` if still used.
- [x] Add release notes for v2.
- [x] Document how to run the app.
- [x] Document Linux build command.
- [x] Document expected Windows build process.
- [x] Document where SQLite database is stored.
- [x] Document backup and restore.
- [x] Document backup retention policy.
- [x] Document return policy.
- [x] Document WAC policy.
- [x] Document single-owner security model.
- [x] Document that no backend, Docker, or PostgreSQL is required.
- [x] Remove or clearly mark outdated v1 instructions.

Acceptance:

- [x] Docs match actual commands and paths.
- [x] A reviewer can find v2 immediately.

## Phase 11: v1 Archive And Cleanup

Do this only after v2 acceptance passes.

Review skills:

- `clean-code-guard`
- `docs-guard`

Tasks:

- [x] Confirm git is clean.
- [x] Create an archive or tag for the pre-cleanup state.
- [x] Confirm v2 tests and build pass before deleting old code.
- [x] Remove old backend code from the active tree.
- [x] Remove old Flutter screens not used by v2.
- [x] Remove old Flutter controllers not used by v2.
- [x] Remove old Flutter services not used by v2.
- [x] Remove old Flutter models not used by v2.
- [x] Remove unused dependencies from `pubspec.yaml`.
- [x] Run dependency resolution.
- [x] Run analyze.
- [x] Run tests.
- [x] Run Linux build.
- [x] Update docs to point only to v2.
- [x] Commit cleanup separately.

Acceptance:

- [x] v2 is the only active app.
- [x] No imports point to v1 code.
- [x] No old backend runtime is required.
- [x] Build succeeds after dependency cleanup.

## Suggested Commit Checklist

- [ ] `fix: align installment returns with ledger`
- [x] `fix: make sqlite restore safe with wal`
- [ ] `feat: harden local password hashing`
- [ ] `perf: add ledger indexes and aggregate balances`
- [ ] `feat: add expense records`
- [ ] `fix: stabilize liquid glass list tiles`
- [ ] `feat: polish daily operations ui`
- [ ] `test: cover full day v2 acceptance flow`
- [ ] `docs: document v2 operation and backup`
- [x] `chore: archive and remove v1 runtime`

## Final Acceptance

- [x] App runs on Linux.
- [x] App is ready for Windows build validation.
- [x] No backend is required.
- [x] No Docker is required.
- [x] No PostgreSQL is required.
- [x] No Redis is required.
- [x] Owner can open shift.
- [x] Owner can purchase.
- [x] Owner can sell by cash, wallet, and installment.
- [x] Owner can collect installment.
- [x] Owner can record expense.
- [x] Owner can return a sale item.
- [x] Owner can close shift.
- [x] Owner can backup and restore.
- [x] All balances and reports are derived from ledger lines.
- [x] Every ledger entry is balanced.
- [x] Backup keeps the last 30 copies.
- [x] Restore is safe with SQLite WAL.
- [x] Tests pass.
- [x] Documentation is current.
- [x] v1 is archived before deletion.
