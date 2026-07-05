# 1Pass

1Pass is a zero-knowledge, open-source password manager where encryption happens entirely on-device. It uses a master password to locally derive a strong encryption key, encrypting all your sensitive data before it ever leaves your device. The cloud sync server only stores encrypted blobs, meaning your data remains strictly yours.

## Setup Instructions

### Prerequisites
- [Flutter](https://flutter.dev/docs/get-started/install) installed (Requires Flutter 3.22.0 or newer).
- A [Supabase](https://supabase.com/) project for cloud sync and authentication.

### Clone and Run
1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/one_pass.git
   cd one_pass
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Supabase Setup
1. Create a new project on [Supabase](https://supabase.com/).
2. Run the SQL migration files provided in the `supabase/` folder. In particular, execute `supabase/schema.sql` (if you are extracting it) or use the Supabase SQL editor to create the `user_vault_meta`, `vault_entries` tables, and the required RPC functions (e.g., `update_master_password`).
3. Set up your `.env` file in the root of the project:
   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```
   > **Note**: For any real public deployment, you **must** configure a custom SMTP server in your Supabase Auth settings. Supabase's default mailer is strictly rate-limited (2 emails/hour) and is not viable for real users.

## How the Encryption Works

- **Zero-Knowledge**: Your master password never leaves your device.
- **Key Derivation**: The app uses Argon2id to derive a strong encryption key locally from your master password and a randomly generated salt.
- **Client-Side Encryption**: Each entry in your vault is encrypted with AES-256-GCM *before* it touches local storage or the cloud.
- **Cloud Privacy**: The Supabase backend only ever stores encrypted blobs, a salt, and a verification blob. It never stores anything that reveals your actual passwords or your master password.

## Known Limitations

- **No Password Recovery**: If you forget your master password, your vault cannot be decrypted or recovered. There is no "forgot password" reset. This is an intentional security design, not a bug.
- **Sync Conflicts**: Conflict resolution is strictly "last-write-wins". Simultaneous offline edits on two different devices may silently overwrite each other.
- **No Browser Extension**: There is currently no browser extension or autofill integration.
- **No Sharing**: Password sharing between users is not supported.

## Contributing
Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to set up a dev environment, coding style expectations, and our pull request process.

## Security
If you discover a security vulnerability, please see [SECURITY.md](SECURITY.md) for reporting guidelines.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
