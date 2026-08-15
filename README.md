# iCleaner-Lite

A small SwiftUI cache cleaner prototype for iOS.

## What it does

- Scans application data containers supplied by the active filesystem provider.
- Calculates `tmp`, `Library/Caches`, and optional `Library/Logs` sizes per app.
- Sorts apps by reclaimable size.
- Selects individual apps or all scanned apps.
- Batch-cleans only the whitelisted cache/log directories.
- Never targets `Documents`, `Library/Preferences`, `Library/Application Support`, databases, or keychain data.

## Important iOS limitation

A normal iOS app is sandboxed and cannot enumerate or delete another app's container. `LocalFileSystemProvider` therefore only works when the process has legitimate filesystem access to the supplied root. The cleaner intentionally keeps that access behind the `FileSystemProvider` protocol so a separate, authorized backend can be integrated without changing the scanner/UI.

This repository does **not** contain an exploit, jailbreak payload, or sandbox bypass.

## Project

Open `iCleanerLite.xcodeproj` in Xcode. The project targets iOS 17+ and uses SwiftUI.

## Default scan root

The prototype expects:

`/var/mobile/Containers/Data/Application`

If the active filesystem backend exposes that path, scanning can discover app containers automatically.

## Safety model

Deletion is limited to the following directories inside a selected application container:

- `tmp/`
- `Library/Caches/`
- `Library/Logs/` (optional in the UI)

Symlinks are not followed during size calculation or deletion.
