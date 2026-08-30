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

---

## Tier-0 Corpus — BUILT, but a genre caveat ⚠️

Pruned `walkman-dj/data/library.db` → a bundleable read-only SQLite.

```sql
SELECT lower(trim(artist)), lower(trim(title)), artist, title, bpm, camelot
FROM recordings
WHERE bpm IS NOT NULL AND camelot IS NOT NULL AND artist <> '' AND title <> ''
GROUP BY lower(trim(artist)), lower(trim(title));
```

| Property | Value |
|----------|-------|
| Unique (artist, title) rows | **6,608** (down from 7,010 — 402 were case/whitespace dupes) |
| File size | **880 KB** — trivially bundleable |
| `journal_mode` | `delete` — the WAL→DELETE conversion the stack research flagged is done |
| Indexes | `(artist_norm, title_norm)` and `(title_norm)` |

### ⚠️ Correction to an earlier claim

PROJECT.md originally stated this corpus is in "the same genres as the vinyl collection
(jungle / DnB / garage)". **The data does not support that.** Tempo distribution:

| Band | Tracks | Share |
|------|--------|-------|
| 100–139 BPM (house / techno) | 3,612 | **55%** |
| 140–159 BPM | 1,304 | 20% |
| < 100 BPM | 903 | 14% |
| **160–184 BPM (jungle / DnB)** | **789** | **12%** |

The `artist_genres` column is empty for effectively every row (6,496 `(none)`, 514 `[]`), and
a text search for jungle / drum & bass / garage / breakbeat returns **0 rows**, so tempo is
the only available proxy. Spot-checking artists (`&ME`, melodic house) confirms the skew.

**Implication:** tier 0 is still worth bundling — it is 880 KB, free, offline and instant —
but its expected hit rate against a *jungle/DnB vinyl crate* is likely modest, not high.
The real load will fall on the SoundCloud → Music Understanding tier and on manual entry.
Weight the roadmap accordingly, and measure the actual tier-0 hit rate early rather than
assuming it.

**Data-quality note:** near-duplicate titles can carry different keys — e.g.
`The Rapture Pt. II` → 3A and `The Rapture, Pt. II` → 2B, the same track punctuated two ways.
Matching must normalise punctuation, and conflicting hits need a tie-break rule.

**Not committed to git.** At 880 KB it would publish the owner's entire music library listing
to a public repo. It is generated at build time from the local source, same pattern as
`Secrets.swift`. Build artifact path is gitignored.
