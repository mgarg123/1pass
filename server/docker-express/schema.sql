-- OnePass BYOD — PostgreSQL Schema

CREATE TABLE IF NOT EXISTS vault_meta (
  id INTEGER PRIMARY KEY DEFAULT 1,
  salt TEXT NOT NULL,
  argon2_params JSONB NOT NULL,
  verification_blob TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vault_entries (
  id TEXT PRIMARY KEY,
  encrypted_data TEXT NOT NULL,
  nonce TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_entries_updated_at ON vault_entries(updated_at);
