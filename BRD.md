Project Spec: Zero-Knowledge Encrypted Password Manager (Mobile-First, Flutter)

1. Project Overview

Build a cross-platform mobile password manager (Flutter, Android + iOS) with zero-knowledge encryption. The core principle: no one but the user — not even the backend — can ever see plaintext passwords or the master password. All encryption/decryption happens on-device. The cloud backend only ever stores encrypted, unreadable blobs.

This must be built entirely with free tools/services:


Flutter (free, open source)
Supabase (free tier: Postgres DB + Auth)
GitHub (free hosting, CI/CD via GitHub Actions)


2. Security Architecture (must be implemented exactly as specified)

2.1 Key derivation


Master password is never stored or transmitted anywhere, in any form (plain, hashed, encrypted).
On-device, derive an encryption key from the master password using Argon2id:

Memory cost: 64 MB minimum
Iterations: 3 minimum
Parallelism: 4
Output key length: 32 bytes (for AES-256)



Each user has a unique random salt (16 bytes, cryptographically secure random) generated at signup. Salt is NOT secret — store it alongside the encrypted blob in the cloud DB, and locally.


2.2 Encryption


Use AES-256-GCM for all vault data encryption.
Generate a new random nonce/IV (12 bytes) for every encryption operation. Never reuse a nonce with the same key.
GCM auth tag must be verified on decrypt (tamper detection) — reject and alert on failure, don't silently ignore.
Encrypt the entire vault as one JSON blob (array of credential entries), OR encrypt each entry individually (entry-level encryption is better for partial sync/merge — prefer this if feasible).


2.3 What the cloud backend is allowed to see


User's email (for auth) — via Supabase Auth
Encrypted blob(s) — random-looking bytes, base64 encoded
Salt (per user)
Nonces (per encrypted entry)
Timestamps (created_at, updated_at) for sync/conflict resolution
Never: master password, derived key, plaintext passwords, plaintext entry data


2.4 Local storage


Use hive (Flutter-native, fast, free) for local storage of encrypted entries — so the app works fully offline.
Derived encryption key should live only in memory during an active session (use flutter_secure_storage only for OS-keystore-backed biometric unlock convenience — not for storing the master password itself).
Auto-lock: clear the in-memory key after N minutes of inactivity or when app is backgrounded (configurable, default 2 minutes).


2.5 Biometric unlock (convenience layer only)


Biometric unlock (fingerprint/Face ID via local_auth) should unlock a locally-stored, OS-keystore-encrypted copy of the derived key — never bypass the actual encryption.
Master password must still be required on fresh install / after biometric reset / periodically.


3. Tech Stack

LayerChoiceWhyFrameworkFlutter (Dart)Free, single codebase for Android+iOSLocal DBHiveFast, lightweight, Flutter-nativeCloud backendSupabase (free tier)Postgres + free Auth, open sourceCryptocryptography package (Dart)Well-maintained, supports AES-GCM, Argon2idBiometricslocal_authStandard Flutter biometric pluginSecure key storageflutter_secure_storageWraps Android Keystore / iOS KeychainState managementRiverpod or ProviderYour choice — Riverpod recommendedCI/CDGitHub ActionsFree build automation

4. Data Model

Supabase table: vault_entries

sqlcreate table vault_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  encrypted_data text not null,      -- base64 AES-GCM ciphertext
  nonce text not null,               -- base64, 12 bytes
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  is_deleted boolean default false   -- soft delete for sync
);

create table user_vault_meta (
  user_id uuid references auth.users(id) primary key,
  salt text not null,                -- base64, 16 bytes, for Argon2id
  argon2_params jsonb not null       -- store memory/iterations/parallelism used
);

Row Level Security (RLS) must be enabled so users can only read/write their own rows:

sqlalter table vault_entries enable row level security;
create policy "Users can only access their own entries"
  on vault_entries for all
  using (auth.uid() = user_id);

Local Hive box structure

Each entry (decrypted, in-memory / local Hive box which is itself encrypted-at-rest via Hive's built-in AES support using the derived key):

json{
  "id": "uuid",
  "title": "Gmail",
  "username": "user@gmail.com",
  "password": "plaintext-only-in-memory-never-written-unencrypted",
  "url": "https://gmail.com",
  "notes": "optional",
  "tags": ["email", "personal"],
  "created_at": "...",
  "updated_at": "..."
}

5. App Screens / Features (MVP scope)


Onboarding / Signup

Create account (email + master password via Supabase Auth for the email identity — this is separate from the encryption key derivation)
Master password strength meter, confirm field
Generate & show salt, run Argon2id, derive key locally
Clear warning: "If you forget your master password, your data cannot be recovered."



Login

Email + master password
Fetch salt from user_vault_meta, derive key locally, decrypt vault
Biometric unlock option if previously enabled



Vault List

Search bar (search titles/usernames, client-side on decrypted data only)
List of entries with title, username, favicon/icon
Tap to view/copy password (auto-clear clipboard after 30s)
Folders/tags filter



Add/Edit Entry

Title, username, password, URL, notes, tags
Built-in password generator (length slider, symbol/number toggles)
Password strength indicator



Password Generator (standalone tool)

Configurable length, character sets
Copy to clipboard with auto-clear



Settings

Auto-lock timer
Biometric toggle
Change master password (re-encrypts entire vault with new derived key — must be handled carefully, see section 7)
Export encrypted backup (still encrypted, for user's own safekeeping)
Sync status / manual sync trigger





6. Sync Logic


On login / app resume (if online): pull all vault_entries for user where updated_at > last local sync timestamp.
On local change: encrypt entry, upsert to Supabase immediately if online; otherwise queue in a local "pending sync" Hive box and retry when connectivity returns.
Conflict resolution: last-write-wins based on updated_at timestamp (simplest for MVP — document this as a known limitation).
Soft delete: mark is_deleted = true rather than hard delete, so deletions sync properly across devices.


7. Change Master Password Flow (important edge case)


Verify current master password (derive key, attempt decrypt of a known entry or a stored verification value).
Derive new key from new master password + new random salt.
Decrypt all entries with old key, re-encrypt all with new key.
Upload all re-encrypted entries + new salt to Supabase in a single transaction if possible.
Only commit locally after cloud confirms success (to avoid lockout if it fails midway).


8. Non-Functional Requirements


App must function fully offline (local vault always accessible once unlocked).
No plaintext password should ever be written to disk, logs, or crash reports. Explicitly disable/scrub logging of sensitive fields in debug and release builds.
Use certificate pinning or at least enforce HTTPS/TLS for all Supabase calls (Supabase client does this by default — verify).
Clipboard auto-clear after copying any password.
Screenshot/screen-recording prevention on the vault screen (Android: FLAG_SECURE; iOS: appropriate equivalent).


9. Suggested Build Order (phases for the AI agent)

Phase 1 — Crypto core (no UI)


Implement Argon2id key derivation function
Implement AES-256-GCM encrypt/decrypt functions
Unit tests: encrypt → decrypt round trip, tamper detection (modify ciphertext, confirm decryption fails), wrong password fails


Phase 2 — Local-only vault (offline MVP)


Flutter UI: signup/login screen (local only, no cloud yet) using master password → derive key → store salt locally
Hive local storage wired to crypto core
Vault list, add/edit/delete entry, password generator
Auto-lock on inactivity/background


Phase 3 — Supabase integration


Set up Supabase project, create tables + RLS policies (SQL above)
Wire up Supabase Auth (email/password) for account identity
Push/pull encrypted blobs, implement sync logic + pending-sync queue


Phase 4 — Convenience features


Biometric unlock via local_auth + flutter_secure_storage
Change master password flow
Export/import encrypted backup


Phase 5 — Polish & hardening


Screenshot prevention
Clipboard auto-clear
Empty states, error handling, offline indicators
README with setup instructions, threat model documentation


10. Deliverables Expected from the AI Agent


Flutter project scaffolded with clean architecture (separate crypto/, data/, sync/, ui/ layers)
SQL migration file for Supabase schema
Unit tests for crypto layer (non-negotiable — this is the part that must not have bugs)
README explaining: setup steps, how to run, how encryption works, known limitations (e.g., last-write-wins conflict resolution, no password recovery if master password is lost)


11. Explicit Non-Goals (for MVP, mention to avoid scope creep)


No browser extension/autofill yet (future phase)
No password sharing between users (future phase)
No multi-factor recovery mechanism (by design — zero-knowledge means no recovery without the master password; do not build a "reset password and keep data" flow, as that would break the security model)