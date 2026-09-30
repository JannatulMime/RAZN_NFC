# Developer / Tester Mode — Findings & Re-implementation Guide

## Summary

The feature you implemented was called **"Tester Mode"** (not "dev mode") internally. It was
activated by **tapping the RAZN logo at the top of the home screen 5 times within 10 seconds**,
and deactivated by tapping the **"TESTER" badge** (which appears next to the logo when enabled)
5 times within 10 seconds.

**Important:** This code does **not** exist in any branch or commit (checked all 97 commits
across `main`, `newDesign`, `version_4.0_req`, `version_4.0_v2`, and all remotes). It only
survives as **dangling git blobs** — the changes were staged but never committed, and were
later discarded (likely by one of the `git reset` operations visible in the reflog, e.g.
2026-05-12 / 2026-05-19 / 2026-08-13). The one stash (`stash@{0}` "tool") is unrelated
(keyboard/layout work).

## Where the recovered code lives (dangling blobs)

Recover any file with: `git cat-file -p <blob-hash>`

| Blob hash | File | Purpose |
|---|---|---|
| `3d25b99ea701f2665123d9d8167ee9b04423295e` | `TesterModeManager.swift` (new file) | Core manager: persists flag in UserDefaults (`razn.testerMode.isEnabled`), sets Firebase Analytics user property `user_type = "tester"` |
| `52c8e3b0c6033f14429a971ce841812e126e66d7` | `NFCToolsView.swift` (full modified version) | Multi-tap detection on the RAZN logo, tester toast, `TesterModeBadge` view, enable/disable logic |
| `5e58f0ffb2b29c027efa9e46971c9ad5ec503d9b` | `RAZN_NFCApp.swift` (modified) | Calls `TesterModeManager.shared.restoreOnLaunch()` after `FirebaseApp.configure()` |
| `57435d2390ef6a463a1b307b3d005079240d5834` | `FirebaseAnalyticsManager.swift` (modified) | Prefixes all analytics event names with `tester_` when tester mode is on |
| `f8d32ab08f7d65727fdca8395bc9fb4068fe155d` | `TesterModeManagerTests.swift` (new file) | Unit tests for the manager |
| `1740e59b9230c41f54b02919d4c89f22279bb0af` | `FirebaseAnalyticsManagerTests.swift` (new file) | Unit tests for `tester_` event name resolution |

> Note: dangling blobs can eventually be garbage-collected. To be safe, extract them now:
> ```bash
> git cat-file -p 3d25b99ea701f2665123d9d8167ee9b04423295e > TesterModeManager.swift.recovered
> ```

## How the feature worked

1. **Activation** — tap the `razn_logo` image in the header of `NFCToolsView` **5 times within
   10 seconds** (`multiTapThreshold = 5`, `multiTapWindow = 10.0`). A "Tester Mode Enabled"
   toast shows for 2 seconds.
2. **Indicator** — a glowing "TESTER" capsule badge (`TesterModeBadge`) animates in next to
   the RAZN logo while enabled (spring animation, pulsing blue glow).
3. **Deactivation** — tap the TESTER badge 5 times within 10 seconds. "Tester Mode Disabled" toast.
4. **Persistence** — flag stored in `UserDefaults` key `razn.testerMode.isEnabled`; restored on
   every launch via `restoreOnLaunch()`.
5. **Effect on analytics** — while enabled:
   - Firebase user property `user_type` is set to `"tester"` (cleared when disabled), so
     internal-tester traffic can be segmented/filtered in Firebase.
   - All analytics events get a `tester_` prefix (e.g. `app_opened` → `tester_app_opened`,
     `successful_nfc_write` → `tester_successful_nfc_write`,
     `selected_quick_button_category` → `tester_selected_quick_button_category`,
     `review_popup_shown` → `tester_review_popup_shown`).

## How to re-implement on the current branch (`version_4.0_v2`)

The current `NFCToolsView.swift` header (lines ~109–148) is almost identical to the recovered
version except the logo has no tap gesture and the badge/state are missing. Steps:

### 1. Add `TesterModeManager.swift` (new file, e.g. in `RAZN NFC/Utility/` or `RAZN NFC/`)

Full recovered content — see blob `3d25b99e` (reproduced above in this repo's git objects).
Requires `import FirebaseAnalytics`.

### 2. `NFCToolsView.swift` changes (current file: `RAZN NFC/Views/HomeScreen/NFCToolsView.swift`)

- Add state properties (from blob `52c8e3b0`):
  ```swift
  @State private var logoTapCount = 0
  @State private var lastLogoTapTime: Date?
  @State private var testerBadgeTapCount = 0
  @State private var lastTesterBadgeTapTime: Date?
  @State private var testerToastMessage: String?
  @State private var testerToastTask: Task<Void, Never>?
  @State private var isTesterModeEnabled = TesterModeManager.shared.isEnabled

  private let multiTapThreshold = 5
  private let multiTapWindow: TimeInterval = 10.0
  ```
- Replace the plain `Image("razn_logo")` in `header` with a tappable version + conditional badge:
  ```swift
  HStack(spacing: 8) {
      Image("razn_logo")
          .resizable()
          .scaledToFit()
          .frame(height: 20)
          .opacity(0.7)
          .contentShape(Rectangle())
          .onTapGesture { handleLogoTap() }

      if isTesterModeEnabled {
          TesterModeBadge(onTap: handleTesterBadgeTap)
              .transition(.scale(scale: 0.85).combined(with: .opacity))
      }
  }
  ```
- Add the functions `handleLogoTap()`, `handleTesterBadgeTap()`, `registerMultiTap(count:lastTapTime:)`,
  `setTesterModeEnabled(_:)`, `showTesterToast(_:)` (all in blob `52c8e3b0`, lines ~119–175).
- Change the toast overlay to `if let message = vm.toastMessage ?? testerToastMessage { ToastView(...) }`.
- Add `isTesterModeEnabled = TesterModeManager.shared.isEnabled` inside `.onAppear`.
- Add the `TesterModeBadge` private struct (bottom of blob `52c8e3b0`) — glowing capsule using
  `Color.brandBlue`, `Constants.Fonts.interBold`.

### 3. `RAZN_NFCApp.swift` change

Add `TesterModeManager.shared.restoreOnLaunch()` right after `FirebaseApp.configure()` in `init()`.

### 4. `FirebaseAnalyticsManager.swift` changes

- Add `static let testerEventPrefix = "tester_"` and `private let testerMode: TesterModeManager`
  with `init(testerMode: TesterModeManager = .shared)`.
- Add `resolvedEventName(for:)` and route `track(_:)` through it (see blob `57435d23`).

### 5. (Optional) Tests

Add `TesterModeManagerTests.swift` (blob `f8d32ab0`) and `FirebaseAnalyticsManagerTests.swift`
(blob `1740e59b0`) — both use isolated `UserDefaults` suites. Note: no test target exists in
the project currently, so this requires adding one first.

## How to use it once implemented

- **Enable**: tap the RAZN logo (top of home screen) 5× within 10 s → badge appears, toast confirms.
- **Disable**: tap the TESTER badge 5× within 10 s.
- The setting persists across launches; all Firebase events from the device are prefixed with
  `tester_` and the `user_type = tester` user property is set, letting you filter out internal
  traffic in Analytics.
