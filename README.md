# Othento iOS SDK

> Drop-in identity verification for iOS — document capture, selfie / face
> match, liveness, and OTP — launched from your app with a few lines of Swift.

The SDK takes over the foreground in a full-screen flow, drives the whole
verification, and hands you a typed decision (`Approved` / `Declined` /
`InReview`). The API surface mirrors the Othento web and Android SDKs 1:1, so
error codes, session statuses, and webhook payloads line up across platforms.

- **Swift Package:** `https://github.com/Othento/ios-sdk` · pin `0.2.1`
- **Min iOS:** 15.0 · **Xcode:** 15+ · **Swift:** 5.9+
- **UI:** renders with SwiftUI internally — your app can be **UIKit or SwiftUI**.
- **Distribution:** a prebuilt `XCFramework`. You add **one** package and
  `import Othento`; SPM resolves the two AWS packages behind Face Liveness for
  you (see [Install](#install)).
- **Copy, branding and language are served by your backend** — see
  [Localisation & branding](#localisation--branding).

> **Versions earlier than 0.2.1 have been withdrawn** and can no longer be
> resolved. Pin **0.2.1 or later**.

---

## Contents

1. [Requirements](#requirements)
2. [Permissions](#permissions)
3. [Install](#install)
4. [AWS Rekognition Face Liveness](#aws-rekognition-face-liveness)
5. [Localisation & branding](#localisation--branding)
6. [Quick start](#quick-start)
7. [Complete example](#complete-example)
8. [Configuration reference](#configuration-reference)
9. [Presenting & dismissing](#presenting--dismissing)
10. [Lifecycle & callbacks](#lifecycle--callbacks)
11. [Result type](#result-type)
12. [Status & decision values](#status--decision-values)
13. [Error codes](#error-codes)
14. [Cancellation reasons](#cancellation-reasons)
15. [Testing your integration](#testing-your-integration)
16. [Troubleshooting](#troubleshooting)
17. [Versioning](#versioning)
18. [Support](#support)
19. [License](#license)

---

## Requirements

Before wiring the SDK in, make sure you have:

- A **partner account** on the Othento platform with at least one **workflow**
  configured. Workflow IDs are issued from your dashboard.
- A **public API key** (`pk_sandbox_…` or `pk_live_…`). Sandbox keys hit the
  test environment; live keys bill against your plan. **There is no environment
  flag** — the key decides. See [Sandbox vs production](#sandbox-vs-production).
- A backend serving **`GET /api/v1/SdkContent`**. From 0.2.0 the SDK renders no
  built-in copy — all text, colours, fonts and imagery arrive from this
  endpoint, and the flow will not start without it. The standard Othento
  backend already provides it; if you self-host, **upgrade the backend before
  shipping this SDK version**. See
  [Localisation & branding](#localisation--branding).

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
- **No microphone key is required** — capture is video-only, without audio.
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
`https://github.com/Othento/ios-sdk`, and pin to **Exact Version `0.2.1`**.

Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Othento/ios-sdk", from: "0.2.1"),
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

You add one package. SPM then resolves two transitive AWS packages
(`amplify-ui-swift-liveness` and `amplify-swift`), which the SDK needs for
Rekognition Face Liveness — see below. **The first resolve is slow**; Amplify is
a large repository.

### CocoaPods

CocoaPods is **not available**. The previously documented pod has been
withdrawn. Integrate via Swift Package Manager (above).

---

## AWS Rekognition Face Liveness

If your workflow's `face_liveness_method` is `rekognition_light` or
`rekognition_movement`, the SDK runs an **active** liveness challenge using
AWS's Face Liveness component instead of the passive video check.

**You do not configure anything.** There is no AWS account to connect, no
Cognito Identity Pool, no keys or identifiers to embed. The SDK renders its own
branded intro (plus a photosensitivity warning before the light challenge), and
the challenge streams to AWS using short-lived credentials your backend vends
per attempt. The pass/fail decision stays server-side.

**Requirements**

- **Swift Package Manager** — the only supported install method.
- `NSCameraUsageDescription` in your `Info.plist` — the same key the document
  and selfie capture screens already require. No new permission, but **update
  the wording**: the camera is now also used for a liveness check, and App
  Review checks purpose strings against actual behaviour. Something like:
  *"Used to photograph your identity document and to record a short liveness
  check confirming it's really you."*
- **Privacy declarations.** The SDK ships its own `PrivacyInfo.xcprivacy`
  declaring what it transmits (biometric/face data as *Sensitive Info*, photos
  and videos, and OTP email/phone when those steps are enabled). Apple
  aggregates that with your app's manifest, but **App Store privacy labels are
  set per-app** — your submission must declare the same categories, and must
  match whatever your backend retains.
- **Export compliance.** The liveness path links s2n-tls / aws-lc for TLS
  transport only. Standard cryptography, so the usual Category 5 Part 2
  exemption applies — set `ITSAppUsesNonExemptEncryption` deliberately rather
  than answering the TestFlight prompt each upload.
- Your backend must expose
  `GET /api/v1/SessionToken/session/liveness/rekognition/credentials`. If you
  run the standard Othento backend this is already in place.

**Behaviour**

- The user gets up to **3 attempts**. Closing the check (×) returns to the
  intro without consuming the step.
- The AWS challenge screen's layout is fixed by AWS. The SDK brands the intro;
  the challenge itself is not themeable beyond what AWS exposes.

---

## Localisation & branding

From **0.2.0** the verification UI carries no built-in copy or theme. On
launch the SDK calls `GET /api/v1/SdkContent` once and renders what your tenant
configuration returns: every string, colour, font and image.

**What this means for you**

- **Nothing to configure in the app.** Text and theme are managed from your
  dashboard, and changes take effect without shipping a new build.
- **A short loading screen precedes the first verification screen** while that
  request is in flight. The close button is live throughout, so the user is
  never trapped.
- **The tenant theme wins.** Colours, fonts and logos resolve from the tenant
  configuration; there is no host-app override.
- **This endpoint is required.** If it cannot be reached, or returns nothing
  usable, the flow ends on an error screen — the SDK does not fall back to
  built-in English. Upgrade your backend before shipping 0.2.0.

### Choosing a language

Pass a BCP-47 code to the builder:

```swift
let config = try OthentoConfig.Builder()
    .create(workflowExternalId: "wf_…", clientData: "user-123")
    .apiKey("pk_sandbox_…")
    .language("ar")          // optional
    .build()
```

- **Optional.** Omit it and the tenant default is used — the behaviour every
  integration had before 0.2.0.
- **Create mode only.** In token mode the session already carries its own
  language, minted by your backend, and this value is ignored.
- **The backend decides.** Request a language your tenant has no content for
  and it resolves to the tenant default. The SDK renders what came back, not
  what was asked for.
- **RTL is automatic.** When the resolved language is right-to-left (Arabic,
  for example) the whole flow mirrors — navigation, alignment and progress
  direction. You do nothing.

> Matching the SDK to your app's language: pass
> `Locale.current.language.languageCode?.identifier` (iOS 16+) or
> `Locale.current.languageCode` — but only if your tenant has content for the
> languages your app supports, since anything else falls back to the default.

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
| `language(_:)` | optional | BCP-47 UI language, e.g. `"en"` / `"ar"`. **Create mode only** — ignored in token mode. Omit for the tenant default. See [Localisation & branding](#localisation--branding). |

```swift
// Token mode — when your backend creates the session and mints a token:
let config = try OthentoConfig.Builder()
    .tokenMode(sat: "<session-access-token>")
    .build()
```

### `OthentoExpectedDetails`

All fields optional — send only what you already know. The backend cross-checks
them against the data extracted from the document / selfie, so **send each value
in the exact format below**: a correct value in the wrong format (e.g. a date as
`"01/01/1988"`, or `"Jordan"` instead of `"JOR"`) will not match.

```swift
OthentoExpectedDetails(
    firstName: "Ahmad",
    lastName: "Khalil",
    dateOfBirth: "1988-01-01",   // must be yyyy-MM-dd
    gender: "M",                 // "M" or "F"
    nationality: "JOR",          // ISO 3166-1 alpha-3
    country: "JOR",              // ISO 3166-1 alpha-3
    address: "Amman, Jordan",
    documentNumber: "A1234567",
    ipAddress: "203.0.113.24"    // expected end-user IPv4
)
```

| Field | Type | What to send | Example |
|---|---|---|---|
| `firstName` | `String?` | The person's first (given) name, as written on their identity document. | `"Ahmad"` |
| `lastName` | `String?` | The person's last (family) name, as written on their identity document. | `"Khalil"` |
| `dateOfBirth` | `String?` | Date of birth. **Must be `yyyy-MM-dd`**: 4-digit year, 2-digit month, 2-digit day, zero-padded, no time or timezone. | `"1988-01-01"` |
| `gender` | `String?` | **`"M"` or `"F"`** only: one uppercase letter. Do not send `"Male"`, `"female"`, etc. | `"M"` |
| `nationality` | `String?` | The person's nationality as an **ISO 3166-1 alpha-3** country code (3 uppercase letters). | `"JOR"` |
| `country` | `String?` | Country as an **ISO 3166-1 alpha-3** country code (3 uppercase letters). Not a country name or a 2-letter code. | `"JOR"` |
| `address` | `String?` | The person's address as free text. | `"Amman, Jordan"` |
| `documentNumber` | `String?` | The identity document number (passport, national ID, …) exactly as printed, without spaces or dashes you added yourself. | `"A1234567"` |
| `ipAddress` | `String?` | The **IPv4** address you expect the end user's device to connect from, in dotted-decimal form. Send the user's public IP, not your server's. | `"203.0.113.24"` |

Leave a field `nil` rather than sending an empty string or a placeholder such as
`"N/A"`.

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

Include the SDK version (`0.2.1`), the `externalId` of the affected session, and
a console capture when contacting your account manager or opening a ticket.

---

## License

MIT — see [LICENSE](./LICENSE).
