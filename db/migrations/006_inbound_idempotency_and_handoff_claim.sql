-- 006_inbound_idempotency_and_handoff_claim.sql
-- Applied: 2026-08-21
--
-- Case Study 1 — close two duplication defects found by the adversarial suite (2026-08-21).
--
-- DEFECT 1: no inbound idempotency. Twilio retries a webhook on timeout, and the reply handler
-- happily processed the same MessageSid twice: two inbound rows, two model calls, two WhatsApp
-- replies, and TWO HubSpot contacts + TWO deals for one lead.
--
-- DEFECT 2: two messages sent seconds apart (normal WhatsApp behaviour) raced each other. Both
-- executions read the lead before either wrote, so both ran the whole CRM branch — again two
-- contacts and two deals.
--
-- Fix 1 is a partial unique index: a duplicate inbound SID can no longer be stored at all, and
-- PostgREST's resolution=ignore-duplicates turns the second attempt into an empty response the
-- workflow can branch on.
--
-- Fix 2 is an atomic claim: exactly one execution can win the right to run the CRM branch for a
-- given lead, decided by the database rather than by timing.
--
-- Verified after applying (2026-08-21): claim won by first caller / lost by second; duplicate
-- inbound SID rejected by the index; outbound rows unconstrained (the index is partial).
-- Verified live end-to-end: a repeated MessageSid produced 1 inbound row, 1 reply, 1 contact,
-- 1 deal + an `inbound_duplicate_ignored` log; two concurrent handoff-triggering messages
-- produced `handoff_already_claimed` + `handoff_complete` with 1 contact and 1 deal.

-- ---------------------------------------------------------------- fix 1: inbound idempotency

-- Any pre-existing duplicates must go before the index can be built. Keeps the earliest row.
delete from public.conversations c
using public.conversations keep
where c.direction = 'inbound'
  and keep.direction = 'inbound'
  and c.twilio_message_id is not null
  and c.twilio_message_id = keep.twilio_message_id
  and c.created_at > keep.created_at;

create unique index if not exists conversations_inbound_sid_uniq
  on public.conversations (twilio_message_id)
  where direction = 'inbound' and twilio_message_id is not null;

comment on index public.conversations_inbound_sid_uniq is
  'Inbound idempotency. A Twilio webhook retry carries the same MessageSid; this makes storing it twice impossible. 02 posts with Prefer: resolution=ignore-duplicates and treats an empty response as "already handled, stop".';

-- ---------------------------------------------------------------- fix 2: atomic handoff claim

alter table public.leads
  add column if not exists handoff_claimed_at timestamptz;

comment on column public.leads.handoff_claimed_at is
  'Set by case1_claim_handoff(). Exactly one execution can claim a lead''s CRM handoff; concurrent runs lose the claim and exit before touching HubSpot or Slack.';

create or replace function public.case1_claim_handoff(p_lead_id uuid)
returns boolean
language plpgsql
security invoker
set search_path to ''
as $function$
declare
  v_won boolean;
begin
  -- A single atomic statement. The row lock Postgres takes here is what serialises two
  -- concurrent executions: the loser's UPDATE matches zero rows once the winner commits.
  update public.leads
     set handoff_claimed_at = now()
   where id = p_lead_id
     and handoff_claimed_at is null;

  get diagnostics v_won = row_count;
  return v_won;
end;
$function$;

comment on function public.case1_claim_handoff(uuid) is
  'Returns true to exactly one caller per lead. 02 calls this before the scoring/CRM/Slack branch so a duplicate or concurrent inbound cannot create a second HubSpot contact and deal.';
