# ALIkhlasPOS v2 Reports Audit

This audit records the actual data sources used by the v2 Reports screen.

## Scope

- UI file: `Frontend/alikhlas_pos/lib/v2/app/v2_app.dart`
- Use-cases file: `Frontend/alikhlas_pos/lib/v2/application/v2_use_cases.dart`
- PDF file: `Frontend/alikhlas_pos/lib/v2/printing/report_summary_pdf.dart`

## Reports Screen Data Sources

| UI area | Code path | Data source | Source type | Status |
| --- | --- | --- | --- | --- |
| Period metric cards | `_ReportsViewState._loadReport()` -> `periodReport()` | `ledger_lines` joined with `ledger_entries` through `_accountNetBetween()` | Ledger-derived | Working |
| Sales amount | `_periodReport()` | `AccountCodes.sales` net movement | Ledger-derived | Working |
| COGS | `_periodReport()` | `AccountCodes.cogs` net movement | Ledger-derived | Working |
| Expenses amount | `_periodReport()` | `AccountCodes.expenses` net movement | Ledger-derived | Working |
| Interest income | `_periodReport()` | `AccountCodes.interestIncome` net movement | Ledger-derived | Working |
| Cash net movement | `_periodReport()` | `AccountCodes.cash` net movement | Ledger-derived | Working |
| Wallet net movement | `_periodReport()` | `AccountCodes.wallet` net movement | Ledger-derived | Working |
| Purchase inventory intake | `_periodReport(referenceType: 'purchase')` | `AccountCodes.inventory` net movement filtered by purchase ledger entries | Ledger-derived | Working |
| Sale count | `_periodReport()` | `sale_invoices.created_at` in the selected period | Invoice-table-derived | Working |
| Purchase count | `_periodReport()` | `purchase_invoices.created_at` in the selected period | Invoice-table-derived | Working |
| Return count | `_periodReport()` | `sale_returns.created_at` in the selected period | Invoice-table-derived | Working |
| Expenses list | `expensesReport()` | `expenses.created_at` in the selected period | Expense-table-derived | Working as a list |
| Expense entry | `_ExpenseDialog` -> `recordExpense()` | Writes `expenses`, then posts balanced ledger lines | Workflow | Added |
| Inventory valuation | `_InventoryValuationPanel` | `WorkbenchSnapshot.products` plus `dashboard.inventoryMinor` | Product-table + ledger snapshot | Working |
| Low-stock report | `_LowStockList` | `WorkbenchSnapshot.products` filtered by `stockQty <= minStockQty` | Product-table-derived | Working |
| Recent invoices | `_RecentInvoicesPanel` | `WorkbenchSnapshot.recentSales` and `recentPurchases` | Invoice-table-derived | Working |
| Due installments | `_DueInstallmentsPanel` | `installment_plans` and `installment_payments` via `_dueInstallments()` | Installment-table-derived | Working |
| Recent ledger | `_RecentLedger` | `ledger_entries` and `ledger_lines` via `_recentLedgerEntries()` | Ledger-derived | Working |
| Report summary PDF | `ReportSummaryPdf.printReport()` | `PeriodReportSnapshot` only | Ledger-derived summary + invoice counts | Working as summary PDF |

## Important Boundaries

- Period money totals must stay ledger-derived.
- The expenses list is table-derived, but every expense must be created through `recordExpense()` so the table row and ledger movement remain consistent.
- Report summary PDF is intentionally a compact summary. It does not include detailed expense rows, invoice rows, or stock rows.
- Inventory valuation intentionally compares two views of the same business state:
  - ledger inventory balance;
  - product quantity multiplied by WAC.

## Remaining Report Risks

- Report PDF does not include detailed expense rows. If the owner expects an expense sheet, add a separate detailed expense export.
- Invoice counts are table-derived, not ledger-derived. This is acceptable for counts, but should stay documented.
- Recent invoices in Reports are limited to the latest 8 invoices from the global workbench snapshot, not the selected report period.
