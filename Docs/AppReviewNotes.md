# App Review Notes

Clippy is a sandboxed macOS clipboard history utility. The app stores clipboard history locally in its app container and does not use accounts, cloud sync, analytics, advertising, tracking, or network access.

Clipboard monitoring is enabled only after first-run onboarding explains what Clippy captures. Users can pause capture, clear history, delete individual entries, exclude apps, and disable clipboard capture from Settings.

Accessibility permission is optional. It is used only to send a paste keystroke after the user selects a history item. Without Accessibility permission, Clippy still copies the selected item back to the pasteboard and shows a copy-only state.

Launch at login is opt-in and uses Apple's Service Management API.

The app supports text, URLs, and images. Image payloads are stored as files inside the app container and linked from local metadata.
