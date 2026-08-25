// Intentionally (almost) empty.
//
// This target exists only to carry the FaceLiveness package dependency into
// the `Othento` product — a `.binaryTarget` cannot declare dependencies of its
// own, and without this the linker would have no FaceLiveness symbols to
// resolve the binary framework against.
//
// The re-export means `import Othento` in a consumer app resolves to the
// binary framework's module exactly as it did before this target existed.
//
// Copy this file to `Sources/OthentoLink/OthentoLink.swift` in the PUBLIC repo
// (see dist/RELEASING.md step 5).
@_exported import Othento
