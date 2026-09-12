# RAZN_NFC — Upwork Portfolio Raw Material

## 1. Project Basics

- App name: **Razn** (display name via `INFOPLIST_KEY_CFBundleDisplayName`); Xcode product / target **RAZN NFC**; README title `RAZN_NFC`
- Bundle ID: `com.razvanVladutChiricia.RAZNNFC`
- Platform: Native iOS (Swift + SwiftUI; UIKit bridged where needed — e.g. share sheet, keyboard lock, haptics)
- Marketing version: **4.0**; build / current project version: **24** (app target)
- Minimum OS: iOS **16.4** (app target `IPHONEOS_DEPLOYMENT_TARGET`); project-level setting also shows 18.2 in shared project configs
- Swift version: **5.0** (`SWIFT_VERSION` in Xcode project)
- App category/niche: Consumer NFC utility for writing (and reading) NDEF link/URL payloads to NFC tags; branded companion UI around RAZN / razn.it (Explore opens `https://razn.it/`; App Store link id `6749680572` in `Constants`)
- License in repo: MIT (copyright 2025 JannatulMime)

## 2. Tech Stack

- Language(s): Swift 5; UI primarily SwiftUI; CoreNFC / StoreKit / UIKit for platform APIs
- Architecture pattern: **MVVM-style** — views + `*VM` / `NFCViewModel` / `NFCWriteInfoVM` as `ObservableObject` with `@Published`; shared write state via `@EnvironmentObject`; navigation via `NavigationStack` + path enum (`Screens`)
- Dependency management: Swift Package Manager (no Podfile / CocoaPods detected)
- Key SPM dependencies (from `Package.resolved` / project frameworks):
  - **firebase-ios-sdk** (≥ 12.13.0) — products linked: `FirebaseCore`, `FirebaseAnalytics`, `FirebaseAnalyticsCore`
  - Transitive Google packages pulled by Firebase (App Check, GoogleAppMeasurement, GoogleUtilities, etc.) — present in lockfile; app code only imports `FirebaseCore` / `FirebaseAnalytics`
- Backend/API integrations detected:
  - Firebase Analytics event logging (no Auth / Firestore / Functions usage found in app Swift sources)
  - Outbound URLs: App Store, razn.it, Instagram profile link
- Third-party / Apple SDKs:
  - **CoreNFC** — NDEF read/write (`NFCNDEFReaderSession`)
  - **StoreKit** — `SKStoreReviewController` in-app review prompts
  - **UIKit** — `UIActivityViewController` share sheet, pasteboard, haptics, keyboard safe-area control
  - NFC entitlement: `com.apple.developer.nfc.readersession.formats` = `TAG`
  - Custom fonts: Croogla4F, Inter Regular / Bold (registered in Info plist)

## 3. Key Features Implemented

- NFC **write** of URL (preferred) or text NDEF records via `NFCReader` / `CoreNFC`
- NFC **read** path implemented in the same `NFCReader` (URI / text well-known records); used from Menu flow scan helper
- URL normalization (prepend `https://` when scheme missing) before write and for share validation
- Primary home flow (`NFCToolsView`): paste link, clear, write button, toast feedback, NFC unavailable alert
- Quick-save category grid (8 types: Social, Message, Business, Review, Custom, Pay, Website, Link) — tap to autofill if saved; long-press to edit/save in sheet; persistence in `UserDefaults` (`nfc_link_<type>`)
- In-place **share** of normalized link via system share sheet when input validates as http(s) URL
- Clipboard paste into main input
- App Store review prompting gated by NFC write count + day cadence (`AppStoreReviewManager`)
- Firebase Analytics events: `app_opened`, `successful_nfc_write`, `selected_quick_button_category`, `review_popup_shown`
- Haptic (and optional sound) feedback utility (`InteractionFeedback`)
- Custom UI: branded background assets, logo/tag imagery, toast, edit-link sheet, icon buttons with press/long-press scaling
- Keyboard layout lock so hosting controller does not shift UI when keyboard appears (`keyboardLayoutLocked`)
- Explore / discover CTA opening razn.it; Instagram deep-link helper on view model (toolbar Instagram button currently commented out in UI)
- Legacy / secondary screens still in nav graph: Menu (add field / write list), Add Field, Add URL field; Splash screen view exists but app entry currently mounts `RootView` directly
- Accessibility hints on category icon buttons

Notable implementations:

- Custom long-press vs tap press-state logic on `NFCIconButton` (different feedback when slot has vs lacks a saved link)
- Share sheet driven by `.sheet(item:)` + identifiable items to avoid empty first-presentation race (documented in code)
- Delayed sheet dismiss after save to avoid tap-through to underlying controls
- Review prompt delayed ~5s after eligibility before calling StoreKit

## 4. Code Quality Signals

- Testing present:
  - Unit tests: `RAZN NFCTests/AppStoreReviewManagerTests.swift` (~9 test methods covering write threshold, cadence, launch trigger, already-reviewed gate)
  - No UI / XCUITest target or widget-style tests discovered in current tree
  - Coverage % not configured/discoverable in repo
- CI/CD:
  - **Not present on current working tree**
  - Remote branch `origin/CI/githubAction` contains GitHub Actions workflows (e.g. `RAZN_build_ipa.yml`) for signed `xcodebuild` archive/IPA on `macos-latest` (push/PR/`workflow_dispatch`)
  - No fastlane / Bitrise configs found in current checkout
- Code organization:
  - Feature-ish folders under `Views/` (HomeScreen, Menu, AddFieled, SplashScreen, Test NFC), plus `Analytics/`, `Review/`, `Utility/`, `Helpers/`, `DI/`
  - Clear VM separation for main NFC tools flow; some older Menu/AddField VMs remain thin navigation flags
  - Mix of primary single-screen NFC tools UI and older multi-screen write/menu flow still in codebase
- Performance-related code:
  - `LazyVGrid` for icon grid
  - Toast auto-dismiss via cancellable `Task`
  - No image-caching library, pagination, or offline sync layer detected

## 5. Notable Technical Problems Solved

Flag as **"Possible technical highlight — verify with client/notes"**:

- Possible technical highlight — verify with client/notes: Preventing SwiftUI keyboard from pushing/reflowing layout (`KeyboardLayoutLock` + `ignoresSafeArea(.keyboard)`); commits reference keyboard/button fixes
- Possible technical highlight — verify with client/notes: Share-sheet first-tap empty presentation race fixed by identifiable `.sheet(item:)` pattern (inline comment in `NFCToolsView`)
- Possible technical highlight — verify with client/notes: Writing well-known URI NDEF payloads specifically for iPhone tap-to-open behavior (comment in `NFCReader.makeURIPayload`)
- Possible technical highlight — verify with client/notes: Icon button tap vs long-press gesture coordination and scaling/sensitivity fixes (multiple git commits: button interaction, sensitivity, scaling, “no link long press”)
- Possible technical highlight — verify with client/notes: App Store review prompt timing (NFC-write multiples + multi-day cadence + launch re-prompt; unit-tested)
- Possible technical highlight — verify with client/notes: Sheet dismiss delay after save to prevent accidental underlying control activation
- Possible technical highlight — verify with client/notes: Firebase Analytics integration for product events (commits: add firebase analytics / stores in firebase)
- Possible technical highlight — verify with client/notes: Font PostScript name mismatch for Inter Bold documented and corrected in `Constants.Fonts`

## 6. Gaps / Info I Cannot Determine From Code

Please fill these in manually for Upwork copy:

- Your role on the project (sole developer vs team; which modules you owned)
- Client / industry context beyond what’s implied by RAZN branding
- Business outcomes, conversion, retention, or revenue impact
- App Store rating, review count, download/MAU metrics
- Official launch date and version history storytelling beyond marketing version 4.0 / build 24
- Whether `summary_RaznNFC.md` marketing claims (e.g. ReTag hardware ecosystem positioning) are approved public facts to reuse
- Whether CI on `CI/githubAction` was productionized or abandoned (not on current branch)
- Design system / Figma ownership; how much UI was your original design vs client assets
- NDA or portfolio disclosure restrictions
- Device matrix / TestFlight process / crash rate (Crashlytics not evidenced in linked packages)
- Whether Menu / Splash / AddField flows are still shipped UX or unused legacy paths

---

*Generated from repository inspection only. Do not treat as marketing copy.*
