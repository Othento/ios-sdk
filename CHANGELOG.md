# Changelog

All notable changes to the Othento iOS SDK are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-11-06

### Fixed

- **`import Othento` failed to compile in Swift Package Manager projects**, with
  `no such module 'AWSPluginsCore'` or `missing required modules: 'AwsCAuth', …`
  (reproduced on 0.2.1 with Xcode 15.4). The framework's public interface
  imported two internal dependencies; it no longer does. No code changes are
  needed on your side.

### Added

- **`OthentoConfig.Builder.apiBaseUrl(_:)` for dedicated-cloud and
  on-premises deployments.** Points the SDK at your deployment's SDK API
  instead of `https://sdk-api.othento.com`. It must be an https origin (host
  and optional port, no path); a blank or invalid value makes `build()` throw
  `OthentoConfigError` (`config_invalid`) rather than falling back to the
  hosted service. Omit it and nothing changes. See "Dedicated and on-premises
  deployments" in the README.

### Removed

- The undocumented `OTHENTO_INTERNAL_BASE_URL` environment variable. Use
  `apiBaseUrl(_:)` instead.

### Documentation

- Sandbox sessions always finish Approved; the README no longer promises test
  documents for the Declined and In-review outcomes.
- A `dateOfBirth` or `gender` in the wrong format is rejected with `400` when the
  session is created; the README previously said they would not match.

## [0.2.1] - 2026-09-14

### Changed

- **Production backend.** The SDK now connects to `https://sdk-api.othento.com`.
  If your app or network restricts outbound hosts, allow this domain. No code
  changes are required; sandbox vs. live is still decided by your API key.

### Documentation

- **Token mode is now the documented integration** (README update,
  2026-09-16). The README explains how to create a session on your server with
  `POST /api/v1/SessionToken/session` and start the SDK with
  `OthentoConfig.Builder().tokenMode(sat:)`, so your API key never ships inside
  your app. Create mode is no longer documented; it keeps working for existing
  integrations. No SDK code changes.

- **`OthentoExpectedDetails` field formats.** The README now documents what to
  send for every field — `dateOfBirth` as `yyyy-MM-dd`, `gender` as `"M"` /
  `"F"`, `nationality` and `country` as ISO 3166-1 alpha-3 codes, and
  `ipAddress` as the expected end-user IPv4 address. The same guidance appears
  in Xcode Quick Help. Values in any other format will not match the extracted
  data.

### Removed

- **Versions 0.1.0, 0.1.1 and 0.2.0 have been withdrawn.** Those builds
  connected to a development backend and must not be used. Their GitHub
  releases and tags were deleted, so they can no longer be resolved. Upgrade to
  0.2.1 or later.

## [0.2.0] - 2026-08-25 [YANKED]

### Added

- **Backend-driven content, branding and localisation.** Every string, colour,
  font and image in the verification UI now comes from your tenant
  configuration instead of being compiled into the SDK. The SDK fetches it once
  at launch from `GET /api/v1/SdkContent` and renders what comes back.

  Practical consequences:
  - **Your backend must serve this endpoint.** It is not optional — the SDK
    blocks its first paint on the response, and a session whose content cannot
    be loaded ends on an error screen rather than falling back to built-in
    English copy. If you run the standard Othento backend this is already in
    place; if you self-host, upgrade the backend *before* shipping this SDK
    version.
  - **The tenant theme now wins over host-app branding.** Colours, fonts and
    logos resolve from the tenant configuration returned with the content.
  - **A brief loading screen precedes the first verification screen** while
    that fetch is in flight. The close button is available throughout.

- **Right-to-left layout.** Arabic and other RTL languages lay out correctly —
  mirrored navigation, alignment and progress direction — driven by the
  language the content resolves to.

- **`language(_:)` on `OthentoConfig.Builder`.** A BCP-47 code (`"en"`, `"ar"`)
  selecting the verification UI language.

  ```swift
  let config = try OthentoConfig.Builder()
      .create(workflowExternalId: "wf_…", clientData: "user-123")
      .apiKey("pk_sandbox_…")
      .language("ar")
      .build()
  ```

  Additive and optional — omit it and you get the tenant default, which is
  exactly what every existing integration already gets. **Create mode only:**
  in token mode the session already carries its own language and the field is
  ignored. The backend has the final say; ask for a language the tenant has no
  content for and it resolves to the tenant default.

- **Active liveness**, as an opt-in alternative to the existing passive
  liveness-video check. A workflow whose liveness method is **Active - Face +
  Light** or **Active - Face Movement** now runs an active liveness challenge.
  The SDK renders its own branded intro (and a photosensitivity warning before
  the light challenge); the challenge itself is run by a third-party cloud
  liveness service. Credentials are short-lived and issued per attempt by the
  Othento backend — the SDK embeds no cloud identifier beyond the region. Up to
  3 attempts; the backend still owns the pass/fail decision.

- **"Update Required" screen.** A session that asks for a verification step
  this build cannot render now shows an explicit dead-end instead of silently
  routing the user into the wrong capture screen.

- **Searchable country and document pickers.** The country and document-type
  lists are now type-to-filter, matching on country name and dialling code.
  Previously they were a plain scroll — unusable at ~200 entries.

- **`rekognitionLiveness` fixture scenario**, for exercising the active-liveness
  intro and photosensitivity screens without a backend. The challenge itself
  still needs a real one.

### Changed

- **SPM integrators now resolve two transitive packages.** `Othento` depends on
  `aws-amplify/amplify-ui-swift-liveness` (pinned exactly `1.4.0`) and
  `aws-amplify/amplify-swift` (pinned exactly `2.49.0`). You still add a single
  package in Xcode; SPM resolves the rest. The first resolve is slow — it is a
  large dependency graph.

  These pins are deliberately **not** the newest. Liveness `1.4.5` /
  amplify-swift `2.58.5` use `@preconcurrency` on a protocol conformance, which
  is Swift 6 syntax and requires Xcode 16 (and so macOS 14.5+). The pinned pair
  builds on Swift 5.10 and exposes an identical error set, keeping the SDK
  consumable on Xcode 15.4.

- **The wait for a verification decision is now 16 seconds, up from 10.** A
  timeout here is not neutral: it routes the session to the terminal
  "Verification under review" result, so a session seconds away from a real
  verdict was landing in a manual-review queue instead. The extra time comes
  from polling more often over the same cadence, so verdicts that arrive
  quickly are not delayed.

- Unknown challenge types are now decoded to an explicit sentinel. Previously
  they fell back to `DocumentFront`, which dropped the user into ID capture.

### Fixed

- **OTP no longer strands the user when a late verdict lands mid-send.** If the
  ID step's asynchronous processing returned a retryable failure while an OTP
  code was being sent, the session moved past the OTP step but the UI stayed on
  it, leaving a dead screen with no way forward. Such a session is now routed
  through the normal resolver.

### Known limitations

- **CocoaPods does not carry active liveness.**
  `amplify-ui-swift-liveness` publishes no podspec, so the CocoaPods artifact
  is built without it. An active-liveness workflow reaching a CocoaPods
  integrator lands on the "Update Required" screen. Passive liveness, document
  capture and OTP are unaffected. **Use SPM if your workflows use active
  liveness.**

  The CocoaPods spec therefore stays at **0.1.1** for this release. There is no
  `0.2.0` pod.

- **The artifact is substantially larger for SPM integrators.** Active
  liveness statically links its cloud client stack: the device slice binary goes from
  **4.5 MiB to 25.2 MiB** (+20.7 MiB), and the release zip from 5.9 MiB to
  26.3 MiB. That is the unstripped framework, not your app's growth — the
  linker dead-strips and the App Store thins per-device — but measure it with
  an App Store size report if binary size is a constraint.

## [0.1.1] - 2026-06-18 [YANKED]

### Fixed

- **Binary consumers can now `import Othento`.** PhoneNumberKit is no longer
  exposed in the framework's public Swift interface. Under
  `BUILD_LIBRARY_FOR_DISTRIBUTION` the leaked import made the XCFramework
  unbuildable for SPM and CocoaPods consumers, failing with
  `no such module 'PhoneNumberKit'`. PhoneNumberKit stays statically linked and
  fully internal, so consumers still declare no transitive dependencies.
- **OTP entry no longer overflows on narrow screens.** Code cells now size to
  the available width, so longer codes (8–10 digits) fit without clipping or
  horizontal overflow; shorter codes still render at the full design size.
- **Camera and torch are suspended during upload.** When a captured document or
  selfie is uploading, the live camera session and torch are now paused instead
  of continuing to run behind the upload overlay, and rebind cleanly if the flow
  returns to the capture screen.

### Build

- The XCFramework release build now fails if any third-party module leaks into a
  public `.swiftinterface`, preventing a recurrence of the binary-distribution
  break above.

## [0.1.0] - 2026-06-14 [YANKED]

### Added

- Initial public release of the Othento identity-verification SDK for iOS.
- Distributed as a self-contained binary `Othento.xcframework` via Swift Package
  Manager and CocoaPods; statically links and embeds PhoneNumberKit so
  consumers declare no transitive dependencies — `import Othento` is all that is
  required.
- Minimum deployment target: iOS 15.

[0.3.0]: https://github.com/Othento/ios-sdk/releases/tag/0.3.0
[0.2.1]: https://github.com/Othento/ios-sdk/releases/tag/0.2.1
