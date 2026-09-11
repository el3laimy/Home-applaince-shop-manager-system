# Implementation batch 32 — Purchase returns

## Scope

- Added purchase-return documents and line items in schema v8.
- Added a searchable end-user flow from the returns screen.
- Added durable operation receipts, pending-operation recovery, stock movement, ledger posting, and integrity-audit coverage.

## Accounting policy

Supplier credit uses the historical purchase-line cost. Inventory is reduced at the product's current weighted-average cost. The difference posts to `inventory_variance`, keeping inventory valuation and the balanced ledger correct after later purchases at different prices.

## Verified behavior

- A duplicate operation key returns the first purchase-return document.
- Changed payloads with a saved key are rejected.
- A pending purchase return survives reopening the SQLite file and replays once.
- A receipt-write failure rolls back the document, stock, and ledger.
- The UI selects a purchase invoice, limits quantities to current stock, and reduces supplier debt.

## Boundary

This is local code and widget validation. A clean-device installation, upgrade, removal, physical printer run, real power-loss test, Windows signing, and end-user pilot remain release-acceptance work.
