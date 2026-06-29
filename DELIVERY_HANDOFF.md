# ALIkhlasPOS v2 Delivery Handoff

## Build Reference

- Branch: `fix/v2-installment-returns`
- Application build commit: `1eb157a08a1218b1b45c241196e60e6dc77faf1d`
- Application build short commit: `1eb157a`
- Flutter used by CI: `3.44.2` stable

## Available Artifacts

### Linux

- Local ZIP on this machine: `/tmp/alikhlas-pos-linux-1eb157a.zip`
- Size: `15M`
- The ZIP contains the Linux executable `alikhlas_pos`, `lib/libapp.so`, SQLite native library, PDF/printing libraries, Material icons, and bundled Cairo font assets.
- The clean ZIP check found no stale `cupertino_icons` or `iconsax_flutter` asset folders.

### Windows

- GitHub Actions workflow: `Windows Release Build`
- Successful run: <https://github.com/el3laimy/Home-applaince-shop-manager-system/actions/runs/28383813030>
- Artifact name: `alikhlas-pos-windows`
- Artifact id: `7956886830`
- Artifact size: `17,928,723` bytes
- Artifact digest: `sha256:ba71161f013b2d85880e38e9b99be925fb94857b242f7bb38af8bfe3e1e5922e`
- Artifact expiry on GitHub Actions: `2026-09-27T15:34:48Z`

## Automated Verification Already Passed

- `dart analyze lib/v2 lib/main.dart test/v2`
- `flutter test`
- Clean `flutter build linux`
- GitHub Actions `Windows Release Build`:
  - Checkout: passed
  - Flutter setup: passed
  - `flutter pub get`: passed
  - `dart analyze lib/v2 lib/main.dart test/v2`: passed
  - `flutter build windows --release`: passed
  - Upload artifact `alikhlas-pos-windows`: passed

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
- Windows build is produced by GitHub Actions because Flutter Windows builds require a Windows host.
