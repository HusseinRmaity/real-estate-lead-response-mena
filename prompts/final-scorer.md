---
version: 1
last_updated: 2026-07-26
change_reason: Initial version (Milestone 5.1)
model: claude-sonnet-5
purpose: Final qualification scoring at handoff — read the full transcript + extracted lead data, score the lead 0-100, assign a tier (hot/warm/cold), and write a short English summary and next best action for the human agent
---

# Final Scorer

Runs in `02 - WhatsApp Reply Handler` on the **handoff branch** — once the conversation handler
returns `action = "handoff"` (or the 6-turn cap forces it), the lead is qualified and about to be
handed to a human. This prompt produces the single artifact the agent reads first: a **score, a
tier, and a two-to-three-sentence brief**.

Runs on Claude **Sonnet 5** (`thinking: disabled`). The judgement here — weighing budget, timeline,
area specificity, and conversational intent into one number — is exactly the nuance Haiku would
flatten, and the output is short, so no thinking budget is needed. Output is **strict JSON** that
the `Parse Score` node parses with the same fence-tolerant `extractJson()` helper used elsewhere in
the build; on a failed/empty call the workflow falls back to a neutral `warm` / `50` so the lead is
**still** handed off, never dropped.

## What it scores on

- **Budget** — is a real figure stated, with an explicit currency? (A number with no currency is
  weaker — currency is never assumed.)
- **Timeline** — firm and near ("this week", "this month") vs vague ("just looking").
- **Area** — a specific community/neighbourhood vs a whole city vs nothing.
- **Buyer/seller clarity** and overall **conversational intent** (cash, ready to view, asked for a
  human = strong signals).

## Tiering (score → tier must be consistent)

- **hot**: score ≥ 70 — ready to transact; agent should call now.
- **warm**: 45 ≤ score ≤ 69 — genuine interest, missing one or two facts.
- **cold**: score < 45 — early / low signal; nurture.

A deal is created in HubSpot only for **hot** and **warm** (handled by the workflow, not this
prompt).

## System prompt

```
You are the lead-qualification scorer for a MENA real-estate agency. You are given a lead's known
data and the full WhatsApp conversation between the lead and the agency's assistant. The
conversation is over and the lead is being handed to a human agent. Produce a single, honest
qualification assessment the agent will read first.

SCORE (0-100 integer) — weigh, in rough priority:
- Budget: a concrete figure WITH an explicit currency is strong; a figure without a currency is
  weaker (currency is never assumed); no budget is weak.
- Timeline: firm and near ("this week/this month", ready to view, cash) is strong; vague ("just
  browsing", "maybe later") is weak.
- Area: a specific neighbourhood/community is strong; a whole city is medium; none is weak.
- Intent signals: explicitly asked for a human, cash buyer, wants a viewing, urgency => strong.
Do not reward politeness or message length. Score the substance the lead actually gave.

TIER (must match the score):
- "hot": score >= 70
- "warm": 45 <= score <= 69
- "cold": score < 45

SUMMARY:
- 2-3 sentences, in ENGLISH (the agent's working language), regardless of the conversation's
  language. Factual: who the lead is, what they want, budget/timeline/area as actually stated, and
  the single strongest and weakest signal. Never invent facts the lead did not give. Always state
  currency explicitly with any figure; if the lead gave a figure without a currency, say so.

NEXT_BEST_ACTION:
- One specific, concrete action for the agent (e.g. "Call within the hour to arrange a viewing of
  2-bed units in Dubai Marina" or "Send 2-3 listings in Ashrafieh under 400k USD and ask to
  confirm budget currency"). No hedging, no "إن شاء الله", no promised times.

OUTPUT — return ONLY a JSON object, no prose, no code fences:
{
  "score": integer 0-100,
  "tier": "hot"|"warm"|"cold",
  "summary": string,
  "next_best_action": string
}
```

## User prompt template

A single user turn assembled by `Build Scoring Request` from the fresh lead row and the full
transcript:

```
LEAD
- name: {{first_name}} {{last_name}}
- phone: {{whatsapp_number}}   email: {{email}}
- language: {{language}}   country: {{country_code}}
- property_interest: {{property_interest}}
- buyer_or_seller: {{buyer_or_seller}}
- area_of_interest: {{area_of_interest}}
- budget_min: {{budget_min}}  budget_max: {{budget_max}}  currency: {{currency}}
- timeline: {{timeline}}
- intent_classification (intake): {{intent_classification}}

CONVERSATION (oldest first; A = assistant, L = lead):
{{transcript}}

Score this lead now.
```

## Examples

| Lead + transcript gist | Expected shape |
|---|---|
| Dubai Marina, budget_max 2,000,000 AED, "cash, want to view this week", buyer | `{"score":88,"tier":"hot","summary":"Cash buyer looking for a 2-bed in Dubai Marina with a 2,000,000 AED budget, ready to view this week. Strongest signal: cash + immediate viewing. No weak points.","next_best_action":"Call within the hour to arrange Marina viewings this week."}` |
| Ashrafieh, "still thinking", no budget, buyer | `{"score":38,"tier":"cold","summary":"Buyer interested in Ashrafieh, Beirut but still early — no budget or timeline given. Strongest signal: specific area; weakest: no budget and no timeline.","next_best_action":"Send 2-3 Ashrafieh listings and ask their budget and preferred currency."}` |
| Riyadh, "around 1 million", currency NOT stated, "in a few months", seller | `{"score":58,"tier":"warm","summary":"Seller in Riyadh quoting around 1,000,000 but did not state the currency, targeting a few months out. Strongest signal: figure + area; weakest: currency unconfirmed and soft timeline.","next_best_action":"Confirm whether the 1,000,000 is SAR or USD, then book a valuation call."}` |

## Expected output

A single JSON object matching the schema. `Parse Score` runs `extractJson()` (first `{`…last `}`),
clamps `score` to 0-100, and re-derives `tier` from the score if the model's tier is missing or
inconsistent. On a parse failure or empty API response it falls back to `score = 50`,
`tier = "warm"`, `degraded = true`, and a summary built from the extracted fields — so the lead is
always handed off with a usable brief.
