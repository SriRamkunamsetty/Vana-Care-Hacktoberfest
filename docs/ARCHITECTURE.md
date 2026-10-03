# Architecture

## Principle

The model explains. Rules and approved content decide. Gemma 4 never overrides an emergency rule, never invents a treatment, and is not needed for any life-safety path.

## Modules (`app/lib`)

| Module | Responsibility |
|---|---|
| `domain/safety.dart` | `SafetyEngine`: ordered keyword rules in English, Hindi and Telugu mapping text to a protocol and a "call 112" decision; `sanitize()` strips dose statements and definite diagnoses from model output |
| `data.dart`, `data_i18n.dart` | Protocols (`Guide`) with `version`, `source`, `reviewed`; Hindi and Telugu renderings |
| `ai/knowledge.dart` | Builds chunks from protocols and `assets/knowledge/field_guide.json`, stores them in SQLite, BM25 search |
| `ai/llm.dart` | `LlmBackend` interface (the seam used by tests and by the production model) |
| `ai/gemma_manager.dart` | Download, install, load and unload Gemma 4 (flutter_gemma + LiteRT-LM). E4B for ≥ 8 GB RAM, E2B for ≥ 4 GB, otherwise guides-only mode. GPU with CPU fallback. Frees weights on memory pressure |
| `ai/assistant.dart` | `VanaAssistant`: safety → retrieval → prompt → Gemma → validation. One small prompt per task (health, emergency phrasing, query translation, vision) |
| `core/db.dart`, `data/repositories.dart` | SQLite schema and repositories: knowledge chunks, health sessions, symptoms, trips, route points, offline regions |
| `maps/` | MBTiles reader, flutter_map tile provider, resumable checksum-verified region downloads |
| `voice.dart` | Speech recognition (on-device first, flagged if it falls back to the network) and text-to-speech |
| `state.dart` | `AppState`: wires everything together for the UI |

## Data and privacy

- Medical ID, contacts and emergency events: `flutter_secure_storage` (Android Keystore).
- Trips, route points, health notes, knowledge chunks, map regions: SQLite in app-private storage. Android backup is disabled.
- Health notes are saved only if the user turns on "Save health sessions".
- Logging is silent in release builds, and no code logs user text or coordinates.
- Network use: model download (HuggingFace), optional map catalogue, optional forecast snapshot (Open-Meteo, sends rounded coordinates). Nothing else. Inference never leaves the phone.
- "Delete all my data" wipes all of the above. The model and maps stay.

## Failure behaviour

| Situation | Behaviour |
|---|---|
| Model not installed / unsupported phone | Answers come straight from approved content, with sources. Emergency steps unchanged |
| Model fails or throws | Same fallback |
| Model produces a dose or a diagnosis | Sentence removed |
| Photo with no model | Explains how to install the model. No fake analysis |
| Poor photo / malformed model JSON | "Could not make out enough", never invented features |
| No GPS fix | Last known position with its age |
| No map region | Plain trail view with a prompt to add a map |

## Known limits

- Retrieval is lexical (BM25). Non-English free-text questions use Gemma to translate the query to English keywords when the model is installed; without it, only the rule-based emergency routing works in Hindi and Telugu.
- The vision flow uses the system camera/gallery picker, not an in-app live viewfinder.
- Gemma's own audio input is not used; voice relies on the phone's speech recogniser.
- `flutter_gemma` ships LiteRT-LM for arm64 only on Android.
