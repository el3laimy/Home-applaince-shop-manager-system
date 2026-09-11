# Implementation batch 29 — financial idempotency coverage

## Scope

- Audited every current public command that posts to the ledger or changes a financial balance.
- Confirmed durable operation-key protection and pending-request recovery for sales, purchases, customer collections, supplier payments, sale returns, expenses, shifts, opening stock, and inventory adjustments.
- Added the in-progress opening-balance command to the same contract.
- Extended the data-integrity audit and Drift v7 migration coverage for opening balances.

## Verified behavior

- Repeating the same key and payload returns the original result id.
- Reusing a key with a different payload is rejected before state changes.
- A request that survives a lost UI reply can be replayed after reopening the SQLite file without duplication.
- Failure to write the durable receipt rolls back the opening-balance document, installment plan, ledger entry, and ledger lines.
- A missing operation key is rejected by every current public money-moving command.

## Validation

- `dart analyze lib/v2 lib/main.dart test/v2`: no issues.
- Focused financial and migration tests: 41 passed.
- `flutter test --no-pub test/v2`: 159 passed.
- `flutter build linux`: succeeded.
- `git diff --check`: succeeded.

## Boundary

Purchase returns are not implemented in the current application, so there is no purchase-return mutation to protect yet. The opening-balance user interface is also still pending; this batch completes its data and recovery contract.
