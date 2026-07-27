-- ============================================================================
-- Case Study 1 — Real Estate Lead Response (MENA) — Core schema
-- Spec: case-study-1-mena-spec.md §4 (Data Model), §7 (currency split)
-- Run this in the Supabase SQL editor. Idempotent: safe to re-run.
-- ============================================================================

-- gen_random_uuid() lives in pgcrypto; present by default on Supabase.
create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- leads — one row per unique lead per source per 72-hour window
-- Carries the FULL column set now (intake + later conversation/scoring fields)
-- so no migration is needed in Milestones 4/5.
-- ----------------------------------------------------------------------------
create table if not exists public.leads (
  id                    uuid primary key default gen_random_uuid(),

  -- provenance
  source                text not null,                     -- e.g. property_finder, meta_lead_ads, website_form
  source_id             text,                              -- external id if the source provides one

  -- identity
  first_name            text,
  last_name             text,
  phone                 text,                              -- as received
  email                 text,
  whatsapp_number       text,                              -- normalized E.164, set in M3

  -- interest / qualification (budget split per spec §7 — never a single free-text range)
  property_interest     text,
  budget_min            numeric,
  budget_max            numeric,
  currency              text,                              -- AED, SAR, USD, LBP, EGP, QAR, KWD, MAD, TND, DZD ...
  timeline              text,
  buyer_or_seller       text check (buyer_or_seller in ('buyer','seller')),
  area_of_interest      text,

  -- locale
  language              text check (language in ('ar','en','fr','mixed')),
  country_code          text,                              -- ISO 3166 alpha-2
  timezone              text,                              -- IANA identifier, set in M3

  -- AI classification / scoring
  intent_classification text check (intent_classification in ('high','medium','low','junk')),
  qualification_score   int  check (qualification_score between 0 and 100),
  qualification_tier    text check (qualification_tier in ('hot','warm','cold')),
  qualification_summary text,                              -- English, for the agent

  -- CRM linkage (populated at handoff, M5)
  hubspot_contact_id    text,
  hubspot_deal_id       text,

  -- lifecycle
  status                text not null default 'new'
                          check (status in ('new','qualifying','qualified','handed_off','dead')),

  -- dedup: SHA256(normalized phone + email + source). UNIQUE enforces idempotency.
  dedup_key             text not null unique,

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index if not exists idx_leads_phone        on public.leads (phone);
create index if not exists idx_leads_email         on public.leads (email);
create index if not exists idx_leads_status        on public.leads (status);
create index if not exists idx_leads_country_code  on public.leads (country_code);
create index if not exists idx_leads_created_at    on public.leads (created_at);
-- dedup_key already has a unique index from the UNIQUE constraint.

-- ----------------------------------------------------------------------------
-- conversations — every message sent or received, one row each
-- ----------------------------------------------------------------------------
create table if not exists public.conversations (
  id                uuid primary key default gen_random_uuid(),
  lead_id           uuid not null references public.leads(id) on delete cascade,
  direction         text not null check (direction in ('inbound','outbound')),
  channel           text not null default 'whatsapp',
  message           text not null,
  twilio_message_id text,
  turn_number       int  not null default 1,               -- 1-indexed within a lead's conversation
  created_at        timestamptz not null default now()
);

create index if not exists idx_conversations_lead_id   on public.conversations (lead_id);
create index if not exists idx_conversations_twilio_id  on public.conversations (twilio_message_id);

-- ----------------------------------------------------------------------------
-- run_logs — every workflow step logged for observability
-- ----------------------------------------------------------------------------
create table if not exists public.run_logs (
  id            uuid primary key default gen_random_uuid(),
  workflow_name text not null,
  execution_id  text,
  lead_id       uuid references public.leads(id) on delete set null,   -- nullable: some runs have no lead
  status        text not null check (status in ('success','partial','failed')),
  step_name     text,
  error_message text,
  duration_ms   int,
  metadata      jsonb,
  created_at    timestamptz not null default now()
);

create index if not exists idx_run_logs_workflow_created on public.run_logs (workflow_name, created_at);
create index if not exists idx_run_logs_status           on public.run_logs (status);

-- ----------------------------------------------------------------------------
-- send_windows — per-country send-time configuration (seeded once, see seed file)
-- weekend_days uses ISO/JS day numbers: 0=Sun, 1=Mon, ... 5=Fri, 6=Sat
-- ----------------------------------------------------------------------------
create table if not exists public.send_windows (
  country_code         text primary key,       -- ISO 3166 alpha-2
  timezone             text not null,           -- IANA identifier
  weekend_days         int[] not null,          -- e.g. {5,6} = Fri+Sat, {6,0} = Sat+Sun
  quiet_hours_start    time not null default '22:00',
  quiet_hours_end      time not null default '08:00',
  respect_prayer_times boolean not null default true
);

-- ----------------------------------------------------------------------------
-- updated_at auto-touch trigger on leads
-- ----------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''   -- hardening: immutable search_path (Supabase linter 0011)
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_leads_touch_updated_at on public.leads;
create trigger trg_leads_touch_updated_at
  before update on public.leads
  for each row
  execute function public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- Row Level Security
-- Enable RLS with NO policies on every table. n8n connects with the
-- service_role key, which bypasses RLS entirely. A leaked anon/public key
-- therefore cannot read or write lead data. This is the secure default for an
-- internal, service-only pipeline. (See docs/decisions.md.)
-- ----------------------------------------------------------------------------
alter table public.leads         enable row level security;
alter table public.conversations enable row level security;
alter table public.run_logs      enable row level security;
alter table public.send_windows  enable row level security;
