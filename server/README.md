# OnePass BYOD — Reference Backend Implementations

This directory contains two reference implementations of the OnePass BYOD REST API contract. You only need **one** of these.

## Option 1: Cloudflare Worker + D1 (Recommended for simplicity)

**Cost:** Free (Cloudflare free tier)  
**Deploy time:** ~5 minutes  
**Best for:** Individual users who want zero-cost self-hosting

### Setup

```bash
cd cloudflare-worker

# 1. Create the D1 database
npx wrangler d1 create onepass-vault

# 2. Copy the database_id from the output into wrangler.toml

# 3. Initialize the schema
npx wrangler d1 execute onepass-vault --file=./schema.sql

# 4. Set your API key (you'll enter this in the 1Pass app)
npx wrangler secret put API_KEY

# 5. Deploy
npx wrangler deploy
```

Your endpoint URL will be: `https://onepass-byod-worker.<your-subdomain>.workers.dev`

---

## Option 2: Docker Compose (Postgres + Express)

**Cost:** Whatever your VPS costs  
**Deploy time:** ~10 minutes  
**Best for:** Users with a home server, NAS, or VPS

### Setup

```bash
cd docker-express

# 1. Create a .env file
echo "DB_PASSWORD=$(openssl rand -hex 16)" > .env
echo "API_KEY=$(openssl rand -hex 32)" >> .env

# 2. Start everything
docker-compose up -d

# 3. Verify
curl http://localhost:3000/health \
  -H "Authorization: Bearer YOUR_API_KEY"
```

Your endpoint URL will be: `http://your-server:3000`

> **Important:** Use HTTPS in production. Put this behind a reverse proxy (nginx, Caddy, Cloudflare Tunnel) with TLS.

---

## API Contract

All endpoints require `Authorization: Bearer <API_KEY>` header.

| Method | Path | Required | Description |
|--------|------|----------|-------------|
| GET | `/vault/meta` | ✅ | Get vault salt, argon2 params, verification blob |
| PUT | `/vault/meta` | ✅ | Create/update vault meta |
| GET | `/vault/entries?since=ISO8601` | ✅ | Pull entries (optionally filtered by update time) |
| PUT | `/vault/entries` | ✅ | Push/upsert entries |
| POST | `/vault/rotate-key` | ❌ Optional | Atomic master password rotation |
| OPTIONS | `/vault/rotate-key` | ❌ Optional | Capability probe (return 204 if supported) |

### Request/Response Formats

**GET /vault/meta** → Response:
```json
{
  "salt": "base64...",
  "argon2_params": { "memoryKB": 65536, "iterations": 3, "parallelism": 4, "hashLengthBytes": 32 },
  "verification_blob": "nonce:ciphertext:mac"
}
```

**PUT /vault/entries** → Request:
```json
{
  "entries": [
    {
      "id": "uuid",
      "encrypted_data": "nonce:ciphertext:mac",
      "nonce": "base64...",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "is_deleted": false
    }
  ]
}
```
