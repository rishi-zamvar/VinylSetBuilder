# Empirical Findings

Tests run directly against the owner's own credentials and accounts. These are facts about
*this* setup, not general research — the research agents cannot reproduce them.

**Date:** 2026-08-29

---

## Spotify Audio Features — DEAD ❌

Tested with the owner's existing `SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET`
(`~/.config/keys/.env`), client-credentials flow.

| Step | Result |
|------|--------|
| `POST /api/token` (client_credentials) | ✅ 200, token issued |
| `GET /v1/search?q=…&type=track` | ✅ 200, returns track id `0G7qyvqwjfMdHZn4RwiAdf` |
| `GET /v1/audio-features/{id}` | ❌ **403** |

**Conclusion:** the credentials are valid and the account works — the *endpoint* is closed.
This is the November 2024 deprecation of `audio-features` for non-grandfathered clients.
The owner's client is NOT grandfathered.

**Implication:** Spotify cannot supply tempo or key. Do not plan against it. Also rules out
the related `audio-analysis` endpoint, which was deprecated in the same wave.

---

## GitHub Pages — CANNOT BUILD ❌

Attempted to host a crawler-visible backlink page to satisfy GetSongBPM's mandatory
backlink requirement.

| Step | Result |
|------|--------|
| Public repo created + pushed | ✅ `github.com/rishi-zamvar/VinylSetBuilder` |
| README contains `getsongbpm.com` link | ✅ |
| GetSongBPM validator against repo URL | ❌ "Link not found" |
| `curl` the repo page, grep for `getsongbpm` | ❌ **0 hits in 304 KB of HTML** |
| Enable Pages, legacy builder | ⚠️ accepted, `status: null`, **no build ever queued** |
| Force build via API | ⚠️ returned `queued`, then vanished; builds list `[]` |
| Switch to Actions workflow deploy | ❌ `Actions has been disabled for this user` (HTTP 422) |
| Repo-level Actions permissions | ✅ `enabled: true` — so the block is **account-level** |

**Two distinct root causes:**

1. **GitHub does not server-render the README** into the repo page HTML — it is lazy-loaded
   client-side. Any crawler that fetches the URL sees no link. This is why a plain repo URL
   can never satisfy a backlink validator.
2. **GitHub Actions is disabled at the account level**, and the Pages builder runs on
   Actions infrastructure. Both the legacy builder and the workflow therefore no-op silently.

**To unblock (requires the owner, not Claude):** re-enable Actions in GitHub account
settings — most likely a spending-limit or account-flag issue. Then the already-committed
`.github/workflows/pages.yml` will deploy `index.html` (which is written and pushed) to
`https://rishi-zamvar.github.io/VinylSetBuilder/`, where the backlink IS in the raw HTML.

**Or:** make GetSongBPM unnecessary. See `BPM-SOURCES.md`.

---

## Local BPM/Key Corpus — AVAILABLE ✅

`~/Documents/Projects/walkman-dj/data/library.db`, table `recordings`:

| Metric | Count |
|--------|-------|
| Total recordings | 7,098 |
| With `bpm` | 7,010 |
| With `camelot` | 7,025 |
| **With BOTH `bpm` and `camelot`** | **7,010** |

Columns present: `artist`, `title`, `bpm`, `camelot`, `key`, `akey`, `spotify_key`,
`bpm_confidence`, `artist_genres`.

Same genres as the vinyl collection (jungle / DnB / garage), DSP-derived from the owner's
own audio. Free, offline, no rate limit, no licence issue — it is the owner's own data.

**Implication:** a pruned `(artist, title, bpm, camelot)` table is a few hundred KB and can
be bundled read-only into the app bundle as tier 0 of the resolution ladder. Zero network,
zero latency, and it is the *only* tier with no external dependency at all.

---

## Credentials Inventory

| Source | Status | Location |
|--------|--------|----------|
| Discogs token | ✅ present | `~/.config/keys/enrich.env` → `DISCOGS_TOKEN` |
| MusicBrainz | ✅ no key required — User-Agent string only | n/a |
| AcoustID | ✅ present but **unusable** — fingerprints audio, and this app has none | `~/.config/keys/.env` → `ACOUSTID_API_KEY` |
| Last.fm | ✅ present (crowd genre/mood tags, no tempo) | `~/.config/keys/enrich.env` |
| Spotify | ✅ present, ❌ audio-features 403 | `~/.config/keys/.env` |
| SoundCloud | ✅ present (working OAuth + download path proven in CrateDig) | `~/.config/keys/.env` |
| GetSongBPM | ❌ not issued — blocked on the backlink problem above | — |
