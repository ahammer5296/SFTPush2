# Product Context

## Why this project exists
- Give macOS users a single, reliable place to ship screenshots and recordings
- Remove manual SFTP steps so uploads happen from the menu bar or clipboard
- Keep creative flow intact by automating copy, upload, and notification loops

## Problems it solves
- Manual juggling of SFTP clients, Finder, and clipboard tools
- Missed or duplicated uploads when juggling multiple capture sources
- No feedback when automated uploads fail or exceed quotas
- Fragmented shortcuts and settings between main app and helper utilities

## How it should work (high-level)
- Menu bar macOS app with a focused Settings surface
- Core modules: Folder Watcher, Upload Service, Hotkey Handler, Notification Center
- SFTP upload pipeline accepts files from watch folders, drag & drop, or clipboard
- Clear, minimally obtrusive feedback for success and failure states

## User experience goals
- Fast one-action upload from clipboard/hotkey
- Clear feedback (menu bar animation + notifications)
- Safe defaults; advanced options in Settings

## Primary user journeys (draft)
1) Folder monitoring: new file arrives, size checked, uploaded, moved to status folder, notify
2) Drag or drop onto menu bar / dock icon: size checked, uploaded without relocation, notify
3) Clipboard upload via menu item or hotkey: detect files or media, confirm multiples, upload, notify

## Edge cases
- Oversized files, offline server, bad credentials, permissions prompts
- Clipboard content with unsupported formats
- Drag/drop of large batches or non-file items

## Open questions
- Exact SFTP auth policy, base URL mapping rules, rename format
- Clipboard confirmation UX for multiple files
- Localization of notification copy and prompts

## Implementation modules
- Folder Watcher: observes target folder, validates size, routes uploaded/error files, queues notifications
- Upload Service: performs SFTP transfers, handles clipboard and drag/drop ingestion, maps server paths
- Hotkey Handler: records and listens for global shortcut, manages optional pre-copy logic
- Notification Center: presents success/failure toasts including filename and reason when blocked

## Detailed workflows
### Folder monitoring
- Watch configured folder; on new file validate against size limit
- Upload when within limit; move to `Uploaded` folder on success
- When blocked (oversize or upload error), move file to `Error`
- Emit notification summarizing outcome and reason

### Drag & drop (menu bar or dock icon)
- Validate dragged file size before upload
- Upload without relocating file on success or failure
- Emit notification with success or failure reason

### Clipboard uploads (menu action or hotkey)
- Inspect clipboard for files first; if multiple valid items, ask for confirmation
- For a single file, upload directly; for multiple, upload after confirmation
- When no files, check for image or video data; create temporary file for upload
- Respect size limits and emit notifications with result

### Hotkey trigger specifics
- Optional pre-copy: send `cmd+c` to Monosnap only, or to active app based on settings
- After upload, optionally send `cmd+w` to close Monosnap window
- Reuse clipboard workflow logic for validation, confirmation, and notifications
