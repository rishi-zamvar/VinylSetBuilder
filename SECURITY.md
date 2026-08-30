# Security posture

This repository is **public**. Audited 2026-08-30.

## Audit result: clean

| Check | Result |
|---|---|
| 10 credential values (Discogs, SoundCloud ×2, Spotify ×2, AcoustID, Last.fm ×2, Anthropic, OpenAI) searched across all tracked files | ✅ none present |
| Same 10 values searched across **all 70 commits** via `git log -S` | ✅ never committed, in any commit |
| `Secrets.swift`, `.env`, `bpmkey.db`, `*.HEIC`, `*.mobileprovision`, `*.p12`, `*.pem`, `id_rsa` ever added | ✅ none ever committed |
| Generic high-entropy `key/secret/token/password = <20+ chars>` patterns | ✅ none |
| `Scripts/generate-secrets.sh` (the one tracked file that touches secrets) | ✅ references only variable NAMES and paths — `$DOT_ENV`, `$ENRICH_ENV`, `$OUT_FILE` — never a value |

## How secrets stay out

Credentials live **only** in `~/.config/keys/`, outside the repository. At build time an Xcode
Run Script phase generates `App/Generated/Secrets.swift`, which is gitignored. The keys are
compiled into the binary as intended and never enter version control.

`.gitignore` covers: `Secrets.swift`, `.env`, `.local/`, `Tests/Fixtures/Labels/`,
`VinylSetBuilderCore/.build/`, `.swiftpm/`.

Also deliberately excluded, though not credentials:
- `.local/bpmkey.db` — 6,608 rows of the owner's personal music library
- `Tests/Fixtures/Labels/*.HEIC` — photographs taken in the owner's home

## The one identifier that IS public, knowingly

```
project.yml:32   DEVELOPMENT_TEAM: 373D7DZ9NM
```

An Apple **Team ID is an identifier, not a credential.** It cannot sign anything without the
private key held in the macOS Keychain, which is not in this repository and cannot be derived
from the Team ID. Team IDs appear routinely in App Store metadata, MDM profiles and public
repositories.

Committed knowingly, with the owner's explicit approval (2026-08-30), because it makes
device-signed builds work with `-allowProvisioningUpdates`.

**To remove it later** — one line, no functional loss:
```yaml
DEVELOPMENT_TEAM: ${DEVELOPMENT_TEAM}
```
then `export DEVELOPMENT_TEAM=…` in `~/.config/keys/.env`, which the build already sources.

## Re-running this audit

```bash
for n in DISCOGS_TOKEN SOUNDCLOUD_CLIENT_SECRET SPOTIFY_CLIENT_SECRET ACOUSTID_API_KEY; do
  git log --all -S"${!n}" --oneline | head -1
done   # any output = a leak, in that commit
```

Run it before making the repository public again after any history rewrite.
