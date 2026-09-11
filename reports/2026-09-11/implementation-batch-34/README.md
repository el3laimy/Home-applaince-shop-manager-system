# Implementation batch 34 — exact inventory valuation and reconciliation

## Scope

- Added an exact `inventory_value_minor` basis to every product and exact cost allocations to sale and sale-return rows (schema v10).
- Purchases, sales, both return directions, opening stock, and inventory adjustments now update that basis inside their existing transactions.
- The rounded weighted-average cost remains a display value only; ledger postings use the exact basis.
- The integrity audit reconciles the product basis to the inventory ledger account and reports, rather than repairs, a legacy difference.
- Prevented deactivation of a product with remaining quantity or inventory value and added reactivation from the inventory menu.
- Inventory and report valuation include every product value so a deactivated row cannot disappear from the total.

## Migration policy

The v9-to-v10 migration initializes the new exact fields from the recorded legacy values (`stock_qty × avg_cost_minor` and `qty × unit_cost_minor`). It does not rewrite historical ledger entries. If history already contains a valuation difference, the read-only integrity audit exposes it for a documented correction.

## Verified behavior

- Purchases costing 2 × 100 and 1 × 101, followed by sales of 1 then 2, allocate costs 100 and 201 and leave both product value and inventory ledger at zero.
- A sale return after a later purchase restores the original exact sale cost, including sequential partial returns, and a final sale drains the product and ledger together.
- A full physical-count shortage removes the remaining exact value even when the displayed average is rounded.
- Products carrying quantity or value cannot be disabled; once fully reconciled they can be disabled and reactivated safely.
- Database snapshots from v3 and v4 migrate to v10 with the new columns and retain the recovery safeguards.

## Validation

- `dart analyze lib test/v2/inventory_adjustment_test.dart test/v2/purchase_return_idempotency_test.dart test/v2/data_integrity_audit_test.dart`: no issues found.
- `flutter test --no-pub test/v2/inventory_reconciliation_test.dart --reporter expanded`: 3 tests passed.
- `flutter test --no-pub test/v2/inventory_adjustment_test.dart --reporter expanded`: 5 tests passed.
- `flutter test --no-pub test/v2/purchase_return_idempotency_test.dart test/v2/data_integrity_audit_test.dart test/v2/return_rounding_test.dart --reporter expanded`: 13 tests passed.
- `flutter test --no-pub test/v2/migration_safety_test.dart --reporter expanded`: 3 tests passed.

## Boundary

This closes the rounding and hidden-value defects in current V2 operations. A device-level upgrade, power-loss test, installer upgrade/removal run, signed Windows installer, CSV import/export, and field pilot remain separate release-acceptance work.
