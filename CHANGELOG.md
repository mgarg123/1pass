# Changelog

All notable changes to the **1Pass** project are documented in this file.

---

## [1.2.2+20] - 2026-10-10

- **Update Dialog Color Polish**: Revamped button design and contrast with Electric Blue and Emerald Green actions and crisp white typography.
- **UI Harmonization**: Coordinated Sky Blue accents across dialog headers, progress indicators, and structured dark pill actions.

## [1.2.1+19] - 2026-10-10

- **Update Popup Revamp**: Modern dark glassmorphism dialog with "What's New" release notes.
- **Smart Package Caching**: Detects already-downloaded installer packages and enables instant 1-tap installation without re-downloading.
- **Accurate Download Progress**: Added real-time MB downloaded/total size metrics, percentage tracking, and cancel support.
- **Clean Version Display**: Removed raw build number (`+18`) from user-facing screens and version comparisons.
- **Build Fix**: Upgraded Kotlin Gradle Plugin to 2.2.20 for Android release build compatibility.

## [1.2.0+18] - 2026-10-10

- **Vault Homescreen Revamp**:
  - Added category filter pills with live counts (replaced 8-tab TabBar).
  - Added pinned favorites carousel with 1-tap copy.
  - Added proactive password health alert banner.
  - Added alphabetized section grouping with interior dividers.
  - Replaced add menu with 2×3 grid sheet.
- **Dedicated Item Type UIs**: Added dedicated screens for Secure Notes, Wi-Fi Networks, and Identity Profiles.
- **Google Branding**: Replaced placeholder 'G' with official 4-color vector Google logo and asset.
- **Backup & Tests**: Added backup serialization for new item types and test coverage.
  
## [1.1.4+17] - 2026-10-09

- Added Google Auth for cloud sync.
- Added MasterCard and recovery card support.
- Fixed mobile autofill stability.

## [1.1.3+16] - 2026-10-08

- Added 30-day Recently Deleted trash bin with auto-purge.
- Added multi-storage modes (Local, Cloud, BYOD).
- Added in-app update checker and About screen.
- Added passkey scaffolding.

## [1.1.2+15] - 2026-10-08

- Added custom fields for login items.
- Added password history tracking.
- Revamped password generator with Diceware passphrases.
- Separated view and edit screens.
- Added autosave for generated passwords.

## [1.1.1+14] - 2026-10-08

- Added credential pinning (favorites).
- Added website favicons.
- Added tag filter bar.
- Added inline TOTP display and quick card copy.

## [1.1.0+13] - 2026-10-07

- Added zero-knowledge encryption core (Argon2id + AES-256-GCM).
- Added biometric unlock and auto-lock engine.
- Added clipboard auto-clear (30s).
- Added Supabase cloud sync.
- Added OLED dark theme.
