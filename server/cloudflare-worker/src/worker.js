/**
 * OnePass BYOD Reference Implementation
 * Cloudflare Worker + D1 (SQLite)
 *
 * Implements the 4 required + 1 optional OnePass BYOD REST endpoints.
 *
 * Setup:
 *   1. npx wrangler d1 create onepass-vault
 *   2. Update wrangler.toml with the database_id
 *   3. npx wrangler d1 execute onepass-vault --file=./schema.sql
 *   4. npx wrangler secret put API_KEY
 *   5. npx wrangler deploy
 */

export default {
  async fetch(request, env) {
    // ── Auth ──
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || authHeader !== `Bearer ${env.API_KEY}`) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    try {
      // ── CORS preflight ──
      if (method === 'OPTIONS') {
        return new Response(null, { status: 204, headers: corsHeaders() });
      }

      // ── GET /vault/meta ──
      if (path === '/vault/meta' && method === 'GET') {
        const row = await env.DB.prepare('SELECT * FROM vault_meta WHERE id = 1').first();
        if (!row) return json(null, 404);
        return json({
          salt: row.salt,
          argon2_params: JSON.parse(row.argon2_params),
          verification_blob: row.verification_blob,
        });
      }

      // ── PUT /vault/meta ──
      if (path === '/vault/meta' && method === 'PUT') {
        const body = await request.json();
        await env.DB.prepare(
          `INSERT INTO vault_meta (id, salt, argon2_params, verification_blob, updated_at)
           VALUES (1, ?, ?, ?, datetime('now'))
           ON CONFLICT(id) DO UPDATE SET
             salt = excluded.salt,
             argon2_params = excluded.argon2_params,
             verification_blob = excluded.verification_blob,
             updated_at = datetime('now')`
        )
          .bind(body.salt, JSON.stringify(body.argon2_params), body.verification_blob)
          .run();
        return json({ ok: true });
      }

      // ── GET /vault/entries ──
      if (path === '/vault/entries' && method === 'GET') {
        const since = url.searchParams.get('since');
        let rows;
        if (since) {
          rows = await env.DB.prepare(
            'SELECT * FROM vault_entries WHERE updated_at > ?'
          ).bind(since).all();
        } else {
          rows = await env.DB.prepare('SELECT * FROM vault_entries').all();
        }
        const entries = (rows.results || []).map(r => ({
          id: r.id,
          encrypted_data: r.encrypted_data,
          nonce: r.nonce,
          created_at: r.created_at,
          updated_at: r.updated_at,
          is_deleted: r.is_deleted === 1,
        }));
        return json(entries);
      }

      // ── PUT /vault/entries ──
      if (path === '/vault/entries' && method === 'PUT') {
        const body = await request.json();
        const entries = body.entries || [];
        for (const entry of entries) {
          await env.DB.prepare(
            `INSERT INTO vault_entries (id, encrypted_data, nonce, created_at, updated_at, is_deleted)
             VALUES (?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET
               encrypted_data = excluded.encrypted_data,
               nonce = excluded.nonce,
               updated_at = excluded.updated_at,
               is_deleted = excluded.is_deleted`
          )
            .bind(
              entry.id,
              entry.encrypted_data,
              entry.nonce,
              entry.created_at,
              entry.updated_at,
              entry.is_deleted ? 1 : 0
            )
            .run();
        }
        return json({ ok: true, count: entries.length });
      }

      // ── POST /vault/rotate-key (optional — atomic rotation) ──
      if (path === '/vault/rotate-key' && method === 'POST') {
        const body = await request.json();

        // Use a batch for atomicity (D1 batches are transactional)
        const statements = [];

        // Update meta
        statements.push(
          env.DB.prepare(
            `INSERT INTO vault_meta (id, salt, argon2_params, verification_blob, updated_at)
             VALUES (1, ?, ?, ?, datetime('now'))
             ON CONFLICT(id) DO UPDATE SET
               salt = excluded.salt,
               argon2_params = excluded.argon2_params,
               verification_blob = excluded.verification_blob,
               updated_at = datetime('now')`
          ).bind(body.salt, JSON.stringify(body.argon2_params), body.verification_blob)
        );

        // Update entries
        for (const entry of body.entries || []) {
          statements.push(
            env.DB.prepare(
              `UPDATE vault_entries
               SET encrypted_data = ?, updated_at = ?
               WHERE id = ?`
            ).bind(entry.encryptedData, entry.updatedAt, entry.id)
          );
        }

        await env.DB.batch(statements);
        return json({ ok: true });
      }

      // ── OPTIONS /vault/rotate-key (capability probe) ──
      if (path === '/vault/rotate-key' && method === 'OPTIONS') {
        return new Response(null, { status: 204, headers: corsHeaders() });
      }

      return json({ error: 'Not found' }, 404);
    } catch (err) {
      return json({ error: err.message }, 500);
    }
  },
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(),
    },
  });
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, PUT, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
}
