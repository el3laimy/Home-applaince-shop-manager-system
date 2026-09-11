# ALIkhlasPOS v2 — Release Candidate Handoff

## Source of truth

- Package version: `1.1.0+10`.
- Database schema: `10`.
- A release artifact is valid only when its GitHub Actions run is green and its commit matches the commit shown by that run.
- CI injects that commit into the desktop build as `APP_GIT_SHA`; the in-app support screen therefore shows the installed package version together with the build revision.
- Do not treat an older artifact, its expiry date, or a manually copied bundle as the current release candidate.

## Required CI evidence

For the exact commit being handed over, attach links to a green `Desktop Release Build` run and its two installer artifacts:

1. `alikhlas-pos-windows-installer`
2. `alikhlas-pos-linux-deb`

The run must pass analyze, tests, Windows bundle, Windows NSIS installer, Linux bundle, Debian package build, and Debian package verification.

## Final-device acceptance

Run this checklist on clean target devices before commercial release:

1. Install the Windows installer, open the app, create the first owner, then verify its version and revision in Help.
2. Upgrade an existing Windows installation while preserving `alikhlas_v2.db`, then verify migration, balances, and backup access.
3. Uninstall Windows and confirm user data is retained as documented; reinstall and confirm it can reopen it.
4. Install the Debian package on a clean supported Debian/Ubuntu device, launch it, then remove and reinstall it.
5. Test the target receipt printer, barcode-label printer, and physical barcode scanner.
6. Create a backup on the intended external location, restore a copy to a test database, and verify its balances.
7. Execute a forced-close/power-loss simulation and a disk-full simulation using a disposable test database.
8. Run a controlled end-user pilot with real workflows before commercial rollout.

## Operating safeguards

- The app is local and offline; protect the operating-system account and use full-disk encryption such as BitLocker where available.
- Store backups on a protected destination and keep the owner recovery code outside the device.
- Do not distribute an unsigned Windows installer as a final production release.
