import Testing
@testable import VinylSetBuilderCore

// CAP-02. The photographs are whole 12" sleeves, not die-cut labels (spike finding 1), so the
// guide has to be provably sleeve-sized. A one-sided coverage assertion cannot tell a sleeve
// guide from a reticle — both halves live in one test so neither can be dropped alone.

@Test("CAP-02: the guide is sleeve-sized, and a label-sized reticle fails the same assertion")
func test_givenTheSleeveGuide_whenMeasured_thenItCoversTheFrameAndAReticleDoesNot() {
    #expect(FramingGuide.sleeve.aspectRatio == 1.0)
    #expect(FramingGuide.sleeve.edgeCoverage > 0.6)

    // Negative control: a label-sized reticle at the same aspect ratio. Without this the
    // assertion above passes on anything square, including a 10%-of-frame circle guide.
    let reticle = FramingGuide(aspectRatio: 1.0, insetFraction: 0.45)
    #expect(reticle.edgeCoverage < 0.6)
}

@Test("CAP-02: edge coverage is the inset arithmetic, checked at both ends")
func test_givenAnyInset_whenCoverageIsRead_thenItIsOneMinusTwiceTheInset() {
    #expect(FramingGuide(aspectRatio: 1.0, insetFraction: 0).edgeCoverage == 1.0)
    #expect(FramingGuide(aspectRatio: 1.0, insetFraction: 0.5).edgeCoverage == 0.0)
    #expect(abs(FramingGuide.sleeve.edgeCoverage
                - (1 - 2 * FramingGuide.sleeve.insetFraction)) < 1e-12)
}
