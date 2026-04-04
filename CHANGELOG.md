# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] — 2026-04-04

### Encryption and storage

- **Optional on-disk encryption** — History (`history.json`) and favorites (`favorites.json`) under Application Support can be stored with **AES-256-GCM**. Plaintext is still JSON; ciphertext is prefixed with a `CLP1` version marker so the app can tell formats apart.
- **Keychain-backed key** — When encryption is enabled, a 256-bit symmetric key is created on first use and stored in the **login Keychain** (generic password: service `ClipboardApp.persistence`, account `clipboard-store-v1`), with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- **Preferences toggle** — **History → Encrypt history and favorites on disk** turns encryption on or off. Changing the setting **rewrites both files** immediately so on-disk format matches the preference.
- **Default: encryption off** — New installs and upgrades with no saved preference use **plain JSON** by default. Users who want protection can enable encryption in Preferences.
- **Migration** — Existing **plain** files are upgraded to encrypted on the next save after enabling encryption. Existing **encrypted** files still load when encryption is off (decrypt for use); toggling off rewrites them as plain JSON. If the on-disk envelope does not match the current setting after load, the store saves once to align format.

### Notes for users

- **Backups:** With encryption on, restoring only the JSON files to another Mac **will not** recover data unless the same Keychain secret is available; plan backups accordingly.
- **Dependencies:** Persistence uses **CryptoKit** and the **Security** framework (Keychain).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
