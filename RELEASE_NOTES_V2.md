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
- SQLite WAL setup and drift schema version 4.
- Ledger-based sales, purchases, expenses, installments, returns, shifts, and reports.
- Sale returns handle installment over-refund correctly:
  - receivable settlement is capped at remaining customer debt;
  - overflow is refunded separately by cash or wallet;
  - cash overflow requires an open shift.
- Expense records are stored in an `expenses` table and posted to the ledger.
- Backup uses `VACUUM INTO`, keeps the latest 30 backup files, and restore clears WAL/SHM sidecar files.
- Liquid Glass daily operations UI covers dashboard, POS, inventory, parties, purchases, installments, returns, reports, backup, and settings.
- Apple/iOS-inspired Liquid Glass polish now uses bundled Cairo Arabic fonts, shared theme tokens, stronger glass contrast, opt-in real blur, and golden coverage for login/dashboard/POS/reports surfaces.
- Money input parsing is centralized around integer minor units, accepts Arabic and English digits, and blocks invalid text before any workflow is posted.
- A full owner operating-day test covers login/change password, shift, purchase, sale, installment collection, return, close shift, and backup.

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
- backup/restore and v3 to v4 migration.
- Cairo theme, glass contrast, centralized blur, and visual golden snapshots for login/dashboard/POS/reports.

## Remaining

- Validate Windows build on a Windows machine or Windows CI.
