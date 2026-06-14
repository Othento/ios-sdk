# Othento iOS SDK

Identity verification for iOS. Swift + SwiftUI. Distributed as a prebuilt XCFramework.

## Requirements
- iOS 15.0+
- Xcode 15+

## Install (Swift Package Manager)
In Xcode: File ▸ Add Package Dependencies ▸ `https://github.com/Othento/ios-sdk`, pin to `0.1.0`. Or in `Package.swift`:
```swift
.package(url: "https://github.com/Othento/ios-sdk", from: "0.1.0")
```

## Install (CocoaPods)
```ruby
pod 'Othento', '~> 0.1.0'
```

## Permissions
Add to your app's Info.plist:
- `NSCameraUsageDescription` — required (document + selfie capture).

(No microphone key is required — capture is video-only without audio.)

## Quick start — SwiftUI (closure API)
```swift
import Othento
import SwiftUI

struct VerifyButton: View {
    @State private var show = false
    let config = try! OthentoConfig.Builder()
        .create(workflowExternalId: "<workflow-id>", clientData: "<your-user-id>")
        .apiKey("<pk_sandbox_… or pk_live_…>")
        .build()

    var body: some View {
        Button("Verify identity") { show = true }
            .othentoVerification(isPresented: $show, config: config) { result in
                switch result {
                case let .completed(decision, externalId): print(decision, externalId)
                case let .cancelled(reason): print("cancelled", reason)
                case let .failed(error, message): print("failed", error.code, message)
                }
            }
    }
}
```

## Quick start — listener API (SwiftUI or UIKit)
```swift
let sdk = OthentoSDK(config: config, listener: self)   // self: OthentoSDKListener
// SwiftUI: OthentoFlowView(sdk: sdk)
// UIKit:   present(sdk.viewController(), animated: true)
```
`OthentoSDKListener` delivers `onReady`, `onSessionCreated(externalId:sessionUrl:)`,
`onStatusChanged`, `onCompleted(decision:externalId:)`, `onCancelled(reason:)`,
`onError(_:displayMessage:)`.

## Configuration
Create mode (recommended): `apiKey` (publishable `pk_…` key) + `workflowExternalId`
+ `clientData` (your end-user id) + optional `expectedDetails`.
Token mode: `.tokenMode(sat:)` with a backend-minted session access token.

**Sandbox vs live is decided by your API key, server-side** — you pass nothing
about environment. A sandbox key surfaces a sandbox indicator in the flow UI.

## License
MIT — see [LICENSE](LICENSE).
