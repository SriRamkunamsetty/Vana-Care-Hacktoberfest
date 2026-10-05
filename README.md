# Vana Care

Offline AI field health and survival companion. Flutter app (Android first, iOS configured) that runs **Gemma 4 on the phone**, with deterministic first-aid protocols, a local knowledge base, GPS trail recording, offline maps and emergency tools. No account, no backend, no cloud inference.

> Vana Care is an information and decision-support tool. It is not a doctor, not a diagnosis, and not a guaranteed rescue service. See [docs/MEDICAL_REVIEW.md](docs/MEDICAL_REVIEW.md) before any public release.

## Layout

| Path | What it is |
|---|---|
| `app/` | The Flutter application |
| `docs/` | Architecture, medical review process, release checklist |
| `.github/workflows/ci.yml` | Analyze, test, build APKs |

## Run it

```bash
cd app
flutter pub get
flutter test
flutter run            # Android device, Android 12+ (API 31)
```

First launch: onboarding offers to download Gemma 4 (E2B ≈ 2.6 GB, E4B ≈ 3.7 GB, chosen from the phone's RAM). The app is fully usable without it: emergency steps, the library, Forest Mode and SOS never depend on the model.

Optional build settings:

```bash
flutter run --dart-define=VANA_REGION_MANIFEST=https://your.host/regions.json   # downloadable map catalogue
```

## How the AI is wired

```
text / voice / photo
        │
  SafetyEngine (rules, EN/HI/TE)  ──► emergency? → protocol steps + Call 112 (never from the model)
        │
  KnowledgeBase (BM25 over SQLite) ──► approved protocols + field guide, with source and version
        │
  Gemma 4 via LiteRT-LM (on device) ──► plain-language explanation, grounded in the retrieved text
        │
  Output validation ──► removes drug doses and definite diagnoses
        │
  Reply: text + steps + sources + "not a diagnosis"
```

Details in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Status against the blueprint

| Blueprint item | Status |
|---|---|
| Local Gemma 4 text assistant (E4B, E2B fallback) | Done. Model manager picks by RAM, GPU→CPU fallback, resumable download |
| Image assessment (visible features, uncertainty, never diagnoses) | Done. Needs a physical phone to verify quality |
| Safety engine + reviewed protocols | Engine done. **Protocol content is a draft and has not been clinician-reviewed** |
| Local RAG with sources | Done (BM25). Vector embeddings are a later upgrade; the DB column exists |
| Voice in/out (EN/TE/HI) | Done via the phone's recogniser and TTS, offline only if the language pack is installed. Gemma audio input is not used yet |
| Emergency Mode, SOS report, 112, contacts | Done (opens the dialer/SMS app; the app never claims a rescuer was reached) |
| GPS, compass, trail recording, Lost Mode | Done. Trail stored in SQLite, foreground service while recording, restored after restart |
| Offline maps | Done for raster MBTiles (import a file, or download from your own catalogue). No hosted catalogue ships with the app |
| Weather snapshot | Done (Open-Meteo, saved for offline reading) |
| Telugu and Hindi | UI strings and all 10 protocols translated. **Translations are unreviewed drafts** |
| Privacy controls, delete-all-data | Done. Health data in encrypted storage, backups disabled |
| Room-style database | Done with SQLite (sqflite) |
| SyncQueue, optional Supabase sync | Not built (blueprint v2) |
| Measured device benchmarks | Speed-test button is built in. **No benchmark numbers exist yet. Test on real phones** |

## Tests

`flutter test` runs 35 tests: safety rules (EN/HI/TE), retrieval, the assistant pipeline with a fake model (including a model that tries to give drug doses), vision parsing, repositories, app state and a full-UI smoke test. **The Gemma model itself is not exercised by tests**; that needs a device.
