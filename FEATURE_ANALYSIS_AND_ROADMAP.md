# 1Pass: Feature Analysis, Gap Assessment & Prioritized Roadmap

This document provides a comprehensive technical audit of the **1Pass** application against production industry standards (such as Bitwarden, 1Password, Proton Pass, and KeePassXC). It categorizes capabilities into **Completed Features**, **Incomplete / Work-in-Progress Features**, and **Completely Missing Features**, each assigned an explicit engineering priority (**P0**, **P1**, **P2**, **P3**).

---

## 1. Priority Legend & Matrix

| Priority | Level | Definition |
| :--- | :--- | :--- |
| **P0** | **Critical / Blocker** | Must-have for production launch; blocks user adoption, data migration, or core usability. |
| **P1** | **High Priority** | Core competitive features; essential for desktop daily workflow and ecosystem completeness. |
| **P2** | **Medium Priority** | Advanced capabilities that elevate the app from good to great (multi-vaults, secure sharing). |
| **P3** | **Low / Polish** | Power-user tools, CLI, developer workflows, and specialized niche additions. |

---

## 2. Completed Features (What is Already Built & Working)

| Category | Feature | Status | Technical Implementation |
| :--- | :--- | :---: | :--- |
| **Cryptography** | **Zero-Knowledge Core** | ✅ Done | On-device key derivation using Argon2id; AES-256-GCM authenticated encryption. |
| | **Tamper Detection** | ✅ Done | Strict GCM MAC verification on decryption; fails on single-byte mutation. |
| | **Emergency Recovery Key** | ✅ Done | 120-bit random Crockford alphanumeric key (`OP-XXXX-...`) with separate Argon2id salt. |
| | **Master Password Rotation** | ✅ Done | Re-encrypts entire vault with fresh derived key and updates cloud verification blob atomically. |
| **Storage & Sync** | **Local-Only Storage** | ✅ Done | Encrypted Hive database on-device; full offline usability. |
| | **Supabase Cloud Sync** | ✅ Done | Row-Level Security (RLS) policies, soft-deletion (`is_deleted`), and timestamp sync. |
| | **BYOD Sync Backend** | ✅ Done | Generic REST API client + Cloudflare D1 and Docker Express reference backends. |
| | **Offline Sync Queue** | ✅ Done | Local `pending_sync` box caches mutations and pushes automatically upon reconnecting. |
| **Vault Items** | **Login Credentials** | ✅ Done | Title, username, password, URL, notes, custom fields, tags, and favorites. |
| | **Credit Cards** | ✅ Done | Cardholder name, card number, expiry date, CVV, PIN, issuing bank. |
| | **Authenticator (2FA/TOTP)** | ✅ Done | RFC 6238 TOTP generator, live countdown progress bar, QR code camera scanner, and image picker. |
| | **Password History** | ✅ Done | Saves previous passwords and update timestamps on entry modification. |
| | **Custom Fields** | ✅ Done | Key-value pairs with obscured/visible toggles. |
| | **Trash / Soft Delete** | ✅ Done | Recently Deleted items screen with 30-day restore and permanent hard deletion. |
| **Security Tools** | **Password Health Audit** | ✅ Done | Flags weak passwords, reused/duplicate passwords, and stale passwords (>1 year). |
| | **Breach Monitoring** | ✅ Done | Anonymous HaveIBeenPwned API check using 5-character SHA-1 prefix (k-Anonymity). |
| | **Biometric Unlock** | ✅ Done | Fingerprint and Face ID via `local_auth` and `flutter_secure_storage`. |
| | **Auto-Lock Engine** | ✅ Done | Inactivity timer (30s, 1m, 2m, 5m, never) and background auto-lock. |
| | **Clipboard Auto-Clear** | ✅ Done | Automatically scrubs copied passwords/TOTP codes from OS clipboard after 30 seconds. |
| **Utilities & UI** | **Password & Passphrase Generator** | ✅ Done | Configurable length/symbols and EFF Diceware passphrase generator with unbiased random sampling. |
| | **OLED Dark Theme** | ✅ Done | Black and Neon Violet Material 3 UI with `flutter_animate` transitions and search/filtering. |
| | **In-App Updater** | ✅ Done | Direct GitHub release check and APK/asset update dialog. |

---

## 3. Incomplete / Work-in-Progress Features (With Priority)

| Feature | Priority | Current State | Required Work to Complete |
| :--- | :---: | :--- | :--- |
| **iOS Autofill Credential Provider** | **P0** | Extension files present, but methods are stubbed (`CredentialProviderViewController.swift`). | Implement App Group Keychain sharing between app and extension, query cached vault items, and authenticate with Face ID / Touch ID. |
| **Field-Level Sync Conflict Merging** | **P0** | Uses basic Last-Write-Wins (LWW) timestamp check; risks field overwrites. | Implement attribute-level 3-way merging or branch conflicting offline edits into duplicate items (`Title (Conflicted Copy)`). |
| **Complete Missing Item Type UIs** | **P0** | Enums exist for `secureNote`, `wifi`, `identity`, but open generic login editor. | Build dedicated UI forms: Markdown for notes, SSID/security/QR for Wi-Fi, and address/SSN fields for identity. |
| **Passkey / WebAuthn Support** | **P1** | Android 14+ channel scaffolded; fields exist on `VaultEntry`. | Implement full FIDO2 registration ceremony, assertion signing, and cross-platform passkey sync across iOS, Android, and Desktop. |
| **Realtime Push Synchronization** | **P1** | Sync occurs on app start, resume, save, or manual pull. | Add Supabase Realtime WebSocket listener / SSE so edits on one device reflect instantly on all other open devices. |

---

## 4. Completely Missing Features (Detailed Gap Analysis & Priority)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        COMPLETELY MISSING SUITE                        │
├───────────────────┬────────────────────┬───────────────────────────────┤
│ 1. Ecosystem      │ 2. Vault Features  │ 3. Security & Admin           │
│ • Browser Ext. P1 │ • Multi-Vaults  P2 │ • Account 2FA (TOTP)       P0 │
│ • Desktop HotkeyP2│ • File Attach.  P1 │ • 2FA Website Scanner      P1 │
│ • Developer CLI P3│ • Secure Send   P2 │ • Emergency Kit PDF        P0 │
│ • 3rd-Party Imp.P0│ • Rich Markdown P1 │ • Dark Web Email Alerts    P2 │
└───────────────────┴────────────────────┴───────────────────────────────┘
```

### 4.1 Migration, Import & Export

- **`[P0]` Third-Party Vault Importers**:
  - *Why Critical*: New users will not switch to 1Pass unless they can import their existing vaults.
  - *Formats Needed*: Bitwarden (`.json`, `.csv`), 1Password (`.1pux`, `.csv`), LastPass (`.csv`), Chrome / Safari / Firefox (`.csv`), KeePass (`.kdbx`, `.xml`), Apple Passwords (`.csv`).
- **`[P0]` Printable Emergency Kit PDF**:
  - *Why Critical*: 1Password-style printable PDF sheet with user email, recovery key QR code, account URL, and space to write the master password. Essential safety net for zero-knowledge recovery.
- **`[P0]` Plaintext / Unencrypted CSV/JSON Export**:
  - Export feature for user data portability with master password confirmation and clear security warning.

### 4.2 Ecosystem & Platform Integrations

- **`[P1]` Browser Extension (Chrome, Firefox, Safari, Edge, Arc, Brave)**:
  - *Why High Priority*: The primary interface for users on laptops/desktops. Manifest V3 extension for autofill, inline TOTP generation, and automatic password capture on signup.
- **`[P2]` Desktop Quick Access Overlay (Global Hotkey)**:
  - Floating search bar accessible via shortcut (`Cmd+Shift+Space` or `Ctrl+Shift+Space`) to copy or fill credentials without switching windows.
- **`[P3]` Developer CLI (`1pass` / `op` equivalent)**:
  - Command-line tool for fetching secrets, injecting environment variables (`1pass run -- npm start`), and managing API keys in CI/CD.

### 4.3 Vault Organization & Collaboration

- **`[P1]` End-to-End Encrypted File & Document Attachments**:
  - Upload photos, PDFs, driver's licenses, or recovery codes to any vault item, encrypted client-side with AES-GCM before uploading to cloud storage.
- **`[P2]` Multi-Vault Architecture**:
  - Separate, independent vaults per account (e.g., *Personal*, *Work*, *Financial*, *Family*) with individual lock/view filters.
- **`[P2]` Nested Folders & Collections**:
  - Structured folder hierarchy in addition to tags for organizing 1,000+ item vaults.
- **`[P2]` One-Time Secure Send (Bitwarden Send / 1Password Psst)**:
  - Share a single encrypted password or file with non-users via a temporary web link that expires after N views or N hours.
- **`[P3]` Emergency Access (Digital Legacy)**:
  - Designate a trusted contact who can request vault access after a mandatory waiting period (e.g., 7 days) unless rejected by the user.

### 4.4 Advanced Security & Auditing

- **`[P0]` Two-Factor Authentication (2FA) for Cloud Account**:
  - *Why Critical*: Protect the Supabase cloud sync account with Authenticator TOTP or FIDO2/WebAuthn hardware keys (YubiKey) to prevent unauthorized remote deletion or sync disruption.
- **`[P1]` 2FA Website Gap Scanner**:
  - Scan vault logins against the 2FA Directory database to alert users when their saved sites support 2FA but have no TOTP configured.
- **`[P2]` Dark Web Email Breach Monitoring**:
  - Continuous monitoring of user-registered email addresses to notify them when an email appears in newly leaked public breaches.
- **`[P2]` Active Session & Device Management**:
  - Settings screen listing all active devices, OS versions, IP locations, and last active timestamps with remote revocation / sign-out.
- **`[P3]` Configurable KDF Security Sliders**:
  - Allow advanced users to customize Argon2id parameters (Memory: 64MB–1GB, Iterations: 3–10) based on their device capability.

### 4.5 UI/UX, Customization & Production Readiness

- **`[P1]` Internationalization (i18n / l10n)**:
  - Externalize all UI strings to `.arb` localization files with `flutter_localizations` (Spanish, German, French, Chinese, Japanese, etc.).
- **`[P1]` High-Res Website Favicon Proxy**:
  - Fetch and cache crisp domain icons using a privacy-preserving proxy instead of generic letter avatars.
- **`[P1]` Light Theme & Accent Color Customization**:
  - Light mode, System Adaptive mode, and customizable accent colors (Violet, Blue, Emerald, Amber, Rose).
- **`[P2]` Tablet & Desktop Master-Detail Split-View**:
  - Responsive multi-column layout for iPads, Android tablets, macOS, and Windows.
- **`[P2]` Zero-Knowledge Crash Reporting**:
  - Integration with Sentry/Crashlytics with automated data scrubbing to ensure no secrets or decrypted payloads ever leak to logs.
- **`[P3]` Home Screen App Shortcuts**:
  - Long-press icon shortcuts for: *Search*, *New Login*, *Password Generator*, *Scan QR*.

---

## 5. Prioritized Phased Implementation Roadmap

```mermaid
flowchart TD
    subgraph Phase 1: Core Parity & Migration [P0 Focus - Immediate]
        P1_1[iOS Autofill Provider]
        P1_2[3rd-Party Importers: Bitwarden, 1Pass, CSV]
        P1_3[Dedicated UI: Notes, Wi-Fi, Identity]
        P1_4[Printable Emergency Kit PDF]
        P1_5[Field-Level Conflict Merging]
        P1_6[Cloud Account 2FA]
    end

    subgraph Phase 2: Desktop & Browser Ecosystem [P1 Focus]
        P2_1[Browser Extension Manifest V3]
        P2_2[Realtime WebSocket Sync]
        P2_3[Encrypted File Attachments]
        P2_4[2FA Website Gap Scanner]
        P2_5[i18n & Light/Adaptive Themes]
    end

    subgraph Phase 3: Advanced Vaults & Sharing [P2 Focus]
        P3_1[Multi-Vault Support & Folders]
        P3_2[One-Time Secure Send Links]
        P3_3[Desktop Quick Access Overlay]
        P3_4[Dark Web Email Breach Monitor]
        P3_5[Active Session Management]
    end

    subgraph Phase 4: Developer Tools & Hardening [P3 Focus]
        P4_1[Developer CLI Tool]
        P4_2[Emergency Access Digital Legacy]
        P4_3[Configurable Argon2id Sliders]
        P4_4[App Store & Play Store CI/CD Fastlane]
    end

    Phase 1 --> Phase 2 --> Phase 3 --> Phase 4
```

### Phase 1: Core Parity & Migration (P0 Items — Immediate Focus)
1. **iOS Autofill Integration**: Complete `CredentialProviderViewController.swift` with App Group Keychain sharing.
2. **Third-Party Importers**: Build parsers for Bitwarden (.json/.csv), 1Password (.1pux/.csv), LastPass, Chrome, and Apple Passwords.
3. **Missing Item Type Screens**: Dedicated forms for *Secure Notes* (with markdown), *Wi-Fi Passwords*, and *Identities*.
4. **Printable Emergency Kit PDF**: Generate downloadable/printable PDF with account details and recovery key QR code.
5. **Attribute-Level Sync Merge**: Implement 3-way conflict resolution to eliminate overwrite risks.
6. **Cloud Account 2FA**: Add TOTP 2FA requirement to Supabase Auth login.

### Phase 2: Ecosystem & Browser Extension (P1 Items)
1. **Browser Extension**: Manifest V3 extension for Chrome/Firefox/Safari for autofill and credential capture.
2. **Realtime Push Sync**: Enable live WebSocket updates so changes sync across devices instantly.
3. **Encrypted Attachments**: Add client-side AES-GCM encrypted file uploads to vault items.
4. **2FA Website Gap Scanner**: Cross-reference logins against the 2FA Directory to prompt users to enable TOTP.
5. **Internationalization & Theming**: Add `.arb` localization files, Light Mode, and Favicon proxy caching.

### Phase 3: Advanced Vaults & Secure Sharing (P2 Items)
1. **Multi-Vault Architecture**: Add multiple independent vaults (*Personal*, *Work*, *Shared*) and folder hierarchies.
2. **One-Time Secure Send**: Create self-destructing end-to-end encrypted secret share links.
3. **Desktop Quick Access Overlay**: Build global search hotkey overlay for macOS, Windows, and Linux.
4. **Dark Web Email Monitor & Session Manager**: Background email leak checks and active device management.

### Phase 4: Developer Tools & Final Hardening (P3 Items)
1. **Developer CLI (`1pass`)**: Secret injection and terminal management tool.
2. **Emergency Access (Digital Legacy)**: Trusted contact recovery protocol.
3. **Configurable KDF Sliders**: Custom Argon2id memory and iteration settings.
4. **Production CI/CD Automation**: Fastlane deployment pipelines for App Store and Google Play.
