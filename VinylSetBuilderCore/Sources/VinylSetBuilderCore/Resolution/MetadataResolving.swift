public protocol MetadataResolving: Sendable {
    /// Takes a .pending Track, returns it resolved or with resolutionState == .failed.
    func resolve(_ track: Track) async -> Track
}

// LabelTextRecognizing is deliberately NOT declared here — it takes a CGImage and belongs
// to the app target's OCR layer in Phase 2. Declaring it in Core would put a
// framework-shaped hole in a package that is not allowed to import that dependency.
