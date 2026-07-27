---
version: 1
last_updated: 2026-07-26
change_reason: Initial version (Milestone 2.7)
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
- "medium" Genuine interest but exploratory: a named area or property type without firm
           budget/timeline, "thinking about", comparing options.
- "low"    Casual browsing: "just checking prices", vague, no area, no timeline, tyre-
           kicking.
- "junk"   Spam, obviously fake identity (nonsense name, random digits), test submissions,
           bots, or clearly unrelated content.

Rules:
- Judge intent from substance, not politeness or message length.
- A fake or nonsensical name combined with no real interest => "junk".
- Missing budget alone does not make a lead "low" if other strong signals exist.
- Currency is never assumed — a bare number ("2 million") is NOT a strong budget signal by
  itself; treat it as medium-strength at best.
- Consider all supported languages equally (Arabic incl. Arabizi, English, French).
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
| "Just browsing prices" | `{"intent":"low","reason":"casual browsing, no specifics"}` |
| name "asdf qwerty", message "test 12345" | `{"intent":"junk","reason":"fake name, test content"}` |

## Expected output

Strict JSON, e.g.:

```json
{"intent": "high", "reason": "pre-approved, specific building, wants viewing this week"}
```

The workflow reads `.intent`. Unparseable/failed response → `intent = "medium"`, logged as
a `partial` run.
