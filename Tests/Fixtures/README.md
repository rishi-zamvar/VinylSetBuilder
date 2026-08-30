# Fixtures

## Labels/  (gitignored)

12 photographs of real records from the owner's crate, the golden fixture set for
segmentation and OCR accuracy.

**Deliberately not committed.** The repo is public (required for the data-source
attribution page), and these are photographs taken in the owner's home. They live locally
only. Source of record: `~/Desktop/test/*.HEIC`.

Restore with:

```bash
mkdir -p Tests/Fixtures/Labels && cp ~/Desktop/test/*.HEIC Tests/Fixtures/Labels/
```

Baseline OCR results for these fixtures — 6 clean / 5 partial / 1 fail, with per-fixture
scoring — are recorded in `.planning/research/OCR-SPIKE.md`. Any change to segmentation
should be measured against that baseline.
