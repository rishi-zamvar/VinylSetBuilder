import Foundation

/// OCR-03 — the words the reader is told to expect.
///
/// The recurring label and artist names in the owner's own crate, taken from the twelve
/// photographed sleeves and from the spike's scored results. It is a **bias list, not a
/// dictionary**: the platform documents `customWords` as supplementing the language model at
/// the word-recognition stage, and community reports are that its effect on stylised label
/// typography ranges from useful to nil. Nothing here is relied on for correctness — the
/// measured gate in `Scripts/ocr-score.sh` is what says whether it helped.
///
/// It lives in Core, not beside the reader, so that the list is testable, diffable, and grows
/// with the collection rather than with the framework binding.
public enum RecognitionVocabulary {
    /// Labels, artists and the imprint names that recur across the crate.
    public static let sleeveTerms: [String] = [
        // labels
        "Timeless Recordings", "Technique Recordings", "Emotif", "Xstatic",
        "Higher Education", "Series 3 Music", "Renegade Hardware", "Full Cycle",
        "Metalheadz", "Moving Shadow", "V Recordings", "Prototype", "Ram Records",
        // artists on these twelve sleeves
        "Abstract", "Dom & Roland", "The Accidental Heroes", "Cause 4 Concern",
        "fellowship", "Drumsound", "Simon Bassline Smith", "G Squad", "DJ Krust",
        "Distorted Minds", "MC Skibadee", "DJ Kane", "Dave Angel", "Skynet",
        // the words a drum'n'bass sleeve prints around its titles
        "Dragstar", "Elementz", "Dubtrack", "Supersonic", "Da Lick", "Invocacion",
        "Wide Open", "Stay Focused", "Sonic Art", "High Down", "Strange Nature",
        // side markers, which the reader mangles more than any other text
        "SIDE A", "SIDE AA", "SIDE ONE", "COLD SIDE", "STEEL SIDE",
    ]
}
