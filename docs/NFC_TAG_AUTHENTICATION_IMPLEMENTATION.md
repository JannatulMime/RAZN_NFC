# How NFC Tag Authentication Is Implemented

This document describes how **RAZN NFC** implements NFC tag authentication on iOS: architecture, credential derivation, provisioning, production write gating, key files, and failure modes.

Related protocol detail: [`NTAG215_UID_PASSWORD_DERIVATION.md`](./NTAG215_UID_PASSWORD_DERIVATION.md).

---

## Summary

Tag authentication is **fully offline**. There is no server challenge-response and no tag-auth REST API.

Production writes authenticate against **NTAG213 / NTAG215** using NXP **PWD_AUTH (`0x1B`)**. Credentials are derived locally from a build-injected master key and the tag’s 7-byte UID:

```
PWD  = HMAC-SHA256(key, UTF8("RAZN-NTAG215-PWD-v1")  || UID)[0..3]
PACK = HMAC-SHA256(key, UTF8("RAZN-NTAG215-PACK-v1") || UID)[0..1]
```

Only after a successful PWD_AUTH + PACK match does the app write NDEF user memory.

---

## Architecture

Two NFC paths share the same low-level MiFare helpers and derivation logic:

| Path | Purpose | Session | Auth |
|------|---------|---------|------|
| **Production write** | Home screen Write (URL → NDEF) | `NFCTagReaderSession` (ISO14443) | Must be NTAG213/215, protected (AUTH0 covers user pages), then HMAC → PWD_AUTH |
| **Production read** | Menu / legacy scan | `NFCNDEFReaderSession` | No password; plain NDEF read |
| **Tag Manager (tester)** | Provision / check / remove protection | `NFCTagReaderSession` via `AuthNFCManager` | NTAG213/215: HMAC; NTAG216: legacy shared hex `AADDCCBB` |

```
Production write
  NFCToolsView → NFCViewModel.writeNFC()
    → NFCReader.performProductionWrite
      → AuthNFCProductionWriteGate.writeProtectedNDEF
          → identify → protection check → derive → PWD_AUTH
          → Type 2 NDEF TLV page WRITE

Tester / provisioning
  Tester Mode → TagManagerView → AuthNFCManager
    Check Auth / Add Auth / Remove Auth
      → AuthNFCTagService (GET_VERSION, READ, WRITE, 0x1B)
      → AuthNFCCredentialDerivation (NTAG213/215)
```

Crypto / key loading:

- `AuthNFCMasterKeyProvider` — reads `RAZN_NFC_MASTER_KEY_HEX` from Info.plist (xcconfig-injected)
- `AuthNFCCredentialDerivation` — CryptoKit `HMAC<SHA256>`
- `AuthNFCTagService.authenticate` — sends PWD_AUTH and compares PACK

---

## Credential derivation (NTAG213 / NTAG215)

### Inputs

| Input | Rule |
|-------|------|
| **UID** | Exactly **7 raw bytes** from tag memory: page 0 `[0..2]` + page 1 `[0..3]` (UID0…UID6). Skip BCC0. Do **not** hash colon/hex display strings. |
| **Master key** | ≥ 32 raw bytes from `RAZN_NFC_MASTER_KEY_HEX` |

Domain separator strings keep the historical `"NTAG215"` name for both NTAG213 and NTAG215 so already-provisioned cards stay valid.

### Implementation

`AuthNFCCredentialDerivation.deriveCredentials(uid:masterKey:)`:

1. Validate UID length (7 bytes).
2. Require master key ≥ 32 bytes.
3. `HMAC-SHA256(key, domain || uid)` for PWD and PACK domains.
4. Truncate digests to 4-byte PWD and 2-byte PACK.

### Test vector (test-only key — not production)

```
key  = 0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF
uid  = 04 DE AD BE EF 01 02
PWD  = 6D4105A4
PACK = DF86
```

Covered by `RAZN NFCTests/AuthNFCCredentialDerivationTests.swift`.

### Legacy NTAG216 (Tag Manager only)

- Shared password hex: `AADDCCBB` (`AuthNFCConstants.tagManagerPasswordHex`)
- `PACK = SHA256(passwordBytes)[0..<2]`

Production write **rejects** NTAG216.

---

## Wire commands (MiFare Type 2)

| Command | Opcode | Payload / response |
|---------|--------|--------------------|
| GET_VERSION | `0x60` | → 8-byte version (identify 213/215/216) |
| READ | `0x30` | page → 16 bytes |
| WRITE | `0xA2` | page + 4 bytes |
| PWD_AUTH | `0x1B` | 4-byte PWD → 2-byte PACK |

Implemented in `AuthNFCTagService`.

### Config pages (AUTH0 / ACCESS)

- **AUTH0** at CFG0\[3\]: first page that requires auth; `0xFF` = protection off
- **ACCESS**: PROT (`0x80`), CFGLCK (`0x40`), AUTHLIM
- Production provisioning: **AUTH0 = `0x04`**, PROT = 0 (write-only protection)

---

## Production write flow (scan → success / failure)

Entry: user pastes/selects a URL → **Write** → `NFCViewModel.writeNFC()` → `NFCReader` opens `NFCTagReaderSession`.

Then `AuthNFCProductionWriteGate.writeProtectedNDEF`:

1. **Connect** as MiFare (ISO14443).
2. **GET_VERSION** — must be NTAG213 or NTAG215; otherwise “Unsupported Tag”.
3. Size the NDEF TLV and compute destination page span from user page `0x04`.
4. **READ CFG0/CFG1** — require destination fully protected (`AUTH0` ≤ start page; AUTH0 ≠ `0xFF`). Else **“Unprotected Tag”** and **no write**.
5. **READ UID** (pages 0–1) → derive PWD/PACK from master key.
6. **PWD_AUTH (`0x1B`)** + PACK compare. Fail → **“Wrong Tag”**, **no write**.
7. Ensure Capability Container (page 3) if needed.
8. **WRITE** Type 2 NDEF TLV pages (`03` + length + records + `FE`, page-padded) starting at `0x04`.

Ordinary production write never changes PWD/PACK/CFG. Config is only written during Tag Manager **Add Auth** / **Remove Auth**.

Success → toast + analytics (`successful_nfc_write`). User cancel → silent (no alert).

---

## Tag Manager: provisioning and checks

Unlock **Tester Mode** (home screen secret gesture) → floating Tag Manager → `TagManagerView`.

### Add Auth (provision)

1. Scan tag; identify via GET_VERSION.
2. Reject if CFGLCK is set.
3. Credentials:
   - **213/215**: UID + master key HMAC
   - **216**: legacy shared password
4. If already protected and overwrite not confirmed → confirmation required.
5. Overwrite auth order: derived → legacy shared → optional current password.
6. Write order: **PWD → PACK → CFG1 (write-only, CFGLCK=0) → CFG0 (AUTH0=`0x04`)**.
7. Re-read config; verify AUTH0 / PROT / CFGLCK; **PWD_AUTH** to confirm PACK.

### Check Auth

Read CFG; if protected, PWD_AUTH with expected credentials → match or reject.

### Remove Auth

Authenticate (derived, then legacy) → set AUTH0=`0xFF` (content kept).

### Test Auth

Derive and display UID / PWD / PACK only — **no** PWD_AUTH and **no** write.

---

## Master key configuration

| Item | Location |
|------|----------|
| Template | `Config/Secrets.xcconfig.example` |
| Local secret (gitignored) | `Config/Secrets.xcconfig` |
| App xcconfig include | `Config/RAZN-NFC.xcconfig` |
| Info.plist mapping | `RAZN-NFC-Info.plist` → `$(RAZN_NFC_MASTER_KEY_HEX)` |
| Runtime reader | `AuthNFCMasterKeyProvider` |

Setup:

1. Copy `Secrets.xcconfig.example` → `Secrets.xcconfig`.
2. Set a **64-character hex** (32-byte) value for `RAZN_NFC_MASTER_KEY_HEX`.
3. Clean build after changing the key.

**DEBUG:** empty key falls back to the documented test-only key.  
**Release:** empty key → “Master Key Missing” (fail closed).

Changing the production key requires re-provisioning every protected card.

---

## Key files

### Production auth / write

| File | Role |
|------|------|
| `RAZN NFC/Views/Test NFC/NFCReader.swift` | Production NFC sessions; routes write through the write gate |
| `RAZN NFC/AuthNFCProduction/AuthNFCProductionWriteGate.swift` | Auth gate + Type 2 NDEF page writer + user alerts |
| `RAZN NFC/AuthNFCProduction/AuthNFCCredentialDerivation.swift` | Offline HMAC PWD/PACK derivation |
| `RAZN NFC/AuthNFCProduction/AuthNFCMasterKeyProvider.swift` | Master key from plist / DEBUG fallback |
| `RAZN NFC/AuthNFCProduction/AuthNFCProductionUnregister.swift` | Disable AUTH0; unregister controller |
| `RAZN NFC/AuthNFCProduction/AuthNFCPasswordStore.swift` | UserDefaults legacy hex password (unregister / migration; not used by current HMAC production write) |
| `RAZN NFC/Views/HomeScreen/NFCViewModel.swift` | UI view model; write alerts |
| `RAZN NFC/Views/HomeScreen/NFCToolsView.swift` | Write UI + tester gate + Tag Manager entry |

### Tag I/O / tester / models

| File | Role |
|------|------|
| `RAZN NFC/TestNFCAuth/AuthNFCTagService.swift` | MiFare GET_VERSION / READ / WRITE / PWD_AUTH / UID |
| `RAZN NFC/TestNFCAuth/AuthNFCManager.swift` | Tester session owner + Check/Add/Remove |
| `RAZN NFC/TestNFCAuth/AuthNFCPasswordService.swift` | Hex↔bytes; legacy SHA256 PACK; CFG builders |
| `RAZN NFC/TestNFCAuth/AuthNFCTagProfile.swift` | NTAG213/215/216 page maps |
| `RAZN NFC/TestNFCAuth/AuthNFCModels.swift` | Config snapshot, protection rules, results |
| `RAZN NFC/TestNFCAuth/AuthNFCConstants.swift` | Command bytes; legacy password |
| `RAZN NFC/TestNFCAuth/AuthNFCError.swift` | Typed errors + user-facing copy |
| `RAZN NFC/TestNFCAuth/TagManagerView.swift` | Tester UI |

### Platform / tests

| File | Role |
|------|------|
| `RAZN NFC/RAZN NFC.entitlements` | `nfc.readersession.formats` = `TAG` |
| `RAZN-NFC-Info.plist` | Master key placeholder + NFC usage wiring |
| `RAZN NFCTests/AuthNFCCredentialDerivationTests.swift` | HMAC vectors |
| `RAZN NFCTests/AuthNFCProductionWriteGateTests.swift` | Gate policy with scripted tag |

---

## Auth success criteria

1. Tag accepts PWD_AUTH (no NAK / I/O error).
2. Returned PACK equals the expected 2-byte PACK.

Mismatch → `packMismatch` / `authenticationRejected` → production **“Wrong Tag”**.

This is NTAG password authentication only — not public-key signing, ECDSA, or remote attestation.

---

## Production write alerts

| Condition | Alert | Behavior |
|-----------|-------|----------|
| AUTH0 does not cover destination | Unprotected Tag | No write |
| PWD_AUTH fail / PACK mismatch | Wrong Tag | No write |
| Not 213/215 / bad GET_VERSION | Unsupported Tag | No write |
| CFG unreadable | Configuration Unreadable | No write |
| Missing / invalid master key | Master Key Missing / Invalid | No write |
| Bad UID | Invalid Tag UID | No write |
| NFC I/O / tag removed | NFC Communication Failed | No write |
| User cancel | (none) | Silent |

Alerts map through `AuthNFCError` → `AuthNFCProductionWriteAlert`. Passwords and master keys are never shown in alert text.

---

## What is *not* part of tag auth

- No HTTP/URLSession calls for tag authentication
- Firebase Analytics / Firestore force-update are unrelated to PWD_AUTH
- Production **read** does not password-authenticate; it reads NDEF only

---

## Security limitations

- A master key compiled into the app binary can be extracted; xcconfig injection only keeps secrets out of git.
- NTAG’s 4-byte password is not strong cryptographic authenticity and does not prevent cloning.
- UID-based derivation binds the password to the reported UID; it is not proof of a genuine NXP silicon tag.

---

## Quick reference — class map

- **UI:** `NFCToolsView`, `NFCViewModel`, `TagManagerView`, `AuthNFCTestAuthView`
- **Sessions:** `NFCReader`, `AuthNFCManager`, `AuthNFCUnregisterController`
- **Gate / crypto:** `AuthNFCProductionWriteGate`, `AuthNFCCredentialDerivation`, `AuthNFCMasterKeyProvider`
- **RF:** `AuthNFCTagService`
- **Policy:** `AuthNFCProtection`, `AuthNFCConfigSnapshot`, `AuthNFCTagProfile`
- **Errors / alerts:** `AuthNFCError`, `AuthNFCProductionWriteAlert`, `AuthNFCStatusMessage`
