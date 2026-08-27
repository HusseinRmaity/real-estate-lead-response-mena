---
version: 1
last_updated: 2026-08-21
change_reason: Initial version. `02b - Close Stale Conversations` previously moved a silent lead straight to `dead` after 48h with no message at all — the lead's last experience was the conversation simply stopping. This prompt writes the single follow-up now sent at 24h.
model: claude-haiku-4-5-20251001
purpose: Write ONE short, context-aware WhatsApp follow-up to a lead who went quiet, before the 48h auto-close
---

# Nudge Writer

Runs inside `02b - Close Stale Conversations`, once per lead selected by the hourly sweep.

A lead who has been silent for 24–48 hours gets exactly one follow-up. It is written fresh per
lead rather than templated, so it can reference what the conversation was actually about — the
area, the property type, the question they never answered. Runs on **Claude Haiku 4.5**
(~$0.0005 per nudged lead); this is a short, low-stakes message and does not need Sonnet.

On API failure the workflow does NOT block — `Parse Nudge` falls back to a static per-language
template, sets `nudge_degraded: true`, and the run is logged as `partial`. The lead still gets
a message.

## Where this prompt actually lives

⚠ **This file is documentation. Nothing reads it at runtime.** The prompt that runs is a
hardcoded string array inside the `Build Nudge Request` Code node of
`02b - Close Stale Conversations` (workflow `YuCbQzFpV7yBAuI0`), and it is mirrored again in
`workflows/02b-close-stale-conversations.json`.

**Any change to this prompt must be made in all three places, in the same sitting:**

1. this file (bump `version` + `change_reason`),
2. the live `Build Nudge Request` node,
3. `workflows/02b-close-stale-conversations.json`.

See `prompts/intent-classifier.md` for what happens when this rule is not followed — that
prompt drifted from its node for weeks and the classifier looked broken when it was faithfully
following a prompt nobody had read.

## System prompt

```
You write ONE short WhatsApp follow-up to a real-estate lead in MENA who stopped replying about
24 hours ago. If they stay silent the agency closes the conversation.

Write ONLY the message text. No JSON, no quotes, no preamble, no sign-off.

LANGUAGE: write in the lead language given below (ar | en | fr | mixed). ar = natural Arabic in
the country register (Gulf / Levant / Egyptian).

CULTURAL (non-negotiable): no religious phrasing, and never in-sha-Allah for timing. Neutral
greeting (marhaba / Hello / Bonjour). Currency is NEVER assumed. Formality by tone: casual or
short history => informal Arabic anta; formal or business => hadretak; unsure => lean respectful.

CONTENT: reference the specific thing they were actually discussing (area, property type, budget
only if they stated one). Ask ONE light question that makes replying easy. Never invent facts.
No pressure, no hype, no discounts, no promises about timing, and do NOT say the conversation is
about to be closed.

LENGTH: under 300 characters. At most one tasteful emoji, and only if the transcript is casual.
```

## User prompt template

```
Lead: {{first_name}}
Language: {{language}}
Country: {{country_code}}
Looking for: {{property_interest}}
Area: {{area_of_interest}}
Budget: {{budget_max}} {{currency}}   (or "(none given)")
Timeline: {{timeline}}

Conversation so far (A = agency, L = lead):
{{transcript}}

Write the follow-up message now.
```

## Design notes

- **Do NOT mention the impending close.** "Reply or we close your file" is a threat, and it reads
  badly in every one of the three languages. The nudge is a helpful check-in; the close is an
  internal state change the lead never needs to know about.
- **One question only.** The lead already stopped replying once — a message with three questions
  in it is less likely to get answered, not more.
- **Budget is passed as `(none given)` when unstated**, never as a guess, and currency is never
  inferred from the country. This is the same rule the conversation handler follows.

## Verified output

Live run 2026-08-21 (lead silent 30h, transcript ended on an unanswered budget/currency question,
the lead having mentioned wanting a sea view):

> Hi Nadia, just following up on the 2-bed with sea view in Dubai Marina. To help us narrow down
> options, what's your budget range looking like?

`nudge_degraded: false`, Twilio SID `SMa239649b274d025702eb12d319d78ba3`. It picked up the sea
view from the lead's own message and re-asked the question she had not answered.

## Fallback templates

Used only when the model call fails or returns nothing (`nudge_degraded: true`). Defined in the
`Parse Nudge` node.

| Lang | Text |
|---|---|
| en | Hi {name}, just checking in on your property search. Still looking? Happy to help whenever you are ready. |
| ar | مرحبا {name}، حابين نطمن عليك بخصوص بحثك عن العقار. لسا عم تدور؟ نحنا جاهزين نساعدك وقت ما تكون جاهز. |
| fr | Bonjour {name}, toujours a la recherche ? Nous restons a votre disposition quand vous voulez. |

⚠ **The Arabic fallback is pending native review.** It is written in Levantine register with
informal `أنت`, no religious phrasing, and no timing promise — but the register choice should be
confirmed against `arabic-style.md` before this is treated as final. The model-generated path is
the normal case; this string only appears during an Anthropic outage.
