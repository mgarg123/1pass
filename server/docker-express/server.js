/**
 * OnePass BYOD Reference Implementation
 * Express + PostgreSQL
 *
 * Implements the 4 required + 1 optional OnePass BYOD REST endpoints.
 *
 * Setup:
 *   1. Copy .env.example to .env and configure
 *   2. docker-compose up -d
 *
 * Or run standalone:
 *   1. npm install
 *   2. Set DATABASE_URL and API_KEY env vars
 *   3. node server.js
 */

const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json({ limit: '50mb' }));

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const API_KEY = process.env.API_KEY || 'your-secret-api-key';
const PORT = process.env.PORT || 3000;

// ── Auth Middleware ──
function authenticate(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || auth !== `Bearer ${API_KEY}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

app.use(authenticate);

// ── GET /vault/meta ──
app.get('/vault/meta', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM vault_meta WHERE id = 1');
    if (rows.length === 0) return res.status(404).json(null);
    const row = rows[0];
    res.json({
      salt: row.salt,
      argon2_params: row.argon2_params,
      verification_blob: row.verification_blob,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── PUT /vault/meta ──
app.put('/vault/meta', async (req, res) => {
  try {
    const { salt, argon2_params, verification_blob } = req.body;
    await pool.query(
      `INSERT INTO vault_meta (id, salt, argon2_params, verification_blob, updated_at)
       VALUES (1, $1, $2, $3, NOW())
       ON CONFLICT (id) DO UPDATE SET
         salt = EXCLUDED.salt,
         argon2_params = EXCLUDED.argon2_params,
         verification_blob = EXCLUDED.verification_blob,
         updated_at = NOW()`,
      [salt, JSON.stringify(argon2_params), verification_blob]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /vault/entries ──
app.get('/vault/entries', async (req, res) => {
  try {
    const since = req.query.since;
    let result;
    if (since) {
      result = await pool.query(
        'SELECT * FROM vault_entries WHERE updated_at > $1',
        [since]
      );
    } else {
      result = await pool.query('SELECT * FROM vault_entries');
    }
    const entries = result.rows.map(r => ({
      id: r.id,
      encrypted_data: r.encrypted_data,
      nonce: r.nonce,
      created_at: r.created_at,
      updated_at: r.updated_at,
      is_deleted: r.is_deleted,
    }));
    res.json(entries);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── PUT /vault/entries ──
app.put('/vault/entries', async (req, res) => {
  try {
    const entries = req.body.entries || [];
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const entry of entries) {
        await client.query(
          `INSERT INTO vault_entries (id, encrypted_data, nonce, created_at, updated_at, is_deleted)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO UPDATE SET
             encrypted_data = EXCLUDED.encrypted_data,
             nonce = EXCLUDED.nonce,
             updated_at = EXCLUDED.updated_at,
             is_deleted = EXCLUDED.is_deleted`,
          [entry.id, entry.encrypted_data, entry.nonce, entry.created_at, entry.updated_at, entry.is_deleted]
        );
      }
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
    res.json({ ok: true, count: entries.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── POST /vault/rotate-key (optional — atomic rotation) ──
app.post('/vault/rotate-key', async (req, res) => {
  try {
    const { salt, argon2_params, verification_blob, entries } = req.body;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Update meta
      await client.query(
        `INSERT INTO vault_meta (id, salt, argon2_params, verification_blob, updated_at)
         VALUES (1, $1, $2, $3, NOW())
         ON CONFLICT (id) DO UPDATE SET
           salt = EXCLUDED.salt,
           argon2_params = EXCLUDED.argon2_params,
           verification_blob = EXCLUDED.verification_blob,
           updated_at = NOW()`,
        [salt, JSON.stringify(argon2_params), verification_blob]
      );

      // Update entries
      for (const entry of entries || []) {
        await client.query(
          `UPDATE vault_entries
           SET encrypted_data = $1, updated_at = $2
           WHERE id = $3`,
          [entry.encryptedData, entry.updatedAt, entry.id]
        );
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Capability probe (OPTIONS) ──
app.options('/vault/rotate-key', (req, res) => {
  res.status(204).end();
});

// ── Health check ──
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok' });
  } catch (err) {
    res.status(500).json({ status: 'error', error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`OnePass BYOD server running on port ${PORT}`);
});
