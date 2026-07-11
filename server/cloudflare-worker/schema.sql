-- OnePass BYOD — D1 (SQLite) Schema
-- Run: npx wrangler d1 execute onepass-vault --file=./schema.sql

CREATE TABLE IF NOT EXISTS vault_meta (
  id INTEGER PRIMARY KEY DEFAULT 1,
  salt TEXT NOT NULL,
  argon2_params TEXT NOT NULL, -- JSON string
  verification_blob TEXT NOT NULL,
  updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS vault_entries (
  id TEXT PRIMARY KEY,
  encrypted_data TEXT NOT NULL,
  nonce TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_deleted INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_entries_updated_at ON vault_entries(updated_at);
