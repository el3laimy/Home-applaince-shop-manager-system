# ALIkhlasPOS v2 Implementation Plan

## Summary

This document is the execution plan for completing ALIkhlasPOS v2.

Execution tracking lives in `TASKS.md`.

The current direction is to keep v2 as the only future runtime:

- Flutter desktop application.
- Offline-first.
- SQLite through drift.
- Riverpod for state management.
- No backend server.
- No Docker.
- No PostgreSQL.
- No Redis.
- Single owner user.
- Ledger-first accounting.

The goal is to move v2 from a working engine and partial daily UI into a stable production-ready shop application, then archive and remove v1 only after v2 passes acceptance.

## Current Known State

- v2 exists under `Frontend/alikhlas_pos/lib/v2`.
- `Frontend/alikhlas_pos/lib/main.dart` starts `ALIkhlasV2App`.
- The v2 engine already includes core workflows:
  - Sales.
  - Purchases.
  - Installments.
  - Returns.
  - Shifts.
  - Backup.
  - Reports.
  - SQLite/drift database.
  - Ledger entries and ledger lines.
- v1 code and old dependencies still exist and must not be deleted until v2 is accepted.
- The remaining work is mostly correctness hardening, restore safety, security, performance, UI polish, tests, documentation, then cleanup.

## Available Skills

The following skills are available in the Codex environment and are relevant to this project:

| Skill | Purpose |
| --- | --- |
| `clean-code-guard` | Review production code after fixes and refactors. |
| `test-guard` | Review test quality and prevent fragile or shallow tests. |
| `frontend-design` | Guide the Liquid Glass UI direction and interaction quality. |
| `docs-guard` | Review README and technical docs against the real code. |
| `doc-coauthoring` | Create and refine plans, reports, specs, and decision documents. |
| `webapp-testing` | UI interaction testing when browser-style tooling is useful. |
| `pdf` | Work with PDF exports or report artifacts if needed. |
| `docx` | Create or edit Word documents if formal documentation is needed. |
| `xlsx` | Work with spreadsheet exports or financial report samples. |
| `skill-creator` | Create a custom project skill if repeated ALIkhlasPOS workflows need automation. |
| `skill-installer` | Install additional skills if needed. |

## Skills To Use During Execution

| Phase | Skill |
| --- | --- |
| Planning and reports | `doc-coauthoring` |
| Backend-free v2 code fixes | `clean-code-guard` |
| Test additions and review | `test-guard` |
| Liquid Glass UI work | `frontend-design` |
| Final docs and README | `docs-guard` |
| Optional export/report files | `pdf`, `xlsx`, or `docx` only if the feature requires them |

## Guiding Rules

- Keep `LedgerEntry` and `LedgerLine` as the financial source of truth.
- Store money as integer minor units only.
- Do not use `double` for financial values.
- Every financial workflow must run inside a database transaction.
- Every ledger entry must balance.
- Cash movements must be tied to an open shift.
- Reports and balances must be derived from ledger lines.
- v1 must stay available until v2 passes final acceptance.
- Avoid broad refactors while fixing correctness issues.
- Use small, reviewable commits by phase where possible.

## Phase 1: Critical Data Correctness

### 1.1 Fix Installment Sale Returns

Problem:

Sale returns for installment invoices currently affect the ledger receivable balance, but the installment plan can remain inconsistent.

Decision:

An installment return must reduce the installment plan. It must not only post a ledger adjustment.

Implementation:

- Update `createSaleReturn`.
- When the original sale has an installment plan:
  - Calculate the return amount.
  - Calculate the customer's remaining receivable before the return.
  - Split the return into `receivableSettlementMinor = min(returnAmount, remainingReceivable)` and `overflowRefundMinor = returnAmount - receivableSettlementMinor`.
  - Reduce `InstallmentPlan.totalMinor` by `receivableSettlementMinor`, not by the full return amount when the return is greater than the remaining receivable.
  - If `overflowRefundMinor > 0`, refund the excess through a separate cash or wallet refund path.
  - Require an open shift when the excess refund path uses cash.
  - Keep already paid installment payments unchanged.
  - Recalculate unpaid installment rows against the new remaining amount.
  - Put rounding difference into the last unpaid installment.
  - Close the plan if the remaining amount becomes zero.
- Ensure the ledger receivable credit equals the installment plan reduction and never exceeds the remaining receivable.

Acceptance:

- Partial return reduces customer balance and remaining installments.
- Full return closes the plan.
- Return greater than the remaining receivable only closes receivables up to the remaining balance.
- Excess return amount above the remaining receivable is refunded separately through cash or wallet.
- Cash excess refund requires an open shift.
- Installment plan reduction equals the receivable ledger reduction.
- Customer statement matches the installment summary.
- Ledger entry remains balanced.

Tests:

- Partial installment return.
- Full installment return.
- Return after one or more installments have already been paid.
- Return amount greater than remaining customer receivable.
- Ledger receivable balance equals installment remaining balance.

### 1.2 Require Open Shift For Cash Returns

Problem:

Cash sales, cash purchases, and cash expenses require an open shift. Cash returns must follow the same rule.

Implementation:

- In `createSaleReturn`, if the refund method is cash:
  - Require an open shift.
  - Fail with a clear business error if no shift is open.
- Ensure the refund affects the expected cash amount at shift close.

Acceptance:

- Cash return without an open shift is rejected.
- Cash return with an open shift succeeds.
- Close shift includes the cash refund in expected cash.

Tests:

- Cash return without shift.
- Cash return with shift.
- Shift close after cash sale and cash return.

### 1.3 Document WAC Return Policy

Decision:

In v2, sale returns restore stock using the historical `unitCost` stored on the original sale item. Sale returns do not recalculate current `avgCostMinor`.

Implementation:

- Keep inventory reversal based on `SaleItem.unitCost`.
- Add a short code comment near the return inventory logic.
- Add tests proving historical COGS reversal uses `unitCost`.

Acceptance:

- Return COGS reversal is historically correct.
- The policy is explicit and tested.

## Phase 2: Safe Backup And Restore

### 2.1 Fix Restore With SQLite WAL

Problem:

Restore must not copy only the `.db` file while stale `-wal` or `-shm` files remain.

Implementation:

- Before restore:
  - Run `PRAGMA wal_checkpoint(TRUNCATE)`.
  - Close the database.
  - Create a temporary copy of the current database as rollback protection.
  - Delete target sidecar files:
    - `<database>-wal`
    - `<database>-shm`
  - Copy the backup database over the target database.
- After restore:
  - Reopen the database safely or require application restart.
  - Surface a clear success message.
- If restore fails:
  - Restore the temporary rollback copy.
  - Return a clear failure result.

Acceptance:

- Restore returns exactly the backed up state.
- Stale WAL/SHM files cannot corrupt restored data.
- Failed restore does not leave the app unusable.

Tests:

- Backup then restore.
- Restore while fake/stale WAL and SHM files exist.
- Restore failure path keeps original database usable.
- Automatic backup retention still keeps the last 30 copies.

## Phase 3: Password Security

### 3.1 Replace Plain SHA-256 With Versioned PBKDF2

Problem:

Plain SHA-256 is too weak for password storage, even in a local single-user app.

Decision:

Use versioned PBKDF2-HMAC-SHA256 hashes.

Hash format:

```text
pbkdf2_sha256$120000$base64Salt$base64Hash
```

Implementation:

- Generate a random per-user salt.
- Use at least 120,000 PBKDF2 iterations.
- Store the versioned hash in the existing password hash field if possible.
- Support legacy hash verification:
  - If the stored hash is legacy SHA-256, verify with the old method.
  - On successful login, rewrite it using PBKDF2.
- Ensure `changePassword` always writes the new format.
- Ensure bootstrap user creation writes the new format.

Acceptance:

- New passwords are stored with PBKDF2 and salt.
- Legacy users can still log in.
- Legacy hash is upgraded after successful login.
- Wrong passwords are rejected.

Tests:

- Same password produces different hashes due to salt.
- New login succeeds with PBKDF2.
- Legacy login succeeds once and upgrades the hash.
- Wrong password fails.

## Phase 4: Database Performance And Query Correctness

### 4.1 Add Useful Indexes

Implementation:

Add drift migrations and indexes for frequent lookups:

- Confirm the actual ledger date column before adding date indexes or date-range aggregates. As of this plan update, the verified column is `LedgerEntries.createdAt`.
- `LedgerLines.entryId`
- `LedgerLines.accountCode`
- `LedgerLines.partyType + partyId`
- `LedgerEntries.createdAt`
- `LedgerEntries.referenceType + referenceId`
- `StockMovements.productId`
- `StockMovements.referenceType + referenceId`
- `Payments.ownerType + ownerId`
- `InstallmentPayments.planId + dueDate`
- `SaleItems.saleId`

Acceptance:

- Indexes exist after migration.
- Existing data remains readable.
- Analyze and tests pass.

### 4.2 Move Balance Calculations To SQL Aggregates

Problem:

Some balances are calculated by loading rows into Dart and folding them in memory.

Implementation:

- Replace account balance calculations with SQL `SUM`.
- Replace party balance calculations with grouped SQL aggregates.
- Preserve current sign conventions.
- Keep ledger lines as the source of truth.

Acceptance:

- SQL results match current expected business results.
- Reports remain unchanged from the user's perspective.

Tests:

- Account balance equivalence.
- Party balance equivalence.
- Daily summary equivalence.
- Larger fixture data set for basic performance confidence.

## Phase 5: Expense Entity

### 5.1 Add `Expenses` Table

Problem:

Expenses are posted to ledger, but there is no first-class expense record. Some references are currently synthetic.

Implementation:

Add an `Expenses` table:

```text
id
description
amountMinor
method
createdAt
```

Update `recordExpense`:

- Validate description, amount, and payment method.
- Require an open shift for cash expenses.
- Insert an expense row.
- Use `expense.id` as the ledger `referenceId`.
- Post a balanced ledger entry.

Acceptance:

- New expenses have a real row.
- Ledger remains the financial source of truth.
- Expense reports can list actual expense records.

Tests:

- Record cash expense.
- Record wallet expense.
- Cash expense without shift fails.
- Expense ledger entry balances.
- Expense report totals match ledger.

## Phase 6: UI Test Fixes

### 6.1 Fix `ListTile` Material Assertion

Problem:

Flutter widget tests can fail when `ListTile` is placed inside Liquid Glass decorated containers without a proper `Material` ancestor.

Implementation:

- Add a small wrapper widget, for example `_InkSafeTile`.
- Wrap affected `ListTile` widgets with `Material(type: MaterialType.transparency)`.
- Do not redesign the UI during this fix.

Acceptance:

- `flutter test` passes.
- No visible UI regression is introduced.

Tests:

- Existing widget tests pass.
- Main dashboard renders without assertion.

## Phase 7: Liquid Glass Daily Operations UI

Use skill:

- `frontend-design`

Goal:

Turn the current v2 UI into a polished daily operations interface, not a landing page.

Design rules:

- Liquid Glass aesthetic.
- Dense but readable.
- Fast for repeated shop workflows.
- No decorative UI that slows daily work.
- Clear Arabic-first labels if the current product direction requires Arabic.
- No accounting complexity exposed to the owner unless in reports.

Screens:

- Dashboard.
- POS.
- Inventory.
- Customers.
- Suppliers.
- Installments.
- Reports.
- Backup and restore.
- Settings.

POS improvements:

- Fast product search.
- Barcode-first flow.
- Stable cart.
- Quantity editing.
- Item removal.
- Mixed payment.
- Clear errors for insufficient stock, missing shift, invalid amount, and overpayment.
- Simple invoice preview.

Inventory improvements:

- Search.
- Filter by all, low stock, disabled.
- Fast sorting.
- Add/edit/disable product.
- Barcode field.
- Selling price.
- Minimum stock.
- Stock quantity.
- WAC shown as owner-only information.

Customers and suppliers:

- Clear account statement.
- Derived balance from ledger.
- Quick collect customer installment.
- Quick pay supplier installment.
- Filter active/inactive if needed.

Reports:

- Daily summary.
- Profit period report.
- Low stock report.
- Inventory valuation.
- Customer statement.
- Supplier statement.
- Due and overdue installments.
- Export/print short report if required.

Backup UI:

- Choose backup folder.
- Show last backup date.
- Run backup manually.
- Show automatic backup retention status.
- Restore with strong confirmation.

Acceptance:

- Owner can complete a normal day without opening technical screens.
- Main workflows are visible and reachable.
- Errors are understandable.
- UI remains responsive and readable.

## Phase 8: Acceptance Tests

Use skill:

- `test-guard`

Required full-day flow:

1. First launch.
2. Login.
3. Force or perform password change when needed.
4. Open shift.
5. Add or edit product.
6. Create purchase.
7. Create cash sale.
8. Create wallet sale.
9. Create installment sale.
10. Collect installment.
11. Record expense.
12. Create partial return.
13. Close shift.
14. Backup.
15. Restore.
16. Verify balances and reports.

Required checks:

- No unbalanced ledger entries.
- Stock cannot go negative.
- Cash shift equation is correct.
- Wallet is separate from cash drawer.
- Customer and supplier balances match ledger.
- Backup/restore preserves state.

Commands:

```bash
dart analyze lib/v2 lib/main.dart test/v2
flutter test
flutter build linux
```

Fallback Flutter command for this machine:

```bash
HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux
```

## Phase 9: Code Quality Review

Use skill:

- `clean-code-guard`

Review checklist:

- Business logic stays in use cases, not UI widgets.
- Database writes are transactional where needed.
- Ledger posting is centralized and validated.
- No financial `double`.
- No duplicate validation logic across UI and use cases unless intentional.
- Errors are business-friendly.
- No broad speculative abstractions.
- No unrelated refactors mixed into correctness fixes.
- Migrations are explicit and tested.

Acceptance:

- Review findings are fixed or explicitly accepted.
- No high-risk correctness issue remains open.

## Phase 10: Documentation

Use skill:

- `docs-guard`

Documents to update:

- Root `README.md`.
- `Frontend/alikhlas_pos/README.md` if still used.
- Release notes for v2.

Must document:

- How to run the app.
- How to build Linux.
- Expected Windows build process.
- Where SQLite database is stored.
- How backup and restore work.
- Backup retention policy.
- Return policy.
- WAC policy.
- Single-owner security model.
- No backend/Docker/PostgreSQL requirement.

Acceptance:

- Docs match actual commands and paths.
- No outdated v1 instructions remain in primary README.
- New developer or reviewer can find v2 immediately.

## Phase 11: v1 Archive And Cleanup

Do this only after v2 acceptance passes.

Steps:

1. Confirm git is clean.
2. Create archive/tag for the pre-cleanup state.
3. Confirm v2 builds and tests pass.
4. Remove old backend code from the active tree.
5. Remove old Flutter screens, controllers, services, and models not used by v2.
6. Remove unused dependencies from `pubspec.yaml`.
7. Run dependency resolution.
8. Run analyze, tests, and Linux build.
9. Update docs to point only to v2.
10. Commit cleanup separately.

Acceptance:

- v2 is the only active app.
- No import points to v1 code.
- No old backend runtime is required.
- Build succeeds after dependency cleanup.

## Suggested Commit Order

1. `fix: align installment returns with ledger`
2. `fix: make sqlite restore safe with wal`
3. `feat: harden local password hashing`
4. `perf: add ledger indexes and aggregate balances`
5. `feat: add expense records`
6. `fix: stabilize liquid glass list tiles`
7. `feat: polish daily operations ui`
8. `test: cover full day v2 acceptance flow`
9. `docs: document v2 operation and backup`
10. `chore: archive and remove v1 runtime`

## Final Acceptance Criteria

- App runs on Linux and is ready for Windows build validation.
- No backend, Docker, PostgreSQL, or Redis is required.
- Owner can perform daily operations:
  - Open shift.
  - Purchase.
  - Sell by cash, wallet, or installment.
  - Collect installment.
  - Record expense.
  - Return sale item.
  - Close shift.
  - Backup and restore.
- All balances and reports are derived from ledger lines.
- Every ledger entry is balanced.
- Backup keeps the last 30 copies.
- Restore is safe with SQLite WAL.
- Tests pass.
- Documentation is current.
- v1 is archived before deletion.
