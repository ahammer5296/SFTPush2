# Progress Log

Keep this as a living log. Append entries; don’t rewrite history.

## Current Status (TL;DR)
- Проект переименован в SFTPush2; структура очищена
- Иконки восстановлены (меню‑бар, док, Privacy & Security)
- Drag & drop: на иконку в меню‑баре и в доке
- История загрузок с миниатюрами, превью по наведению, cmd‑клик открывает URL
- Пакетные загрузки: одно уведомление с итогами (успехи/ошибки, последний файл)
- Новые настройки: размер истории, копировать URL, открывать URL
 - Monosnap: опции копирования перед загрузкой и закрытия окна после загрузки с настраиваемой задержкой

## What works
- Menu bar icon + menu; Dock icon + animation
- Settings: General, SFTP, Clipboard & Hotkeys; новые флаги копирования/открытия URL и лимит истории
- Folder watcher + единый загрузочный пайплайн (SFTP via mft)
- Clipboard upload: подтверждение множественных, последовательная загрузка, очистка временных файлов
- Ограничение по размеру (папка + буфер), уведомления сообщают о превышении
- Drag & drop: статус‑иконка и Dock (CFBundleDocumentTypes + Apple Events)
- История: хранится в UserDefaults (JSON), миниатюры, превью, cmd‑клик
- Пакетные загрузки: одно финальное уведомление с последним URL
 - Интеграция с Monosnap: Cmd+C (опционально) перед загрузкой; Cmd+W после загрузки, учитывая задержку `monosnapCloseDelayMs`

## What’s left
- Notification actions (копировать/открыть из уведомления), deep links
- Launch at login (SMAppService)
- Move SFTP password into Keychain
- (Optional) ATS исключение для http‑превью или строго https

## Known issues
- В разделе Notifications иногда кешируется системная иконка после переименования; помогает перезагрузка/очистка кэша
- http‑превью миниатюр может блокироваться ATS (требуется https или исключение)

## Timeline (append at will)
- <date>: Created MenuBarProbe; modular settings and animations
- <date>: Implemented SFTP Upload Service (mft), path/baseURL mapping, factory with fallback
- <date>: Renamed to SFTPush2, fixed Dock drop (CFBundleDocumentTypes + Apple Events), added history + thumbnails + hover preview, batch summary
 - <2025‑10‑23>: Добавлена задержка закрытия Monosnap (UI + prefs); обновлены локализации и README; выпущен релиз v1.1 (title "SFTPush2 1.0"); добавлен auto‑tag workflow

## Decision Changes / Notes
- Switched from toolbar to segmented control for stability
- Explicit Info.plist maintained in repo; LSHandlerRank=Owner for dev
