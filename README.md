# Real Estate Lead Response & AI Qualification — MENA Edition

A production-grade **n8n** system that answers real estate leads on **WhatsApp in under 60 seconds**, qualifies them through a **bilingual (Arabic / English / French)** AI conversation, scores intent, syncs to a CRM, and hands a scored lead to a human agent — day or night, weekend or weekday, prayer-time aware.

Built for MENA agencies (Dubai, Riyadh, Beirut, Cairo, Amman, Doha) that lose leads to slow WhatsApp follow-up. Self-initiated portfolio project — a real, working system, not a mockup.

**Demo — the same live lead, walked through end to end in both languages:**

| English walkthrough | العرض بالعربي |
|---|---|
| [![English walkthrough](https://img.youtube.com/vi/MEebh0leVys/mqdefault.jpg)](https://youtu.be/MEebh0leVys) | [![العرض بالعربي](https://img.youtube.com/vi/lS2NAjy52xM/mqdefault.jpg)](https://youtu.be/lS2NAjy52xM) |

---

## What it does

A lead arrives from a website form, Property Finder / Bayut / Dubizzle, a Meta lead ad, or a CRM webhook. Within 60 seconds:

1. The lead is **validated, deduplicated, language-detected, and intent-scored**, then stored.
2. A **personalized WhatsApp acknowledgment** goes out in the lead's own language — respecting the country's weekend and prayer times.
3. A **multi-turn WhatsApp conversation** (capped at 6 turns) extracts budget, currency, timeline, area, and buyer/seller intent.
4. The lead is **scored 0–100 and tiered** (hot / warm / cold), a **HubSpot contact + deal** is created, and a **rich Slack card** is posted to the agents' channel.
5. Everything is logged; failures are caught by a global error handler and summarized in a daily digest.

---

## Architecture

```
  Lead source (form / Property Finder / Bayut / Meta Lead Ads / CRM webhook)
        │  POST JSON
        ▼
┌─────────────────────────────────────────────────────────────┐
│  01 — Lead Intake                                           │
│  Webhook → Validate → Dedupe (SHA-256, 72h) → Detect        │
│  Language (Haiku) → Classify Intent (Haiku) → Insert →      │
│  Send-window + prayer-time gate → WhatsApp acknowledgment   │
└─────────────────────────────────────────────────────────────┘
        │                         ▲
        ▼                         │ inbound reply (Twilio webhook)
┌─────────────────────────────────────────────────────────────┐
│  02 — WhatsApp Reply Handler                               │
│  Lookup lead → Load history → Extract + Respond (Sonnet)    │
│  → 6-turn cap → Update lead → continue / handoff / end      │
│        └── handoff ─► Score (Sonnet) → HubSpot upsert +     │
│                       deal → Slack #leads → handed_off       │
└─────────────────────────────────────────────────────────────┘

  02b — Close Stale Conversations   hourly sweep: nudge at 24h silence, close at 48h (reopenable 7d)
  03 — Daily Digest                 08:00 summary to #leads (volume, tiers, run health)
  99 — Error Handler                global: unhandled crash → run_logs + #automation-errors
  00 — Health Check                 dependency reachability probe
```

Two main workflows by design — n8n doesn't hold long-lived stateful conversations well, so intake and the reply handler are separate and stateless, with all state in Postgres.

---

## Stack

| Layer | Choice |
|---|---|
| Orchestration | n8n (self-hosted, Docker) |
| Language detection & intent | Claude **Haiku 4.5** (fast, cheap) |
| Conversation & scoring | Claude **Sonnet 5** |
| Messaging | Twilio WhatsApp Business API (sandbox for demo) |
| Database | Supabase (Postgres) |
| CRM | HubSpot (parameterized paths for Bitrix24 / Zoho) |
| Notifications | Slack |
| Prayer times | aladhan.com (free) |

Model choice is cost-driven: Haiku handles classification and language detection; Sonnet is reserved for conversation and final scoring.

---

## Built for MENA, not bolted on

- **Trilingual** — Arabic, English, French; the bot matches the language of each message and never forces a switch.
- **Currency-safe** — "two million" is never assumed to be USD; the bot asks, and `budget_min` / `budget_max` / `currency` are stored separately.
- **Weekend-aware** — Gulf (Fri–Sat) vs Levant (Sat–Sun) send windows, per country.
- **Prayer-time-aware** — sends within 15 minutes of a prayer are delayed 30 minutes (aladhan.com); Lebanon opts out (mixed-faith market).
- **Formality-aware** — informal vs formal Arabic based on the sender's tone.

---

## Production hardening (the 8-point standard)

| # | Standard | How it's met |
|---|---|---|
| 1 | Error handling | Every external call has an explicit timeout, retry with backoff, and Continue-On-Fail decision (documented per node). |
| 2 | Validation | Required fields checked at intake; malformed input routes to its own logged branch. |
| 3 | Idempotency | Inbound: `dedup_key` (SHA-256) + UNIQUE + 72h lookback on leads, and a partial unique index on `conversations(twilio_message_id)` so a repeated Twilio MessageSid is dropped, not re-answered. Handoff: an atomic `case1_claim_handoff()` claim, so two concurrent messages produce one CRM record, not two. |
| 4 | Observability | Every execution path writes a `run_logs` row (success / partial / failed) with decision metadata; a daily digest summarizes it. |
| 5 | Global error workflow | `99 - Error Handler` is attached to every main workflow; crashes log + alert `#automation-errors`. |
| 6 | Credentials | All in n8n's encrypted store — never in node bodies or URLs. |
| 7 | Naming | Verb-object node names; sticky notes on non-obvious logic (dedup, 6-turn cap, re-engagement). |
| 8 | Loop caps | 6-turn conversation cap, 48h timeout sweep, bounded waits — no unbounded loops or pagination. |

Graceful degradation is deliberate: an AI/Twilio/Slack outage is Continue-On-Fail (logged `partial`, lead never dropped) and surfaces in the daily digest — it does **not** page the error channel, which is reserved for genuine crashes.

---

## Repository layout

```
├── workflows/          n8n workflow exports (00, 01, 02, 02b, 03, 99)
├── prompts/            versioned Claude system prompts
├── db/                 schema.sql, seed data, migrations
├── web/                lead-form.html (demo front door)
├── tests/              10 lead payload fixtures
├── docs/               case study write-up
└── loom-scripts/       demo scripts (EN + AR)
```

---

## Run it yourself

**Prerequisites:** Docker, a Supabase project, and API access for Anthropic, Twilio (WhatsApp sandbox), HubSpot (private app), and Slack (bot token).

1. **Database** — run `db/schema.sql` then `db/seed-send-windows.sql` in the Supabase SQL editor, then every file in `db/migrations/` in numerical order (002-006).
2. **n8n** — start it (`docker-compose.yml` documents the setup). Before importing, replace `YOUR_PROJECT.supabase.co` with your own Supabase host in every file in `workflows/` (44 occurrences across the six files — one find-and-replace), then import each file.
3. **Credentials** — add Supabase, Anthropic, Twilio, HubSpot, and Slack credentials in n8n's credential store; each imported node references them by name.
4. **Activate** `00`, `01`, `02`, `02b`, `03`, `99`. Wire the Twilio sandbox inbound webhook to `<your-n8n-url>/webhook/whatsapp-inbound`.
5. **Try it** — open `web/lead-form.html` (set `WEBHOOK_BASE` + `WEBHOOK_TOKEN`), submit a lead, watch WhatsApp.

See [`docs/case-study.md`](docs/case-study.md) for the full write-up and the cost / ROI model.

---

## License

MIT — see [`LICENSE`](LICENSE).

## Author

**Hussein Rmaity** — automation engineer, Tyre, Lebanon. WhatsApp-first AI automation for MENA service businesses.
Portfolio: [husseinrmaity.github.io](https://husseinrmaity.github.io) · GitHub: [@HusseinRmaity](https://github.com/HusseinRmaity)

_Self-initiated case study. The system is real and working; the ROI figures in the case study are an illustrative model, labeled as such — no client results are represented._
