# RAZN Force Update — Firestore Setup

Firebase project: `razn-3d9e4`  
Document path: `app_config/razn_ios`

This app has **no Firebase Auth**. Clients need unauthenticated **read** access to this single document. Client **writes** must be denied. Change configuration only from the Firebase Console (or another trusted admin workflow).

There is no Firebase CLI / `firebase.json` in this repository. Use the Console steps below.

---

## 1. Enable Firestore (if needed)

1. Open [Firebase Console](https://console.firebase.google.com/) → project **razn-3d9e4**.
2. Go to **Build → Firestore Database**.
3. If Firestore is not enabled, create a database in **Native mode** (production or test mode is fine initially; publish the rules in step 3 before shipping).
4. If the API is disabled, also enable **Cloud Firestore API** for the project:  
   https://console.developers.google.com/apis/api/firestore.googleapis.com/overview?project=razn-3d9e4

---

## 2. Create the configuration document

1. In Firestore, create collection `app_config` if it does not exist.
2. Create document ID `razn_ios` with these fields:

| Field | Type | Initial value |
|-------|------|----------------|
| `minimumSupportedVersion` | string | `5.0` |
| `forceUpdateEnabled` | boolean | `false` |
| `updateMessage` | string | `A new version of RAZN is required. Please update to continue.` |
| `appStoreURL` | string | `https://apps.apple.com/app/id6749680572` |

JSON equivalent:

```json
{
  "minimumSupportedVersion": "5.0",
  "forceUpdateEnabled": false,
  "updateMessage": "A new version of RAZN is required. Please update to continue.",
  "appStoreURL": "https://apps.apple.com/app/id6749680572"
}
```

Initial values match the current App Store marketing version with force update **off**, so shipping the client does not lock existing users.

---

## 3. Security rules

### If this project has no other Firestore data yet

In **Firestore → Rules**, publish:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /app_config/razn_ios {
      allow read: if true;
      allow write: if false;
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### If broader rules already exist

Do **not** replace unrelated rules. Merge only this match (place it before any catch-all deny if needed):

```
match /app_config/razn_ios {
  allow read: if true;
  allow write: if false;
}
```

Never put service-account credentials or privileged secrets in the iOS app.

---

## 4. How force update works

| Condition | Result |
|-----------|--------|
| `forceUpdateEnabled == false` | App is allowed (no forced update). |
| `forceUpdateEnabled == true` and installed version **&lt;** `minimumSupportedVersion` | Force-update screen; App Store only. |
| `forceUpdateEnabled == true` and installed version **≥** `minimumSupportedVersion` | App is allowed. |

Version comparison is numeric / component-wise (`1.10.0` &gt; `1.2.0`; `5.0` equals `5.0.0`).

The iOS client reads with Firestore **server** source so a stale offline cache cannot bypass a mandatory update.

---

## 5. Operating the feature

### Force an update for a future release

1. Ship the new build to the App Store.
2. Set `minimumSupportedVersion` to that new version (or the oldest you still support).
3. Set `forceUpdateEnabled` to `true`.
4. Optionally update `updateMessage`.

### Disable force update

Set `forceUpdateEnabled` to `false` in the Console. Users can use the app again without changing `minimumSupportedVersion`.

---

## 6. App Store URL

Default listing: [https://apps.apple.com/app/id6749680572](https://apps.apple.com/app/id6749680572)

The app prefers a valid remote `appStoreURL`. If the field is missing or invalid, it falls back to `Constants.getAppLink()` in the iOS project.
