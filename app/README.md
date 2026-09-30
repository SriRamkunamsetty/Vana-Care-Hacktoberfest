# Vana Care (Flutter, Android + iOS)

Implementation of the `Vana Care v2` design (`../project/Vana Care v2.dc.html`). One custom
liquid-glass UI drawn by Flutter itself, so Android and iOS look identical.

```
flutter pub get
flutter run
```

## Layout

| File | What |
|---|---|
| `lib/theme.dart` | Dark/Light design tokens (blueprint palette) |
| `lib/glass.dart` | `Glass`, `Solid`, `ProgressiveBlur`, switch, chips, icon set (SVG paths from the design) |
| `lib/state.dart` | `AppState`: persistence, GPS, compass, battery, trip recording, SOS, chat |
| `lib/data.dart` | First-aid protocols + `AssistantEngine` seam (currently `ScriptedAssistant`) |
| `lib/l10n.dart` | English / Telugu / Hindi strings (untranslated keys fall back to English) |
| `lib/screens/` | Splash + onboarding, Home, Explore/Map/Lost/Toolkit, AI, Library, Profile |
| `lib/sheets.dart` | Emergency, Guide, Voice, Vision, SOS, Contact, Medical ID sheets |

Design rule from the blueprint: glass for navigation / AI controls / non-critical cards; **solid,
high-contrast** cards for emergency and step-by-step content (`Solid`).

## What is real vs. still a stand-in

Real (on device):
- Emergency contacts + Medical ID: encrypted (`flutter_secure_storage`), add / edit / remove, call button
- Call 112, "Share position" and "Send by SMS" (opens the SMS app with the report / coordinates)
- Live GPS position + accuracy, altitude, daylight left (computed from position), battery level
- Compass (magnetometer; flat-phone heading, magnetic north, no tilt compensation)
- Trail recording (foreground), distance / elapsed, map drawing of the recorded path, distance + bearing back to start
- Flashlight SOS strobe (`torch_light`), whistle tone (`audioplayers`), battery saver (lower GPS accuracy)
- SOS: hold 2 s creates a local emergency report (stored encrypted); it is never claimed to have reached anyone
- Theme / language / privacy / pack toggles persist
- Onboarding permission toggles: only Location is requested when you finish setup; camera and photo access are requested when you first use them (the microphone toggle has no effect yet because voice input is a stand-in)

Stand-ins that need real integrations (marked in code):
- **Assistant replies** — keyword script (`ScriptedAssistant`). Implement `AssistantEngine` with Gemma (LiteRT) + local RAG.
- **Vision result** — the photo is picked/captured for real but the findings are scripted; the sheet says so.
- **Voice input** — canned phrase per language; needs offline ASR (+ TTS).
- **Offline packs / onboarding download** — simulated progress; no map tiles are stored. The map screen draws only your recorded path.
- **Weather** — no forecast snapshot exists yet.
- **First-aid protocols** — placeholder text from the design; blueprint requires clinician review, versioning and sources before release.

## Deviations from the prototype (deliberate)
- SOS screen no longer claims "Broadcasting over Bluetooth and sound" (nothing does that); it says the report is saved and offers SMS.
- Vision result adds a "demo result" notice; guide count on Home says 9 (there are 9 guides).
- Hard-coded "Wonderland Trail · Mount Rainier NP" / 1,842 m / 68 % values replaced by live data.
- Trip check-in sends an SMS to your first contact when switched on (the prototype had a fake countdown).
