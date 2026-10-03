# Release checklist

## Build

```bash
cd app
flutter analyze && flutter test
```

Signing: create `app/android/key.properties` (git-ignored) with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Without it the release build is debug-signed, which is fine for CI and never for distribution.

```bash
flutter build apk --release --target-platform android-arm64     # or: flutter build appbundle --release
```

The release build enables R8 shrinking (`android/app/proguard-rules.pro`). **Run the release APK on a device and load the model once**, because shrinking problems in native-library plugins only show up at runtime.

Requirements: Android 12+ (minSdk 31), arm64 device for Gemma (LiteRT-LM is arm64 only).

## Device test plan (cannot be done in CI)

Run on at least: one 4 GB phone, one 6–8 GB phone, one 12 GB+ phone.

| Test | Pass condition |
|---|---|
| Airplane mode after model + map installed | Emergency, library, chat, photo analysis, voice (with offline pack), trail recording, compass, map all work |
| Model install on Wi-Fi, kill the app mid-download | Download resumes; installed model loads |
| Install E2B and E4B | Correct variant offered by RAM; GPU or CPU shown in Offline AI; speed test numbers recorded |
| Two photos then voice then text in a row | No crash, memory freed on pressure |
| Record a 2 h trail with screen off | Foreground notification shown; route has no long gaps; survives app kill and restart |
| Battery | Record % per hour with tracking on, with battery saver on, with AI idle and in use |
| TalkBack, 200 % font scale | All emergency actions reachable and readable |
| Telugu / Hindi | Voice recognition with realistic accents and noise; protocol text reads correctly |
| Delete all my data | Profile, contacts, trips, notes, chat gone after restart |

Record the Offline AI speed-test numbers per device in the release notes. Do not publish a latency figure you have not measured.

## Before public release

- [ ] Clinician sign-off ([MEDICAL_REVIEW.md](MEDICAL_REVIEW.md)), `reviewed: true` per protocol
- [ ] Hindi and Telugu reviewed by native medical reviewers
- [ ] A hosted map catalogue (`VANA_REGION_MANIFEST`) with checksums, or ship without downloads
- [ ] Privacy policy that matches [ARCHITECTURE.md](ARCHITECTURE.md) (network uses listed there)
- [ ] Regulatory assessment (CDSCO)
- [ ] Final launcher icon and store assets (the Flutter default icon is still in place)
