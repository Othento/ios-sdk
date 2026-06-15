// swift-tools-version: 5.9
// Public distribution manifest for the Othento iOS SDK.
//
// Manifest-only: ships a prebuilt, self-contained Othento.xcframework as a
// single binaryTarget. The xcframework statically links PhoneNumberKit and
// embeds its metadata bundle inside Othento.framework, so consumers declare
// NO transitive dependencies — `import Othento` is all they need.
import PackageDescription

let package = Package(
    name: "Othento",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "Othento",
            targets: ["Othento"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Othento",
            url: "https://github.com/Othento/ios-sdk/releases/download/0.1.0/Othento.xcframework.zip",
            checksum: "0824e66599462d64ef6066f9938f55bd726eb655070f717faa8d2a0e62205a41"
        ),
    ]
)
