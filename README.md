# Othento iOS SDK

> Drop-in identity verification for iOS — document capture, selfie / face
> match, liveness, and OTP — launched from your app with a few lines of Swift.

The SDK takes over the foreground in a full-screen flow, drives the whole
verification, and hands you a typed decision (`Approved` / `Declined` /
`InReview`). The API surface mirrors the Othento web and Android SDKs 1:1, so
error codes, session statuses, and webhook payloads line up across platforms.

- **Swift Package:** `https://github.com/Othento/ios-sdk` · pin `0.1.0`
- **Min iOS:** 15.0 · **Xcode:** 15+ · **Swift:** 5.9+
- **UI:** renders with SwiftUI internally — your app can be **UIKit or SwiftUI**.
- **Distribution:** a prebuilt, self-contained `XCFramework`. **No transitive
  dependencies** — `import Othento` is all you need.

---

## Contents

1. [Requirements](#requirements)
2. [Permissions](#permissions)
3. [Install](#install)
4. [Quick start](#quick-start)
5. [Complete example](#complete-example)
6. [Configuration reference](#configuration-reference)
7. [Presenting & dismissing](#presenting--dismissing)
8. [Lifecycle & callbacks](#lifecycle--callbacks)
9. [Result type](#result-type)
10. [Status & decision values](#status--decision-values)
11. [Error codes](#error-codes)
12. [Cancellation reasons](#cancellation-reasons)
13. [Testing your integration](#testing-your-integration)
14. [Troubleshooting](#troubleshooting)
15. [Versioning](#versioning)
16. [Support](#support)
17. [License](#license)

---

## Requirements

Before wiring the SDK in, make sure you have:

- A **partner account** on the Othento platform with at least one **workflow**
  configured. Workflow IDs are issued from your dashboard.
- A **public API key** (`pk_sandbox_…` or `pk_live_…`). Sandbox keys hit the
  test environment; live keys bill against your plan. **There is no environment
  flag** — the key decides. See [Sandbox vs production](#sandbox-vs-production).

| Setting | Value |
|---|---|
| Deployment target | iOS 15.0+ |
| Xcode | 15+ |
| Swift | 5.9+ |
| Architectures | `arm64` (device), `arm64` + `x86_64` (simulator) |

If you don't have credentials yet, contact your account manager to be onboarded.

---

## Permissions

Add the camera usage description to your app's **Info.plist** — without it, iOS
terminates the app when the SDK opens the camera:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan your identity document and selfie.</string>
```

Notes:
- **No photo-library key is required** — the optional "upload from library"
  fallback uses the system image picker, which runs out-of-process.
- The SDK requests camera access **at the moment of first capture** and shows an
  in-flow rationale with an **"Open Settings"** path if it was permanently denied.
- A `PrivacyInfo.xcprivacy` manifest is bundled **inside** the XCFramework
  (required-reason APIs + no tracking), so your App Store submission's privacy
  report is satisfied for the SDK's own usage.

---

## Install

### Swift Package Manager (recommended)

In Xcode: **File ▸ Add Package Dependencies…**, enter
`https://github.com/Othento/ios-sdk`, and pin to **Exact Version `0.1.0`**.

Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Othento/ios-sdk", from: "0.1.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [.product(name: "Othento", package: "ios-sdk")]
    )
]
```

SPM downloads the prebuilt XCFramework from the GitHub Release and verifies it
against the manifest's SHA-256 checksum at resolution time.

### CocoaPods

```ruby
pod 'Othento', '~> 0.1.0'
```

---

## Quick start

### SwiftUI — closure API (the one-liner)

Flip a `Bool`; the SDK owns presentation and hands you one result:

```swift
import Othento
import SwiftUI

struct VerifyButton: View {
    @State private var showVerification = false

    private let config = try! OthentoConfig.Builder()
        .create(workflowExternalId: "<WORKFLOW_ID>", clientData: "user-123")
        .apiKey("<pk_sandbox_… or pk_live_…>")
        .build()

    var body: some View {
        Button("Verify identity") { showVerification = true }
            .othentoVerification(isPresented: $showVerification, config: config) { result in
                switch result {
                case let .completed(decision, externalId):
                    print("decision:", decision, "session:", externalId)
                case let .cancelled(reason):
                    print("cancelled:", reason)
                case let .failed(error, message):
                    print("failed:", error.code, "—", message)
                }
            }
    }
}
```

### Listener API (SwiftUI or UIKit)

Implement `OthentoSDKListener` for the full lifecycle (ready / session-created /
status changes), and present via SwiftUI or UIKit:

```swift
let config = try OthentoConfig.Builder()
    .create(workflowExternalId: "<WORKFLOW_ID>", clientData: "user-123")
    .apiKey("<pk_sandbox_… or pk_live_…>")
    .build()

let sdk = OthentoSDK(config: config, listener: self)   // self: OthentoSDKListener

// UIKit:
present(sdk.viewController(), animated: true)

// SwiftUI:
//   .fullScreenCover(isPresented: $show) { OthentoFlowView(sdk: sdk) }
```

```swift
extension MyVerificationCoordinator: OthentoSDKListener {
    func onReady() {}
    func onSessionCreated(externalId: String, sessionUrl: String) {
        // Persist externalId against your user record for webhook correlation.
    }
    func onStatusChanged(_ status: OthentoSessionStatus) {}
    func onCompleted(decision: OthentoDecision, externalId: String) {
        // decision = .approved | .declined | .inReview
    }
    func onCancelled(reason: OthentoCancelReason) {}
    func onError(_ error: OthentoError, displayMessage: String) {
        // error.code is a stable identifier; displayMessage is user-facing.
    }
}
```

> `OthentoSDKListener` is `@MainActor` and is held **weakly** by `OthentoSDK` —
> keep a strong reference to your listener (and to the `OthentoSDK` instance) for
> the duration of the flow. The closure API handles this for you.

### Sandbox vs production

There is **no environment flag**. The API-key prefix decides: `pk_sandbox_…`
hits the test environment, `pk_live_…` bills real verifications — same SDK build.
A sandbox key surfaces a sandbox indicator inside the flow UI.

---

## Complete example

```swift
import Othento
import SwiftUI

struct ContentView: View {
    @State private var showVerification = false
    @State private var outcome = "—"

    private var config: OthentoConfig {
        // Configuration is validated synchronously; handle the throw in real code.
        try! OthentoConfig.Builder()
            .create(workflowExternalId: "<WORKFLOW_ID>", clientData: "user-123")
            .apiKey("<pk_sandbox_…>")
            .expectedDetails(OthentoExpectedDetails(dateOfBirth: "1990-04-23"))
            .build()
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Status: \(outcome)")
            Button("Verify identity") { showVerification = true }
                .buttonStyle(.borderedProminent)
        }
        .othentoVerification(isPresented: $showVerification, config: config) { result in
            switch result {
            case let .completed(decision, externalId):
                outcome = "completed \(decision.rawValue) (\(externalId))"
            case let .cancelled(reason):
                outcome = "cancelled (\(reason.rawValue))"
            case let .failed(error, message):
                outcome = "failed \(error.code): \(message)"
            }
        }
    }
}
```

---

## Configuration reference

Build an `OthentoConfig` with the fluent `Builder`. Configuration is validated
**synchronously** — missing or malformed fields throw `OthentoConfigError` from
`build()`; they never arrive via `onError`.

| Method | Required | Purpose |
|---|---|---|
| `create(workflowExternalId:clientData:)` | ✅ (create mode) | The workflow id + your end-user identifier. |
| `apiKey(_:)` | ✅ (create mode) | Public API key (`pk_sandbox_…` / `pk_live_…`). |
| `tokenMode(sat:)` | ✅ (token mode) | A backend-minted session access token; use *instead of* `create`/`apiKey`. |
| `callbackUrl(_:)` | optional | Redirect URL forwarded to the create-session call. |
| `callbackReceiver(_:)` | optional | Which webhook the platform invokes: `.initiator` / `.completer` / `.both`. |
| `metadata(_:)` | optional | Free-form string round-tripped on session events / webhooks. |
| `expectedDetails(_:)` | optional | Identity hints cross-checked against extracted data (see below). |

```swift
// Token mode — when your backend creates the session and mints a token:
let config = try OthentoConfig.Builder()
    .tokenMode(sat: "<session-access-token>")
    .build()
```

### `OthentoExpectedDetails`

All fields optional — send only what you already know. The backend cross-checks
them against the data extracted from the document / selfie.

```swift
OthentoExpectedDetails(
    firstName: nil,
    lastName: nil,
    dateOfBirth: nil,   // ISO-8601, e.g. "1990-04-23"
    gender: nil,
    nationality: nil,
    country: nil,
    address: nil,
    documentNumber: nil,
    ipAddress: nil
)
```

---

## Presenting & dismissing

You have three entry points; all drive the same flow:

| Entry point | Use when |
|---|---|
| `.othentoVerification(isPresented:config:onResult:)` | SwiftUI, common case. The SDK owns full-screen presentation; you flip a `Bool` and get one `OthentoResult`. |
| `OthentoFlowView(sdk:)` / `OthentoFlowView(config:listener:)` | SwiftUI, when you want to place / present the flow yourself and use the listener. |
| `OthentoSDK(config:listener:)` + `viewController()` | UIKit. `present(sdk.viewController(), animated: true)`. |

**Dismissing early:**

- **Closure API** — set the binding back to `false`, or let it auto-dismiss when
  a terminal result fires.
- **Imperative** — call `sdk.destroy()`. It fires `onCancelled(reason: .hostDestroy)`
  if invoked before a terminal event, and is a safe no-op afterwards.

Exactly one of `onCompleted` / `onCancelled` / `onError` (or one `OthentoResult`)
fires per session, and only one SDK instance should run at a time.

---

## Lifecycle & callbacks

```
start() → onReady → onSessionCreated
                         ↓
                onStatusChanged (deduped, n×)
                         ↓
       exactly one terminal callback:
       onCompleted | onCancelled | onError
```

All callbacks are dispatched on the **main actor**.

| Callback | When it fires |
|---|---|
| `onReady()` | SDK is up. Fires once, before any other event. |
| `onSessionCreated(externalId:sessionUrl:)` | A new session was minted. Save `externalId` against your user record. |
| `onStatusChanged(_:)` | Session status transitioned. Deduplicated — never the same status twice in a row. |
| `onCompleted(decision:externalId:)` | Terminal decision reached: `.approved`, `.declined`, or `.inReview`. |
| `onCancelled(reason:)` | User dismissed, host called `destroy()`, or the SDK cancelled before a terminal status. |
| `onError(_:displayMessage:)` | Non-decision terminal error. `error.code` is stable; `displayMessage` is user-facing. |

The closure API collapses the three terminal callbacks into a single
[`OthentoResult`](#result-type); the non-terminal events are available only via
the listener.

---

## Result type

The closure API delivers one value:

```swift
enum OthentoResult {
    case completed(decision: OthentoDecision, externalId: String)
    case cancelled(reason: OthentoCancelReason)
    case failed(error: OthentoError, displayMessage: String)
}
```

---

## Status & decision values

```swift
enum OthentoSessionStatus { case created, inProgress, processing, completed, expired, failed }
enum OthentoDecision { case approved, declined, inReview }
```

The raw values (`"Created"`, `"Approved"`, …) are identical to the web and
Android SDKs', so the same analytics and webhook payloads work across platforms.

---

## Error codes

`OthentoError` is an enum; `error.code` is the stable wire string. Switch on the
case (or `code`) for exhaustive handling.

| `code` | Meaning | Recommended action |
|---|---|---|
| `config_invalid` | Required field missing/malformed (thrown sync from `build()`). | Fix at build time. |
| `missing_api_key` | No `apiKey`. | Provide the public API key. |
| `missing_workflow` | No `workflowExternalId`. | Provide the workflow ID. |
| `missing_client_data` | No `clientData`. | Pass your end-user identifier. |
| `session_not_found` | Session id didn't resolve (HTTP 404). | Start a fresh session. |
| `session_expired` | The session is past its validity window. | Start a fresh session. |
| `session_token_expired` | A token-mode SAT/ST expired. | Mint a new token from your backend. |
| `session_failed` | The session ended in a non-recoverable failure. | Start a fresh session. |
| `camera_permission_denied` | Camera access was denied. | Guide the user to Settings to enable it. |
| `network` | Connectivity / DNS / TLS failure. | Retry. |
| `create_failed` | Session could not be created. | Verify `apiKey` + `workflowExternalId`. |
| `documents_failed` | Document list/processing failed. | Prompt retry with better lighting. |
| `initiate_failed` | Flow failed to start after session creation. | Retry on a fresh instance. |
| `upload_failed` | Evidence upload failed; `error.stage` says which step (`UploadUrl` / `S3Put` / `ConfirmUpload`). | Retry; check connectivity. |
| `poll_failed` | Polling for the result failed. | Retry; the session may still resolve. |
| `file_too_large` | Picked file exceeded the upload limit (> 10 MB). | Prompt the user to retry capture. |
| `cancelled` | The operation was cancelled. | No action; surfaces via `onCancelled`. |
| `unknown` | Unclassified runtime error. | Show `displayMessage`; capture logs + `externalId` for support. |

```swift
func onError(_ error: OthentoError, displayMessage: String) {
    switch error {
    case .network:           showRetry()
    case .sessionNotFound:   restartSession()
    case .uploadFailed:      showRetry()          // error.stage available
    default:                 showGeneric(displayMessage)
    }
}
```

---

## Cancellation reasons

`onCancelled(reason:)` fires once with a typed `OthentoCancelReason`:

| `reason` | Trigger |
|---|---|
| `.hostDestroy` | Host called `sdk.destroy()` before a terminal event. |
| `.sdkInternal` | The SDK's own UI cancelled the session. |
| `.swipeDismiss` | Sheet pull-down dismissal. |

---

## Testing your integration

A healthy integration produces, in order:

1. `onReady` shortly after `start()`.
2. `onSessionCreated` with a non-empty `externalId`.
3. `onStatusChanged(.inProgress)` at least once.
4. Exactly one terminal callback (or one `OthentoResult`).

Use the sandbox test documents from your dashboard to exercise approved /
declined / in-review paths deterministically.

- [ ] Sandbox key in place; the flow launches and `onReady` fires
- [ ] Approved-path document → `onCompleted(.approved)`
- [ ] Declined-path document → `onCompleted(.declined)`
- [ ] In-review document → `onCompleted(.inReview)`
- [ ] Swipe the sheet down mid-flow → `onCancelled(.swipeDismiss)`

> The iOS Simulator camera is a static image and Vision/AVFoundation behave
> differently there — run capture and liveness on a **real device**.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| App terminates when the camera opens | Missing `NSCameraUsageDescription`. | Add it to your Info.plist (see [Permissions](#permissions)). |
| SPM error: checksum mismatch | Stale package cache or a re-uploaded asset. | File ▸ Packages ▸ Reset Package Caches, then re-resolve. |
| `onError(create_failed)` immediately | Wrong/expired `apiKey` or `workflowExternalId`. | Verify credentials and that the key matches the environment. |
| Camera screen never appears | Camera permission permanently denied. | The SDK shows an "Open Settings" path; the user must grant it. |
| No result is ever delivered | The listener (or SDK) was deallocated mid-flow. | Hold a strong reference to both, or use the closure API. |

---

## Versioning

[SemVer](https://semver.org/). While on `0.x` the public API may change between
minor versions; the first frozen API ships as `1.0.0`. **Pin an exact version in
production.**

---

## Support

Include the SDK version (`0.1.0`), the `externalId` of the affected session, and
a console capture when contacting your account manager or opening a ticket.

---

## License

MIT — see [LICENSE](./LICENSE).
