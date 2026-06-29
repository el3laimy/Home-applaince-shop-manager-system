# ALIkhlasPOS v2 Delivery Handoff

## Build Reference

- Branch: `fix/v2-installment-returns`
- Release artifact commit: `f69f81484ddfbabf3e795596342a75102d993833`
- Release artifact short commit: `f69f814`
- Flutter used by CI: `3.44.2` stable

## Available Artifacts

### Linux

- GitHub Actions workflow: `Desktop Release Build`
- Successful run: <https://github.com/el3laimy/Home-applaince-shop-manager-system/actions/runs/28386193066>
- Artifact name: `alikhlas-pos-linux`
- Artifact id: `7957800299`
- Artifact size: `15,859,198` bytes
- Artifact digest: `sha256:f659e2dcb7d6a7a92b7601f4a786ce737798f5350bea8dae90a3ff283b78c258`
- Artifact expiry on GitHub Actions: `2026-09-27T16:12:20Z`
- Local ZIP on this machine: `/tmp/alikhlas-pos-linux-f69f814.zip`
- Size: `15M`
- The ZIP contains the Linux executable `alikhlas_pos`, `lib/libapp.so`, SQLite native library, PDF/printing libraries, Material icons, and bundled Cairo font assets.
- The clean ZIP check found no stale `cupertino_icons` or `iconsax_flutter` asset folders.

### Windows

- GitHub Actions workflow: `Desktop Release Build`
- Successful run: <https://github.com/el3laimy/Home-applaince-shop-manager-system/actions/runs/28386193066>
- Artifact name: `alikhlas-pos-windows`
- Artifact id: `7957842881`
- Artifact size: `17,928,717` bytes
- Artifact digest: `sha256:75c3555c9cbb60b234a74d30d925b2213681471bddf68a819373eb2d53dba44f`
- Artifact expiry on GitHub Actions: `2026-09-27T16:12:20Z`

## Automated Verification Already Passed

- `dart analyze lib/v2 lib/main.dart test/v2`
- `flutter test`
- Clean `flutter build linux`
- GitHub Actions `Desktop Release Build`:
  - Checkout: passed
  - Flutter setup: passed
  - Linux build dependencies installation: passed
  - `flutter pub get`: passed on Windows and Linux
  - `dart analyze lib/v2 lib/main.dart test/v2`: passed on Windows
  - `flutter build windows --release`: passed
  - `flutter build linux --release`: passed
  - Upload artifact `alikhlas-pos-windows`: passed
  - Upload artifact `alikhlas-pos-linux`: passed

## Delivery Smoke Test

Run this on the final device before handover:

1. Open the app.
2. Log in with the owner account and change the default password if prompted.
3. Choose a backup folder from Settings.
4. Open a shift.
5. Add or edit a product, including barcode and optional image.
6. Record a purchase with at least one item.
7. Print incoming barcode labels after the purchase.
8. Reprint one existing product barcode from Inventory.
9. Record a sale with cash or wallet payment.
10. Record an installment sale and collect one installment.
11. Open the customer statement and verify invoice totals, discount, paid, returned, and remaining values.
12. Print or export the customer statement PDF.
13. Record a return.
14. Record an expense.
15. Close the shift and verify expected cash versus counted cash.
16. Run a manual backup.
17. Restart the app and confirm the data remains available.

## Hardware Validation Still Required

These items cannot be proven from the current Linux development environment:

- Launch and basic navigation on the target Windows machine.
- Thermal receipt printer output.
- Barcode label printer output with the configured dimensions, especially the default `40 x 30 mm` label.
- Actual barcode scanner input in POS search.

Do not treat the Windows delivery as final until the Windows artifact launches on the target machine and the printer/scanner checks above pass.

## Release Notes For The Reviewer

- The app is now Flutter Desktop with local SQLite/drift, not a separate backend runtime.
- Money is represented as integer minor units in the v2 code path.
- Ledger entries remain the financial source of truth for balances and reports.
- Barcode labels can be printed after purchases and reprinted later from Inventory when a label is damaged.
- Barcode label dimensions are configurable from Settings.
- Windows and Linux release bundles are produced by GitHub Actions. Windows still requires a Windows host, so it is built on `windows-latest`.
