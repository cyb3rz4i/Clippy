# App Review Notes

Clippy is a macOS clipboard history utility. The app stores clipboard history locally and does not use accounts, cloud sync, analytics, advertising, tracking, or network access.

Clipboard monitoring is enabled only after first-run onboarding explains what Clippy captures. Users can pause capture, clear history, delete individual entries, exclude apps, and disable clipboard capture from Settings.

Selecting a history item writes it back to the pasteboard. If the user enables auto-paste and grants macOS Accessibility permission, Clippy reactivates the prior app and sends Command-V; otherwise it falls back to copy-only behavior.

Launch at login is an optional user-controlled setting and uses Apple's Service Management API.

The app supports text, URLs, and image clipboard history. Image payloads are stored as local files and linked from local metadata inside Clippy's Application Support storage.
