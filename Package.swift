// swift-tools-version: 5.9
// Public distribution manifest for the Othento iOS SDK.
//
// This file lives at the ROOT of the separate PUBLIC repo
// (github.com/Othento/ios-sdk).
//
// Othento.xcframework statically links and embeds PhoneNumberKit, so that
// stays invisible to consumers. AWS Rekognition Face Liveness cannot be folded
// in the same way — amplify-ui-swift-liveness is a large source package with
// its own resource bundles — so it is declared here as a real package
// dependency. Integrators still add exactly ONE package: SPM resolves Amplify
// for them.
//
// `OthentoLink` is an (almost) empty source target whose only job is to carry
// that dependency into the `Othento` product; a `.binaryTarget` cannot declare
// dependencies of its own. It also re-exports the binary framework's module,
// so `import Othento` keeps working unchanged for consumers.
//
// ──────────────────────────────────────────────────────────────────────────
// The binaryTarget's `url` and `checksum` below always point at the LAST
// PUBLISHED release, so this manifest resolves at every commit. They are
// rewritten by scripts/release.sh, which matches them by their own indented
// line — do not move them onto a `.package(url:` style line or reformat them
// across lines, or the release bump will silently miss them.
//
// The checksum is computed from the SIGNED, re-zipped framework. The build
// script also prints one for the UNSIGNED zip; that is pipeline proof only.
// See dist/RELEASING.md.
// ──────────────────────────────────────────────────────────────────────────
import PackageDescription

let package = Package(
    name: "Othento",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "Othento",
            targets: ["OthentoLink", "OthentoBinary"]
        ),
    ],
    dependencies: [
        // Pinned exactly, and deliberately NOT the newest: liveness 1.4.5 /
        // amplify-swift 2.58.5 use `@preconcurrency` on a protocol conformance,
        // which is Swift 6 syntax and needs Xcode 16. 1.4.0 + 2.49.0 build on
        // Swift 5.10 and expose the identical FaceLivenessDetectionError set,
        // so integrators on Xcode 15.4 can consume this release.
        .package(url: "https://github.com/aws-amplify/amplify-ui-swift-liveness", exact: "1.4.0"),
        .package(url: "https://github.com/aws-amplify/amplify-swift", exact: "2.49.0"),
    ],
    targets: [
        .binaryTarget(
            name: "OthentoBinary",
            url: "https://github.com/Othento/ios-sdk/releases/download/0.2.1/Othento.xcframework.zip",
            checksum: "36ac1d4c530b8bcd9be415be4bec7af5335a41adc28f3cd15cdb26ff76f25290"
        ),
        .target(
            name: "OthentoLink",
            dependencies: [
                "OthentoBinary",
                .product(name: "FaceLiveness", package: "amplify-ui-swift-liveness"),
                .product(name: "AWSPluginsCore", package: "amplify-swift"),
            ],
            path: "Sources/OthentoLink"
        ),
    ]
)
