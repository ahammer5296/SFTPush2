# Tech Context

## Languages & Frameworks
- Swift 5 / AppKit (macOS)

## Build & Run
- Open `SFTPush2/SFTPush2.xcodeproj`
- Select target `SFTPush2`
- Set Team if required → Run

## Repository Structure (key parts)
- `SFTPush2/` — main macOS app target and sources
- `mft-main/` — SFTP framework project (libssh/openssl)
- `memory-bank/` — knowledge base for development
- `agent.md` — agent guidance

## Dependencies
- System frameworks (AppKit, CoreGraphics, ApplicationServices)
- `mft.framework` (from `mft-main`) for SFTP; libssh/openssl inside
- Carbon (RegisterEventHotKey) for global hotkeys

## Tooling / Conventions
- Localization via `Localizable.xcstrings` + helper `L(_:)`
- Auto Layout programmatic (NSStackView + constraints)
- Preferences via `UserDefaults` wrapper (`Preferences`)
  - Hotkeys stored as keyCode + modifier flags for layout independence
  - Monosnap behavior keys: `copyBeforeUpload`, `closeMonosnapAfterUpload`, `monosnapCloseDelayMs` (0–2000 ms)

## Testing Strategy (initial)
- Manual verification of UI sections and menu behaviors
- Add unit tests for Preferences and small pure functions when ready
 - Verify Accessibility (Privacy) permissions when simulating Cmd+C/Cmd+W

## Environments
- macOS Sonoma/Sequoia; Xcode 15/16 compatible

## Secrets / Credentials
- For now SFTP password is in UserDefaults (development only)
- Future: move to Keychain via `SecItem` APIs
- Accessibility permission (Automation) required for CGEvent key simulation (Cmd+C/Cmd+W)
- Project Structure & Build
  - Renamed to SFTPush2 (target + product), cleaned repo to memory-bank, mft-main, SFTPush2, agent.md
  - Explicit Info.plist at SFTPush2/Info.plist (GENERATE_INFOPLIST_FILE=NO)
  - CFBundleDocumentTypes declares public.data (Viewer); used for Dock drag & drop
  - Entitlements: com.apple.security.cs.disable-library-validation=true (dev) to allow mft.framework embedding/signing

- Frameworks
  - mft.framework embedded with CodeSignOnCopy; real SFTP vs fallback decided by canImport(mft) with runtime logs

- Notifications
  - UNUserNotificationCenter used; custom categories reserved for future actions
  - Batch summary notifications synthesized in code; history updates on success

- UI/UX Details
  - Status bar: custom overlay for drag; animated frames loaded from assets
  - Hover preview: NSPopover with NSImageView, max 250x250, prefers left; thumbnail cache via URLSession + NSCache

- Known platform caveats
  - Dock drop requires app visible in Dock and updated Launch Services cache; sometimes needs Finder restart
  - AppIcon must include full mac idiom sizes to appear in all system surfaces (e.g., Notifications pane)
  - ATS blocks http image fetches by default; prefer https or define exceptions

## Release Build & Signing (macOS, outside Mac App Store)
- Prerequisites
  - Apple Developer account with a Developer ID Application certificate in your keychain
  - Xcode configured with your Team; set Target Signing to your team

- Versioning & Bundle
  - Update MARKETING_VERSION (semantic version) and CURRENT_PROJECT_VERSION (build number)
  - Set PRODUCT_BUNDLE_IDENTIFIER to your reverse‑DNS ID (e.g., com.yourco.SFTPush2)
  - Ensure AppIcon has all mac idiom sizes (16/32/128/256/512 @1x/@2x)

- Signing Settings (Release configuration)
  - Code Signing: Developer ID Application
  - Enable Hardened Runtime = YES
  - Entitlements: review SFTPush2.entitlements
    - Keep com.apple.security.cs.disable-library-validation only if truly required by embedded frameworks; prefer removing for production if possible
  - Embedded frameworks: Build Phases → Embed Frameworks must have CodeSignOnCopy

- Archive & Export
  - Product → Archive (scheme: SFTPush2, configuration: Release)
  - Locate the .app in Organizer or export the archive
  - Verify code signature: `codesign --verify --deep --strict --verbose=2 /path/SFTPush2.app`

- Notarization (notarytool)
  - Zip the app: `cd /path && ditto -c -k --keepParent SFTPush2.app SFTPush2.zip`
  - Store credentials once: `xcrun notarytool store-credentials AC_PROFILE --apple-id your@appleid.com --team-id TEAMID --password app-specific-password`
  - Submit: `xcrun notarytool submit SFTPush2.zip --keychain-profile AC_PROFILE --wait`
  - Staple ticket: `xcrun stapler staple /path/SFTPush2.app`
  - Gatekeeper check: `spctl -a -t exec -vvv /path/SFTPush2.app`

- Distribution
  - Distribute the stapled .app or package into a signed .dmg if desired
  - For .dmg, codesign the .dmg with Developer ID Application and re‑notarize if needed

- App Store (if applicable)
  - Use App Store Connect, App Sandbox, appropriate entitlements, and App Store provisioning; notarization is handled by Apple upon upload

- Misc recommendations
  - Consider changing LSHandlerRank from Owner→Alternate for public.data before release to avoid claiming ownership of all files
  - Keep Info.plist explicit in repo; include LSApplicationCategoryType and other metadata as needed

## CI/CD & Releases
- Tags: auto‑tag workflow on pushes to `main` increments minor version (vX.Y → vX.(Y+1)) if HEAD is untagged.
- Releases: created manually (or via `gh`) from tag; title scheme kept as “SFTPush2 1.0” while tag may be `v1.1`.
- Asset: ship `SFTPush2.zip` (built .app zipped with parent folder using `ditto`).
- Notes: maintain `RELEASE_NOTES.md` in repo; include SHA256 and size of the asset.
