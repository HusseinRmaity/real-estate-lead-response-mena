# Demo script — English demo

**Target length:** 2:30–3:30
**Audience:** MENA real estate agency owners / ops managers, and English-speaking agencies scouting a WhatsApp automation partner.
**Goal:** Prove — visibly, on a real phone — that a lead gets a bilingual WhatsApp reply in under 60 seconds, gets qualified through conversation, and lands in the CRM + Slack as a scored, ready-to-call lead.

**Before you hit record (setup checklist):**
- [ ] Tunnel running (`cloudflared`), `WEBHOOK_BASE` in `web/lead-form.html` points at it, `WEBHOOK_TOKEN` filled.
- [ ] Twilio sandbox inbound webhook wired to `<tunnel>/webhook/whatsapp-inbound-router`; your phone joined the sandbox. (On a standalone install of just this project, point at `<tunnel>/webhook/whatsapp-inbound` instead — the router only exists because one shared Twilio sandbox fronts three separate systems here.)
- [ ] Test data pruned (run the prune SQL from `docs/testing-log.md` / the M7 handoff).
- [ ] Windows/tabs open and arranged: (1) the lead form, (2) n8n `01 - Lead Intake` canvas, (3) Supabase `leads` table, (4) HubSpot contacts, (5) Slack `#leads`. Phone screen mirrored or held in frame.
- [ ] Send-window note: if you're recording during quiet hours (22:00–08:00 local) the ack is delayed by design — record during working hours so it fires immediately, or use a Gulf number during Gulf daytime.

---

## Shot list & voiceover

### 0:00–0:20 — The hook (face or form on screen)
> "A real estate lead in Dubai or Riyadh expects a WhatsApp reply in minutes — not an email, not a call back tomorrow. Miss that window and the lead is gone. Here's a system that answers in under a minute, in the lead's own language, at any hour. Let me show you it working — on my actual phone."

*Show the lead form (`web/lead-form.html`). Let the "typical first reply · under 60s" clock be visible.*

### 0:20–0:45 — Submit a lead
> "This is a standard website inquiry — but it works exactly the same from Property Finder, Bayut, or a Meta lead ad. I'll come in as a cash buyer looking in Dubai Marina."

*Fill: name, your WhatsApp number, Buy, "2-bed, Dubai Marina", a short message. Click **Send inquiry**. Success state appears: "Keep an eye on WhatsApp."*

### 0:45–1:05 — The system fires (n8n)
> "Behind that one click, the intake workflow validates the lead, dedupes it, detects the language, scores intent with a small fast model, and stores it — all before it sends a thing."

*Cut to n8n `01 - Lead Intake` execution: show the green path lighting up. Point at Validate → Dedupe → Detect Language → Classify Intent → Insert.*

### 1:05–1:35 — The phone buzzes (the money shot)
> "And here's the part that closes deals — my phone."

*Hold the phone up / show the mirror. The Arabic-or-English WhatsApp acknowledgment has arrived. Read the timestamp against the submit.*
> "Under a minute. It greeted me, referenced Dubai Marina specifically, and asked one qualifying question — it doesn't dump a form on the buyer, it has a conversation."

### 1:35–2:10 — Qualifying conversation
> "So I reply like a real buyer would."

*Reply on the phone: budget + currency + timeline (e.g. "around 2 million AED, cash, want to view this week"). The bot replies again, in your language.*
> "It's pulling out budget, timeline, and buyer intent as we talk — and it never assumes currency, which matters when 'two million' could be dirhams, riyals, or dollars. It caps itself at six messages, then hands me to a human."

### 2:10–2:40 — CRM + Slack handoff
> "Once it has enough, the lead is scored and handed off."

*Cut to Slack `#leads`: the rich lead card — score, tier, budget, area, summary, next best action, HubSpot links. Then HubSpot: the contact + deal with the qualification fields filled in.*
> "The agent opens Slack to a scored lead — hot, 2 million AED, wants to view this week — with a HubSpot contact and deal already created. No data entry. They just call."

### 2:40–3:15 — Why it's different + ROI
> "This is built for this market, not bolted on. Arabic, English, and French. Gulf versus Levant weekends. Prayer-time-aware sending. And full production hardening — retries, a global error handler, a daily digest — so it runs unattended."
>
> "For a Dubai team doing 500 leads a month, recovering even a handful of leads that used to die from slow response pays for the system many times over. The maths is in the write-up."

### 3:15–3:30 — CTA
> "If you're running an agency in the Gulf or the Levant and losing leads to slow WhatsApp follow-up, I build this for your stack — your CRM, your number, your language. Link's in the description. Let's talk."

---

## Notes
- Keep the phone in frame for the reveal — the physical buzz is the emotional peak; don't cut away from it.
- If Twilio is rate-limited mid-take, the ack still logs to `conversations`; but for the demo, re-shoot once the send goes through — the phone reveal is the whole point.
- Don't over-explain the architecture. One sentence per stage. The phone and Slack do the selling.
- No invented metrics on screen. The ROI figure is an illustrative model (see the case study), say so if asked.
