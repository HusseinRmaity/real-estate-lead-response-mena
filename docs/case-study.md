# Case Study — Real Estate Lead Response & AI Qualification (MENA)

**Type:** Self-initiated portfolio project — a real, working system built end to end.
**Role:** Sole engineer (architecture, build, testing, hardening).
**Stack:** n8n · Claude (Haiku 4.5 + Sonnet 5) · Twilio WhatsApp · Supabase · HubSpot · Slack.

> ▶️ **English walkthrough:** https://youtu.be/OOVjQe0bvBY · ▶️ **العرض بالعربي:** https://youtu.be/lS2NAjy52xM · **Code:** [github.com/HusseinRmaity/real-estate-lead-response-mena](https://github.com/HusseinRmaity/real-estate-lead-response-mena)

---

## The problem

In MENA real estate, the first response wins the deal. Buyers in Dubai, Riyadh, and Beirut expect a **WhatsApp** reply within minutes — not an email, not a callback tomorrow. But agents can't man WhatsApp 24/7, and leads arrive at 11pm, on Fridays, during Ramadan. The lead that waits an hour is usually already talking to a competitor.

The generic fix — a Western, SMS-first, English-only autoresponder — doesn't fit this market. It reads as spam, it ignores Arabic, and it has no idea that Thursday night is the weekend in Riyadh or that a message shouldn't land mid-prayer.

## Who it's for

MENA agencies with 5–50 agents (Dubai, Riyadh, Beirut, Cairo, Amman, Doha) already paying for a CRM and receiving leads through Property Finder, Bayut, Dubizzle, Meta lead ads, or their own site — and losing a share of them to slow follow-up.

## What I built

A production-grade n8n system that, within 60 seconds of a lead arriving:

- replies on **WhatsApp in the lead's own language** (Arabic, English, or French),
- **qualifies through conversation** — budget, currency, timeline, area, buyer/seller intent,
- **scores and tiers** the lead (hot / warm / cold),
- creates a **HubSpot contact + deal**, and
- hands the agent a **scored, ready-to-call lead in Slack** — with zero data entry.

It runs unattended, respects the region's rhythms, and is hardened against every failure mode I could think of.

---

## How it works (the 60-second journey)

1. **Intake.** A lead POSTs in from any source. The intake workflow validates it, deduplicates it (so a double-submit or a webhook retry never creates two leads), detects the language, and scores intent with a fast, cheap model — all before sending anything.
2. **The right moment.** Before it messages, the system checks the lead's country: is it the weekend here? Is it quiet hours? Is a prayer time within 15 minutes? If so, the send is delayed to the next appropriate moment. Otherwise it goes immediately.
3. **First touch.** A personalized WhatsApp acknowledgment arrives — greeting the lead by name, referencing what they asked about, and asking one qualifying question. It opens a conversation; it doesn't dump a form.
4. **Qualification.** As the lead replies, the system extracts budget, timeline, and area — and **never assumes currency** (in this market "two million" could be dirhams, riyals, or dollars). It caps itself at six messages, then escalates to a human.
5. **Handoff.** The lead is scored 0–100, a HubSpot contact and deal are created, and a rich card lands in the agents' Slack channel: score, tier, budget, area, a two-line summary, and the recommended next action. The agent just calls.

---

## Built for MENA — the part off-the-shelf tools miss

| Feature | Why it matters here |
|---|---|
| **Arabic / English / French**, per-message | 97%+ WhatsApp penetration; the buyer writes in their language and expects a reply in it. |
| **Currency never assumed** | AED, SAR, USD, LBP, EGP… stored explicitly. Assuming USD loses or mis-prices a lead. |
| **Per-country weekends** | Gulf is Fri–Sat, Levant is Sat–Sun. A Western Mon–Fri assumption sends at the wrong times. |
| **Prayer-time-aware sending** | Messages near a prayer time are delayed. Culturally correct sending is the moat, not a feature. |
| **Arabic formality** | Informal vs formal address based on the sender's tone. |

99% of Western automation agencies build SMS-first and English-only. Arabic conversation and embedded regional context are the unfair advantage.

---

## Engineering rigor (technical highlights)

This was built to a strict 8-point production standard — the same bar I'd hold for a paying client on day one:

- **Every external call** (Anthropic, Twilio, HubSpot, Slack, Supabase — 47 nodes) has an explicit timeout, retry with backoff, and a Continue-On-Fail decision documented on the node.
- **Graceful degradation, on purpose.** If a model call or Twilio send fails, the lead is never dropped: the run is logged `partial` and continues. A daily digest surfaces those; a separate global error handler catches genuine crashes and alerts `#automation-errors`. Two channels, two severities.
- **Idempotency under load.** Dedup is a SHA-256 key with a database UNIQUE constraint. I chaos-tested it: five identical webhooks fired in parallel produce exactly one lead and one outbound message — the constraint wins the race, the losers collapse to an update.
- **Bounded by design.** A 6-turn conversation cap (enforced in code, not just the prompt), a 48-hour silence sweep, and computed send-delays — no unbounded loops.
- **Full observability.** Every execution path writes a `run_logs` row with decision metadata (language, intent, send-window and prayer decisions, scores, message IDs).
- **Cost-engineered model choice.** Haiku 4.5 for classification and language detection; Sonnet 5 only for conversation and final scoring — roughly 60% cheaper than a Sonnet-only build with no quality loss on the simple tasks.

Every milestone was tested — happy path, malformed input, duplicate triggers, and deliberate outages — before being called done.

---

## The economics (illustrative model)

> These figures are a transparent model, not measured client results. This is a self-initiated demo; no real client outcomes are represented.

**What it costs to run** (≈500 leads/month): ~$72/month in infrastructure — n8n hosting, Twilio WhatsApp messages, and Anthropic API (Supabase, HubSpot, and Slack on free tiers).

**Illustrative return (Dubai).** Average residential commission ≈ **35,000 AED (~$9,500)** per deal. A 5-agent team taking 500 leads/month that recovers even ~4 deals a month previously lost to slow response adds ≈ **$38,000/month**. Against ~$72 infra + a service retainer, that models to a return in the range of **~60×**. Riyadh is comparable; Beirut is lower in absolute terms but similar in relative return.

The point isn't the exact multiple — it's that in a high-commission market, recovering a *handful* of otherwise-lost leads dwarfs the cost of the system.

---

## Deploying this for your agency

I build this on **your** stack — your CRM (HubSpot, Bitrix24, or Zoho), your WhatsApp number, your languages. Typical shape:

- Setup: **Levant** $800–1,500 · **Gulf** $1,500–3,000
- Retainer: **Levant** $200–400/mo · **Gulf** $400–800/mo
- Live in days, not weeks — WhatsApp Business API in MENA needs no US-style A2P registration.

If you're losing leads to slow WhatsApp follow-up, [let's talk](https://husseinrmaity.github.io).

---

## Tech stack

n8n (self-hosted) · Claude Haiku 4.5 + Sonnet 5 · Twilio WhatsApp Business API · Supabase (Postgres) · HubSpot · Slack · aladhan.com.

**Author:** Hussein Rmaity — WhatsApp-first AI automation for MENA. Portfolio: [husseinrmaity.github.io](https://husseinrmaity.github.io) · Code: [github.com/HusseinRmaity/real-estate-lead-response-mena](https://github.com/HusseinRmaity/real-estate-lead-response-mena).
