# Othento iOS SDK

> Drop-in identity verification for iOS — document capture, selfie / face
> match, liveness, and OTP — launched from your app with a few lines of Swift.

The SDK takes over the foreground in a full-screen flow, drives the whole
verification, and hands you a typed decision (`Approved` / `Declined` /
`InReview`). The API surface mirrors the Othento web and Android SDKs 1:1, so
error codes, session statuses, and webhook payloads line up across platforms.

- **Swift Package:** `https://github.com/Othento/ios-sdk` · pin `0.3.0`
- **Min iOS:** 15.0 · **Xcode:** 15+ · **Swift:** 5.9+
- **UI:** renders with SwiftUI internally — your app can be **UIKit or SwiftUI**.
- **Distribution:** a prebuilt `XCFramework`. You add **one** package and
  `import Othento`; SPM resolves the two extra packages active liveness needs
  for you (see [Install](#install)).
- **Copy, branding and language are served by your backend** — see
  [Localisation & branding](#localisation--branding).

> **Versions earlier than 0.2.1 have been withdrawn** and can no longer be
> resolved. Pin **0.2.1 or later**.

---

## Contents

1. [Requirements](#requirements)
2. [How it works](#how-it-works)
3. [Permissions](#permissions)
4. [Install](#install)
5. [Active liveness](#active-liveness)
6. [Localisation & branding](#localisation--branding)
7. [Step 1 — Create a session on your server](#step-1--create-a-session-on-your-server)
8. [Step 2 — Start the SDK in your app](#step-2--start-the-sdk-in-your-app)
9. [Complete example](#complete-example)
10. [Configuration reference](#configuration-reference)
11. [Dedicated and on-premises deployments](#dedicated-and-on-premises-deployments)
12. [Presenting & dismissing](#presenting--dismissing)
13. [Lifecycle & callbacks](#lifecycle--callbacks)
14. [Result type](#result-type)
15. [Status & decision values](#status--decision-values)
16. [Error codes](#error-codes)
17. [Cancellation reasons](#cancellation-reasons)
18. [Testing your integration](#testing-your-integration)
19. [Troubleshooting](#troubleshooting)
20. [Versioning](#versioning)
21. [Support](#support)
22. [License](#license)

---

## Requirements

Before wiring the SDK in, make sure you have:

- A **partner account** on the Othento platform with at least one **workflow**
  configured. Workflow IDs are issued from your dashboard.
- Your application's **API key** from the dashboard. It stays on **your
  server** — never embed it in the app, where anyone can extract it from the
  binary. Sandbox and live keys decide the environment; see
  [Sandbox vs production](#sandbox-vs-production).
- A **server endpoint** of your own that creates a verification session and
  returns its session access token to the app. See
  [Step 1](#step-1--create-a-session-on-your-server).
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

## How it works

```
 Your app                   Your server                    Othento API
 ────────                   ───────────                    ───────────
 user taps "Verify" ────▶  POST /your/verify-session
                           (user is authenticated)
                                    │
                                    ├──▶ POST /api/v1/SessionToken/session
                                    │    X-API-KEY: <your API key>
                                    │◀── { externalId, sessionToken: "sat:…" }
                                    │
                           save externalId on the user
 receive { sat } ◀─────────  return { sat }

 OthentoConfig.Builder().tokenMode(sat: sat)
 result: .completed(decision, …) ◀── the SDK runs the verification

                           webhook: session.completed ◀── final result
```

1. **Your server** creates the session with your API key and gets back a
   **session access token** (SAT, prefixed `sat:`).
2. **Your app** passes only that SAT to the SDK.
3. The SDK runs the verification and reports the decision. Your server also
   receives it through webhooks, keyed by the `externalId` you saved in step 1.

Your API key never ships inside your app, and the session is bound to the user
your server authenticated — not to whatever identifier the device sends.

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
`https://github.com/Othento/ios-sdk`, and pin to **Exact Version `0.3.0`**.

Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Othento/ios-sdk", from: "0.3.0"),
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

You add one package. SPM then resolves two transitive packages
(`amplify-ui-swift-liveness` and `amplify-swift`), which the SDK needs for
[active liveness](#active-liveness). **The first resolve is slow**: they are
large repositories.

### CocoaPods

CocoaPods is **not available**. The previously documented pod has been
withdrawn. Integrate via Swift Package Manager (above).

---

## Active liveness

If your workflow's liveness method is **Active - Face + Light** or **Active -
Face Movement**, the SDK runs an **active** liveness challenge instead of the
passive video check.

**You do not configure anything.** There is no cloud account to connect and no
keys or identifiers to embed. The SDK renders its own branded intro (plus a
photosensitivity warning before the light challenge). The challenge itself is
run by a third-party cloud liveness service: the face video streams to it from
the device using short-lived credentials the Othento backend issues for each
attempt. The pass/fail decision stays server-side.

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
- **Export compliance.** The liveness module links an additional TLS library,
  used for transport encryption only. That is standard cryptography, so the
  usual Category 5 Part 2 exemption applies — set
  `ITSAppUsesNonExemptEncryption` deliberately rather than answering the
  TestFlight prompt each upload.
- **Nothing to add on your server.** The SDK fetches each attempt's
  credentials from the Othento SDK API itself.

**Behaviour**

- The user gets up to **3 attempts**. Closing the check (×) returns to the
  intro without consuming the step.
- The SDK brands the intro screens. The challenge screen's layout comes from
  the liveness service and can't be themed.

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

The session carries its language, so choose it **on your server** when you
create the session — pass `language` in the
[create-session request](#request-body):

```json
{ "workflowExternalId": "<WORKFLOW_ID>", "clientData": "user-123", "language": "ar" }
```

- **Optional.** Omit it and the tenant default is used.
- **The backend decides.** Request a language your tenant has no content for
  and it resolves to the tenant default. The SDK renders what came back, not
  what was asked for.
- **RTL is automatic.** When the resolved language is right-to-left (Arabic,
  for example) the whole flow mirrors — navigation, alignment and progress
  direction. You do nothing.

> Matching the SDK to your app's language: send
> `Locale.current.language.languageCode?.identifier` (iOS 16+) or
> `Locale.current.languageCode` to your server along with the request, and
> forward it as `language` — but only if your tenant has content for the
> languages your app supports, since anything else falls back to the default.

---

## Step 1 — Create a session on your server

Call this endpoint **from your backend only**, once per verification attempt.

```
POST https://sdk-api.othento.com/api/v1/SessionToken/session
X-API-KEY: <your API key>
Content-Type: application/json
```

### Request body

| Field | Type | Required | Notes |
|---|---|---|---|
| `workflowExternalId` | `String` | yes | The workflow to run, from your dashboard. |
| `clientData` | `String` | yes | Your identifier for the end user. Take it from **your authenticated session**, never from the app's request body. Echoed in webhooks. |
| `language` | `String` | optional | BCP-47 code (`"en"`, `"ar"`, …) the flow starts in. Omit for your tenant default. |
| `callbackUrl` | `String` | optional | Where the user is redirected on completion (if applicable). |
| `callbackReceiver` | `"Initiator"` / `"Completer"` / `"Both"` | optional | Which party receives the `callbackUrl` redirect. |
| `metadata` | `String` | optional | Free-form string round-tripped on session events and webhooks. |
| `expectedDetails` | object | optional | Identity hints compared against the document and selfie. See [Expected details](#expected-details). |

### Response

The response describes the new session. The fields you need:

| Field | Type | Use it for |
|---|---|---|
| `sessionToken` | `String` | The session access token (`sat:…`). **Return this to your app** as `sat`. |
| `externalId` | `String` | The session ID. **Save it on the user record** — webhooks reference it. |
| `expiresAt` | `String` | ISO-8601 time after which the session can no longer be started. |

### Example — Node.js (Express)

```ts
app.post('/api/verify-session', requireLogin, async (req, res) => {
  const response = await fetch('https://sdk-api.othento.com/api/v1/SessionToken/session', {
    method: 'POST',
    headers: {
      'X-API-KEY': process.env.OTHENTO_API_KEY!, // server-side secret
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      workflowExternalId: process.env.OTHENTO_WORKFLOW_ID,
      clientData: req.user.id, // from YOUR session, not from req.body
      language: req.user.language,
    }),
  });

  if (!response.ok) {
    return res.status(502).json({ error: 'verification_unavailable' });
  }

  const session = await response.json();
  await db.users.update(req.user.id, { othentoSessionId: session.externalId });

  res.json({ sat: session.sessionToken });
});
```

### Example — cURL

```bash
curl -X POST https://sdk-api.othento.com/api/v1/SessionToken/session \
  -H "X-API-KEY: <your API key>" \
  -H "Content-Type: application/json" \
  -d '{
    "workflowExternalId": "<WORKFLOW_ID>",
    "clientData": "user-123"
  }'
```

### Server-side errors

The endpoint uses the same API-key authentication as the Othento REST API, so
it answers with the same error statuses:

| Status | Meaning | What to do |
|---|---|---|
| `400` | A field is missing or invalid. | Check `workflowExternalId`, `clientData`, and field formats. |
| `401` | Missing or invalid API key. | Check the key and that it belongs to this application. |
| `402` | No active subscription on your account. | Check billing in your dashboard. |
| `403` | Application or organization suspended. | Contact your account manager. |
| `404` | `workflowExternalId` not found for this key. | Check the workflow ID and the environment of the key. |

Don't forward these to the end user as-is — show a generic "verification is
unavailable, try again" message and log the detail.

### Handling the session access token

- **Create a new session for every attempt.** Don't cache a SAT in the app for
  a later launch, and never share one between users.
- **Send it only to the user it was created for**, over HTTPS, as the response
  to that user's authenticated request.
- **Don't log it** or send it to analytics or crash reporting. Anyone holding
  the SAT can open that session until it expires.
- **If the SDK reports `session_expired`, `session_token_expired` or
  `session_not_found`**, call your endpoint again for a fresh SAT and start a new
  SDK instance.

### Expected details

All fields optional — send only what you already know. The backend cross-checks
them against the data extracted from the document / selfie, so **send each value
in the exact format below**. A `dateOfBirth` or `gender` in any other format
(e.g. `"01/01/1988"` or `"Male"`) is rejected: the create-session call fails with
`400`. Any other field in the wrong format (e.g. `"Jordan"` instead of `"JOR"`)
will not match.

```json
{
  "workflowExternalId": "<WORKFLOW_ID>",
  "clientData": "user-123",
  "expectedDetails": {
    "firstName": "Ahmad",
    "lastName": "Khalil",
    "dateOfBirth": "1988-01-01",
    "gender": "M",
    "nationality": "JOR",
    "country": "JOR",
    "address": "Amman, Jordan",
    "documentNumber": "A1234567",
    "ipAddress": "203.0.113.24"
  }
}
```

| Field | Type | What to send | Example |
|---|---|---|---|
| `firstName` | `String` | The person's first (given) name, as written on their identity document. | `"Ahmad"` |
| `lastName` | `String` | The person's last (family) name, as written on their identity document. | `"Khalil"` |
| `dateOfBirth` | `String` | Date of birth. **Must be `yyyy-MM-dd`**: 4-digit year, 2-digit month, 2-digit day, zero-padded, no time or timezone. | `"1988-01-01"` |
| `gender` | `String` | **`"M"` or `"F"`** only: one uppercase letter. Do not send `"Male"`, `"female"`, etc. | `"M"` |
| `nationality` | `String` | The person's nationality as an **ISO 3166-1 alpha-3** country code (3 uppercase letters). | `"JOR"` |
| `country` | `String` | Country as an **ISO 3166-1 alpha-3** country code (3 uppercase letters). Not a country name or a 2-letter code. | `"JOR"` |
| `address` | `String` | The person's address as free text. | `"Amman, Jordan"` |
| `documentNumber` | `String` | The identity document number (passport, national ID, …) exactly as printed, without spaces or dashes you added yourself. | `"A1234567"` |
| `ipAddress` | `String` | The **IPv4** address you expect the end user's device to connect from, in dotted-decimal form. Send the user's public IP, not your server's. | `"203.0.113.24"` |

Leave a field out rather than sending an empty string or a placeholder such as
`"N/A"`.

### Sandbox vs production

There is **no environment flag** in the SDK. The API key your server uses
decides: a sandbox key creates sandbox sessions, a live key creates billable
production sessions. The SAT carries that environment with it, so the app code
is identical in both. A sandbox session surfaces a sandbox indicator inside the
flow UI, and always finishes **Approved**; see
[Testing your integration](#testing-your-integration).

---

## Step 2 — Start the SDK in your app

Fetch a SAT from your server when the user taps "Verify", then start the flow
with it.

### SwiftUI — closure API

Flip a `Bool`; the SDK owns presentation and hands you one result:

```swift
import Othento
import SwiftUI

struct VerifyButton: View {
    // Built from a fresh SAT each time the user taps "Verify".
    @State private var config: OthentoConfig?
    @State private var showVerification = false

    var body: some View {
        let button = Button("Verify identity") {
            Task {
                let sat = try await MyBackend.createVerificationSession() // returns "sat:…"
                config = try OthentoConfig.Builder()
                    .tokenMode(sat: sat)
                    .build()
                showVerification = true
            }
        }

        if let config {
            button.othentoVerification(isPresented: $showVerification, config: config) { result in
                switch result {
                case let .completed(decision, externalId):
                    print("decision:", decision, "session:", externalId)
                case let .cancelled(reason):
                    print("cancelled:", reason)
                case let .failed(error, message):
                    print("failed:", error.code, "—", message)
                }
            }
        } else {
            button
        }
    }
}
```

### Listener API (SwiftUI or UIKit)

Implement `OthentoSDKListener` for the full lifecycle (ready / status changes),
and present via SwiftUI or UIKit:

```swift
let sat = try await MyBackend.createVerificationSession()

let config = try OthentoConfig.Builder()
    .tokenMode(sat: sat)
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
        // Same externalId your server saved in Step 1.
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

> **Treat the in-app result as a UI signal, not proof.** Update your records
> from the webhook your server receives (or by looking the session up
> server-side), not from a value reported by the device.

---

## Complete example

```swift
import Othento
import SwiftUI

struct ContentView: View {
    @State private var config: OthentoConfig?
    @State private var showVerification = false
    @State private var outcome = "—"

    var body: some View {
        let content = VStack(spacing: 16) {
            Text("Status: \(outcome)")
            Button("Verify identity") { Task { await startVerification() } }
                .buttonStyle(.borderedProminent)
        }

        if let config {
            content.othentoVerification(isPresented: $showVerification, config: config) { result in
                switch result {
                case let .completed(decision, externalId):
                    outcome = "completed \(decision.rawValue) (\(externalId))"
                case let .cancelled(reason):
                    outcome = "cancelled (\(reason.rawValue))"
                case let .failed(error, message):
                    outcome = "failed \(error.code): \(message)"
                }
            }
        } else {
            content
        }
    }

    private func startVerification() async {
        do {
            // Your endpoint from Step 1 — it creates the session with your API key.
            let sat = try await MyBackend.createVerificationSession()
            config = try OthentoConfig.Builder()
                .tokenMode(sat: sat)
                .build()
            showVerification = true
        } catch {
            outcome = "could not start: \(error.localizedDescription)"
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
| `tokenMode(sat:)` | ✅ | The `sessionToken` your server received in [Step 1](#step-1--create-a-session-on-your-server). |
| `apiBaseUrl(_:)` | optional (default `https://sdk-api.othento.com`) | Dedicated-cloud and on-premises deployments only. See [Dedicated and on-premises deployments](#dedicated-and-on-premises-deployments). |

```swift
let config = try OthentoConfig.Builder()
    .tokenMode(sat: "<session-access-token>")
    .build()
```

Everything about the session itself — workflow, user, language, callback URL,
metadata, expected details — is set **on your server** when you create it. See
[Request body](#request-body).

---

## Dedicated and on-premises deployments

If you use Othento's hosted service, skip this section: the SDK already points
at it.

With a dedicated-cloud or on-premises deployment, the SDK API runs on a host
your deployment provides. Pass that origin, as Othento gave it to you, to
`apiBaseUrl(_:)`:

```swift
let config = try OthentoConfig.Builder()
    .tokenMode(sat: sat)
    .apiBaseUrl("https://kyc-api.your-bank.example") // from your app's own configuration
    .build()
```

- **It is the SDK API host**, the same host your server creates sessions
  against in [Step 1](#step-1--create-a-session-on-your-server) (instead of
  `sdk-api.othento.com`).
- **An https origin only:** `https://`, a host name or IPv4 address, and an
  optional port, such as `https://kyc-api.your-bank.example:8443`. A path,
  query, fragment, credentials, an IPv6 literal, `http://`, or a blank string
  makes `build()` throw `OthentoConfigError` (`config_invalid`). Write
  international domain names in their `xn--` form.
- **It never falls back.** A blank or invalid value throws; the SDK does not
  quietly switch to Othento's hosted service. Once set, the SDK sends the
  session's access tokens only to that host.
- **Set it from your app's own build or configuration**, never from user input
  or a deep link.
- App Transport Security applies as usual: the host needs a certificate that
  iOS trusts. Don't add ATS exceptions for it.

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
| `onSessionCreated(externalId:sessionUrl:)` | The session loaded and has not finished yet. `externalId` is the one your server saved in Step 1. |
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
| `config_invalid` | Required field missing/malformed — for example an empty `sat` (thrown sync from `build()`). | Fix at build time. |
| `session_not_found` | The SAT didn't resolve to a session (HTTP 404). | Check the SAT was passed unmodified; request a new one from your server. |
| `session_expired` | The session is past its validity window. | Request a new SAT from your server. |
| `session_token_expired` | The SAT or the session token derived from it expired. | Request a new SAT from your server. |
| `session_failed` | The session ended in a non-recoverable failure. | Request a new SAT from your server. |
| `camera_permission_denied` | Camera access was denied. | Guide the user to Settings to enable it. |
| `network` | Connectivity / DNS / TLS failure. | Retry. |
| `documents_failed` | Document list/processing failed. | Prompt retry with better lighting. |
| `initiate_failed` | Flow failed to start. | Retry on a fresh instance. |
| `upload_failed` | Evidence upload failed; the associated `stage` in `.uploadFailed(stage:httpStatus:)` says which step: `.uploadUrl` (requesting the upload URL), `.s3Put` (uploading the file itself) or `.confirmUpload` (confirming the upload). | Retry; check connectivity. |
| `poll_failed` | Polling for the result failed. | Retry; the session may still resolve. |
| `file_too_large` | Picked file exceeded the upload limit (> 10 MB). | Prompt the user to retry capture. |
| `cancelled` | The operation was cancelled. | No action; surfaces via `onCancelled`. |
| `unknown` | Unclassified runtime error. | Show `displayMessage`; capture logs + `externalId` for support. |

```swift
func onError(_ error: OthentoError, displayMessage: String) {
    switch error {
    case .network:           showRetry()
    case .sessionNotFound:   restartWithNewSession()   // fetch a fresh SAT
    case .uploadFailed:      showRetry()               // error.stage available
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

1. Your server endpoint returns a `sat` beginning with `sat:` and stores the
   session's `externalId` on the user.
2. `onReady` shortly after `start()`.
3. `onSessionCreated` with the same `externalId`.
4. `onStatusChanged(.inProgress)` at least once.
5. Exactly one terminal callback (or one `OthentoResult`).
6. Your webhook endpoint receives the final session event for the same
   `externalId`.

Sandbox sessions always finish **Approved**, so use them to prove the
integration end to end. Declined and In-review outcomes can't be produced in
sandbox: cover that handling with your own tests (call your `onCompleted`
handling with `.declined` and `.inReview` directly) and confirm it once in
production.

- [ ] Server creates sessions with the **sandbox** API key; no API key anywhere in the app target
- [ ] `clientData` comes from the logged-in user on the server, not from the app's request body
- [ ] The flow launches and `onReady` fires
- [ ] A completed sandbox session → `onCompleted(.approved)`
- [ ] Your `.declined` and `.inReview` handling is covered by your own tests
- [ ] Swipe the sheet down mid-flow → `onCancelled(.swipeDismiss)`
- [ ] An expired SAT → `onError`, handled by fetching a new one

> The iOS Simulator camera is a static image and Vision/AVFoundation behave
> differently there — run capture and liveness on a **real device**.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| App terminates when the camera opens | Missing `NSCameraUsageDescription`. | Add it to your Info.plist (see [Permissions](#permissions)). |
| SPM error: checksum mismatch | Stale package cache or a re-uploaded asset. | File ▸ Packages ▸ Reset Package Caches, then re-resolve. |
| Your server gets `401` from `/SessionToken/session` | Missing or wrong `X-API-KEY`, or a key from a different application. | Check the key your server sends and the application it belongs to. |
| `build()` throws `config_invalid` | `sat` is empty — usually the server response was read with the wrong field name. Or, on a dedicated/on-premises deployment, `apiBaseUrl` is blank or not a bare https origin. | Return `session.sessionToken` from your server and pass it as `sat`. Check `apiBaseUrl` against [the rules](#dedicated-and-on-premises-deployments). |
| `onError(session_not_found)` right after launch | The SAT was altered (trimmed, re-encoded) or belongs to a different environment. | Pass the token exactly as received; make sure the server used the intended key. |
| `onError(session_expired)` / `session_token_expired` | The SAT was created too long before the user started. | Create the session when the user taps "Verify", not at app launch. |
| Camera screen never appears | Camera permission permanently denied. | The SDK shows an "Open Settings" path; the user must grant it. |
| No result is ever delivered | The listener (or SDK) was deallocated mid-flow. | Hold a strong reference to both, or use the closure API. |

---

## Versioning

[SemVer](https://semver.org/). While on `0.x` the public API may change between
minor versions; the first frozen API ships as `1.0.0`. **Pin an exact version in
production.**

---

## Support

Include the SDK version (`0.3.0`), the `externalId` of the affected session, and
a console capture when contacting your account manager or opening a ticket.

---

## License

MIT — see [LICENSE](./LICENSE).
