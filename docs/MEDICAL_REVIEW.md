# Medical content review

**Status: no protocol in this repository has been reviewed by a clinician.** Every `Guide` has `reviewed: false` and the app shows "draft, not yet clinician reviewed" on each protocol and under chat answers that cite one. Do not distribute the app publicly until this process is complete.

## What needs review

1. `app/lib/data.dart` — 10 English protocols (steps, red-flag line).
2. `app/lib/data_i18n.dart` — Hindi and Telugu versions. These also need a native-speaking medical reviewer, not only a translator.
3. `app/assets/knowledge/field_guide.json` — 14 field-guide documents (lost, water, wildlife, danger signs).
4. `app/lib/domain/safety.dart` — the trigger keywords and which protocol each routes to. Review false negatives especially.
5. Prompts in `app/lib/ai/assistant.dart`.

## Sign-off procedure

For each protocol and document:

1. Reviewer compares with the cited source (WHO Basic Emergency Care, and Indian first-aid guidance such as the relevant national or Red Cross material).
2. Edits are made in the Dart/JSON source, `version` is bumped, `source` is set to the exact document and section, and `reviewed` is set to `true` only for that version.
3. Reviewer name, credential and date are recorded in the release notes (not in the app).
4. Any later content change resets `reviewed` to `false` until re-signed.

## Scenario testing (needs clinicians)

Do not validate by comparing the model with another model's answer. Use clinician-written scenarios, including cases where the safest answer is "call emergency services now". At minimum cover:

- Each emergency rule in `SafetyEngine.rules`, in English, Hindi and Telugu, in plain and misspelt phrasing.
- Ambiguous inputs ("he fell and is quiet"), mixed languages, and negations ("not bleeding").
- Photos: poor light, non-injuries, skin tones, wounds near the edge of frame. Confirm uncertainty is stated and no diagnosis is made.
- Attempts to obtain doses or drug advice. Confirm the app declines.

## Regulatory

India's CDSCO regulates software that is intended for diagnosis, monitoring or treatment. Keep the intended-use statement to information and decision support, keep the "not a diagnosis" wording, and have a regulatory professional assess the final feature set and any claims before public release.
