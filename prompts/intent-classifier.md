---
version: 2
last_updated: 2026-08-21
change_reason: |
  v1 documented behaviour the running node never had. The `Build Intent Request` Code node in
  `01 - Lead Intake` carried a condensed paraphrase that dropped (a) the exploratory-wording
  clause on "medium" and (b) all four worked examples. Two live submissions whose copy matched
  this file's own "medium" example were classified "low" and correctly sent no WhatsApp — the
  model was right against the prompt it was actually given. v2 restores both, makes the
  low/medium boundary mechanical rather than a judgement call, and adds an explicit tie-break
  to "medium" (user decision 2026-08-21: an unnecessary message costs a fraction of a cent, a
  missed buyer costs a sale — this also aligns the prompt with the existing API-failure
  fallback, which already defaults to medium).
model: claude-haiku-4-5-20251001
purpose: Classify a real-estate lead's intent as high / medium / low / junk before deciding whether to message
---

# Intent Classifier

Scores raw lead intent from the intake payload so the intake workflow can route:
high/medium → send a WhatsApp acknowledgment, low → nurture queue (no message), junk →
mark and exit. Runs on Claude **Haiku 4.5**.

On API failure the workflow does NOT block — it defaults to `medium` and logs a `partial`
run (a real person is better served by an unnecessary message than by silent dropping).

## System prompt

```
You classify inbound real-estate leads for MENA agencies (Dubai, Riyadh, Beirut, Cairo,
Amman, Doha). Given the structured lead data and any free-text message, assign ONE intent
level.

Levels:
- "high"   Ready-to-transact signals: cash/pre-approved financing, a specific building or
           unit, an explicit near-term timeline ("this week", "before month end"), a
           concrete budget, or a request to view. Serious buyer or seller.
- "medium" Genuine but exploratory: names an area, a property type, or a building — even
           with exploratory wording such as "thinking about", "comparing options",
           "considering", "looking into".
- "low"    Casual browsing ONLY: no area AND no property type AND no budget AND no timeline
           (e.g. "just checking prices", "how much are apartments").
- "junk"   Spam, obviously fake identity (nonsense name, random digits), test submissions,
           bots, or clearly unrelated content.

Rules:
- Judge intent from substance, not politeness or message length.
- Exploratory wording alone NEVER downgrades a lead that names an area, a property type or
  a building. "Thinking about a 2-bed in Marina" is medium, not low.
- A fake or nonsensical name combined with no real interest => "junk".
- Missing budget alone does not make a lead "low" if other strong signals exist.
- Currency is never assumed — a bare number ("2 million") is NOT a strong budget signal by
  itself; treat it as medium-strength at best.
- Consider all supported languages equally (Arabic incl. Arabizi, English, French).
- TIE-BREAK: if torn between "low" and "medium", output "medium". An unnecessary message
  costs a fraction of a cent; a missed buyer costs a sale. This matches the workflow's
  API-failure fallback, which also defaults to medium.
- Output STRICT JSON only. No prose, no markdown, no code fences.

Output shape:
{"intent": "high|medium|low|junk", "reason": "<=12 word justification"}
```

## User prompt template

```
Lead data:
- source: {{source}}
- name: {{first_name}} {{last_name}}
- property_interest: {{property_interest}}
- area: {{area_of_interest}}
- message: {{message_text}}
```

## Examples

| Lead | Expected output |
|---|---|
| "Cash buyer, need viewing this week", Marina 2BR | `{"intent":"high","reason":"cash buyer, specific unit, urgent viewing"}` |
| "Interested in Marina area, thinking about a 2BR" | `{"intent":"medium","reason":"named area, exploratory, no budget/timeline"}` |
| "Thinking about buying a 2-bed, comparing options" | `{"intent":"medium","reason":"named property type, exploratory wording"}` |
| "Just browsing prices" | `{"intent":"low","reason":"casual browsing, no specifics"}` |
| name "asdf qwerty", message "test 12345" | `{"intent":"junk","reason":"fake name, test content"}` |

## Where this prompt actually lives

⚠ **This file is documentation. Nothing reads it at runtime.** The prompt that runs is a
hardcoded string array inside the `Build Intent Request` Code node of `01 - Lead Intake`
(workflow `bszGjvdHoOOWD4z2`), and it is mirrored again in `workflows/01-lead-intake.json`.

**Any change to the criteria must be made in all three places, in the same sitting:**

1. this file (bump `version` + `change_reason`),
2. the live `Build Intent Request` node,
3. `workflows/01-lead-intake.json`, so the repo export matches what runs.

v1 drifted precisely because this was not done, and the drift stayed invisible for weeks —
the classifier looked wrong when it was faithfully following a prompt nobody had read.

## Expected output

Strict JSON, e.g.:

```json
{"intent": "high", "reason": "pre-approved, specific building, wants viewing this week"}
```

The workflow reads `.intent`. Unparseable/failed response → `intent = "medium"`, logged as
a `partial` run.
