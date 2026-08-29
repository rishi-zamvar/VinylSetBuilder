# Vinyl Set Builder

Personal-use iOS app. Photograph vinyl labels, resolve the metadata, auto-sequence a mixable DJ set.

Point the camera at a record label. On-device Vision OCR reads the track listing,
the tracks are resolved against music metadata services, and a BPM-gated,
harmonically-aware sequencer orders the crate into a set you can actually play.

**Platform:** iOS 17+, SwiftUI, Swift 5.9
**Scope:** single user, on-device only. Not distributed.

## How it works

1. **Capture** — shoot each vinyl label, one side at a time
2. **OCR** — Apple Vision reads the label text with bounding boxes
3. **Segment** — deterministic geometric clustering splits the label into individual tracks
4. **Resolve** — each track is matched to artist, title, BPM and musical key
5. **Sequence** — a beam search finds the longest playable run under a BPM tolerance gate,
   minimising Camelot-wheel distance between neighbours

## Data sources

Track metadata and audio attributes are provided by these services:

- **[GetSongBPM](https://getsongbpm.com)** — BPM and musical key data.
  Tempo and key information powering the set sequencer is provided by
  [GetSongBPM.com](https://getsongbpm.com).
- **[Discogs](https://www.discogs.com)** — release, artist, label and pressing metadata
- **[MusicBrainz](https://musicbrainz.org)** — open music encyclopedia, used as a resolution fallback

## Status

In development.

## Licence

Personal project. Not for redistribution.
