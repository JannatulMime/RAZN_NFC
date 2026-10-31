# NTAG213 / NTAG215 Offline UID Password Derivation

## Algorithm (v1)

Applies to **NTAG213 and NTAG215** (same inputs and outputs for a given UID). Domain separator strings retain the historical `NTAG215` name and must not change.

| Input | Rule |
|-------|------|
| UID | Exactly **7 raw bytes** from tag memory: page 0 bytes `[0..2]` + page 1 bytes `[0..3]` (UID0…UID6). Do **not** hash colon/hex display strings. |
| Master key | ≥ 32 raw bytes from build-injected hex (`RAZN_NFC_MASTER_KEY_HEX`). |

```
PWD  = HMAC-SHA256(key, UTF8("RAZN-NTAG215-PWD-v1")  || UID)[0..3]
PACK = HMAC-SHA256(key, UTF8("RAZN-NTAG215-PACK-v1") || UID)[0..1]
```

CryptoKit `HMAC<SHA256>` on iOS. The same rules must be used by any external provisioning tool.

**NTAG216** (Tag Manager only) still uses the legacy shared password `AADDCCBB` and `PACK = SHA256(PWD)[0..1]`.

## How to inject the master key

1. Copy `Config/Secrets.xcconfig.example` → `Config/Secrets.xcconfig`.
2. Set a **64-character hex** (32-byte) value:

```
RAZN_NFC_MASTER_KEY_HEX = YOUR_64_CHAR_HEX_KEY_HERE
```

3. `Config/Secrets.xcconfig` is **gitignored**. Never commit a production key.
4. The app target uses `Config/RAZN-NFC.xcconfig`, which optionally includes `Secrets.xcconfig`.
5. `RAZN-NFC-Info.plist` maps `RAZN_NFC_MASTER_KEY_HEX` → `$(RAZN_NFC_MASTER_KEY_HEX)`.
6. Clean build (`Product → Clean Build Folder`) after changing the key.

**DEBUG:** if the plist value is empty, the app falls back to the documented test-only key so local builds work. **Release** fails closed with “Master Key Missing” when unset.

Changing the production key requires re-provisioning every NTAG215 card.

## Provisioning (Add Auth)

Tester Mode → Tag Manager → **Add Auth**:

1. Scan the tag.
2. For NTAG213/215: derive PWD/PACK from UID + master key, then write PWD → PACK → CFG1 → CFG0 (AUTH0=`0x04`).
3. Verify with `PWD_AUTH`.
4. Overwrite of an already-protected tag tries: derived credentials → legacy shared password → optional manual current password.

Existing cards that still use `AADDCCBB` are **not** migrated until you run Add Auth again.

## Test Auth (preview only)

Tag Manager → **Test Auth** → **Scan Tag** (NTAG213 or NTAG215):

- Shows UID, master key, generated password (and PACK).
- Does **not** send `PWD_AUTH` and does **not** write.

## Production write

1. Identify NTAG213/215.
2. Reject unprotected tags (`Unprotected Tag`).
3. Read UID → derive → `PWD_AUTH` + PACK check.
4. Only then write NDEF pages. Never write config during ordinary write.

Wrong Tag message: *Authentication failed. This tag does not match the expected credentials. Writing is not allowed.*

## Test vector (test-only key — not production)

```
key = 0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF
uid = 04 DE AD BE EF 01 02
PWD = 6D4105A4
PACK = DF86
```

## Security limitations

- A key compiled into the app can be extracted; injection only keeps secrets out of git.
- NTAG215’s 4-byte password is not strong cryptographic authenticity and does not prevent cloning.
- UID-based derivation binds the password to the reported UID; it is not a remote attestation of a genuine NXP tag.

## Manual hardware checklist

1. Set `Secrets.xcconfig` master key; clean rebuild.
2. Test Auth on a blank NTAG213 or NTAG215 → note UID/PWD.
3. Add Auth on the same tag → success.
4. Production Write with a URL → success.
5. Unprotected tag → Unprotected Tag, no write.
6. Tag with wrong password / other key → Wrong Tag, no write.
7. Production Read (if used) still needs no password when PROT=0.
