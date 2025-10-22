# Active Context

Always update this file first when starting new work. It reflects the live state of development.

## Current Focus
- Project renamed and restructured to SFTPush2 (target, product, folders)
- Settings window UX stabilized (fixed width, dynamic height, top-center open)
- Three sections implemented: General, SFTP, Clipboard & Hotkeys
- Menu bar + dock icons with testable animations; assets restored
- Drag & drop to status item (overlay view) and Dock (CFBundleDocumentTypes + Apple Events)
- Clipboard pipeline finalized (format re-encode, size guard); batch uploads emit single summary
- History menu with thumbnails + 1s hover preview (popover, left-first), cmd-click opens URL
- Post-upload options: copy URL to clipboard, open in browser (configurable)
- SFTP upload via mft with runtime logs; fallback stub logs when mft unavailable

## Recent Changes
- Renamed project to SFTPush2; cleaned repo to memory-bank, mft-main, SFTPush2, agent.md
- Fixed Dock drop: added explicit Info.plist and CFBundleDocumentTypes (public.data, Owner), Apple Event 'odoc' handler + reply
- Added status item drag overlay; unified file upload pipeline; accepts any regular file
- Implemented HistoryStore (JSON in UserDefaults), history submenu, thumbnails, 1s hover preview (NSPopover), cmd-click to open
- Batch upload summary notification (success count, error count, last file + URL)
- New settings: history size, copy URL after upload, open URL after upload
- Explicit Info.plist, removed stale asset reference; icons restored; target renamed
- SFTP service logs real mft vs fallback; fixed signing (disable library validation) for dev

## Next Steps (Shortlist)
- [x] Drag & drop: status item + Dock
- [x] Batch upload summary + history
- [ ] Notification module actions (copy/open buttons, deep links)
- [ ] Hook launch at login (SMAppService)
- [ ] Move SFTP password storage into Keychain
- [ ] Consider ATS exception or enforce https for thumbnail preview
- [ ] Port modular settings back to main app if needed

## Decisions
- Fixed width window for consistent layout; dynamic height only
- Localization via .xcstrings; helper `L(_:)`
- Explicit Info.plist maintained in repo (no auto-generate); CFBundleDocumentTypes declared
- Popover preview prefers left side, flips to right when insufficient space
- LSHandlerRank=Owner used for dev to stabilize Dock drop

## Patterns & Preferences
- MV(C) with small controllers (StatusBarController, Settings VCs)
- Preferences as a single source of truth; new flags: historyMaxEntries, copyURLAfterUpload, openURLAfterUpload
- Status bar drag via overlay NSView instead of extension override
- Register Apple Events in applicationWillFinishLaunching; reply(toOpenOrPrint:) on open events
- History persisted as JSON; thumbnail cache with async URLSession fetch

## Risks / Considerations
- Keep .xcstrings valid JSON (Xcode is strict)
- Maintain Info/entitlements alignment; signing and library validation for embedded mft
- ATS may block http thumbnail previews; consider exceptions if needed
- Notification Center and iconservices may cache icons after bundle/target rename; may require reboot

## Parking Lot
- Clear history UI action; show top-N errors in batch summary
