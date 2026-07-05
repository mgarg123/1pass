# Threat Model

1Pass is designed with security and zero-knowledge privacy as its primary goals. This document outlines what the application is designed to protect against, and importantly, what it is **not** designed to protect against. 

Please read this carefully to understand the security guarantees and limitations of 1Pass before trusting it with your sensitive data.

## What 1Pass Protects Against

1Pass provides robust protection against the following threats:

*   **Server / Database Breach:** If the backend (Supabase) is compromised, attackers will only obtain encrypted blobs, random salts, and verification blobs. Because all encryption and decryption happens exclusively on your device, the attacker gains no access to plaintext passwords or your master password.
*   **Device Theft (While App is Locked):** Vault data stored locally on your disk is encrypted using AES-256-GCM. Without your master password (or a valid biometric-unlocked session tied to your device's secure enclave), the data remains unreadable.
*   **Network Interception:** All traffic to and from the Supabase backend is transmitted over TLS. Furthermore, even if the TLS encryption were broken or bypassed, the payloads themselves are already encrypted client-side, rendering intercepted traffic useless to attackers.

## What 1Pass Does NOT Protect Against

No system is entirely foolproof. 1Pass explicitly does **not** protect against:

*   **Compromised / Malware-Infected Devices:** If your device is infected with malware that has root access, accessibility permissions, or the ability to read process memory while the vault is unlocked, the malware could potentially extract your decrypted passwords or your master password.
*   **Keyloggers & Screen Recorders:** Malware or hardware that logs your keystrokes or records your screen can capture your master password as you type it.
*   **Weak Master Passwords:** The security of your entire vault relies on the strength of your master password. While the app includes a strength meter, it cannot prevent you from choosing a weak, easily guessable, or reused password. 
*   **Physical Coercion / Shoulder Surfing:** We cannot protect against someone physically forcing you to unlock your vault, or someone watching you type your master password.
*   **Supabase Account Compromise (App Login):** The credential you use to log in to the Supabase authentication layer is a standard password subject to normal risks. If an attacker gains access to your Supabase account, they could potentially delete your remote encrypted vault or disrupt syncing. We highly recommend enabling any available account security options (like 2FA) on your Supabase provider, even though this does not grant the attacker access to decrypt your vault data.

> **Crucial Note:** By design, there is **no password recovery**. If you forget your master password, your data is permanently lost.
