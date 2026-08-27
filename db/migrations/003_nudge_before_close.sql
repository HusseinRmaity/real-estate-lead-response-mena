-- 003_nudge_before_close.sql
-- Applied: 2026-08-21
--
-- Case Study 1 — nudge before the 48h auto-close (02b).
--
-- Until now `02b - Close Stale Conversations` moved a silent `qualifying` lead straight to
-- `dead` after 48h with no message at all: the lead's last experience was the conversation
-- simply stopping. This column lets the sweep send ONE follow-up nudge at 24h and still
-- close at 48h, without re-nudging the same lead every hour in between.
--
-- Nullable and additive: ADD COLUMN with no default is a catalog-only change in PG11+, so
-- this does not rewrite the table and does not block the live workflows.

alter table public.leads
  add column if not exists nudged_at timestamptz;

comment on column public.leads.nudged_at is
  'When 02b sent the pre-close follow-up nudge. NULL = not yet nudged. Reset to NULL by 02 whenever the lead replies, so a re-engaged lead can be nudged again in a later cycle.';

-- The sweep queries are always `status = 'qualifying'` filtered by updated_at, and
-- qualifying is a small slice of the table, so a partial index matches the predicate
-- exactly and stays far smaller than a full index on (status, updated_at).
create index if not exists idx_leads_qualifying_stale
  on public.leads (updated_at)
  where status = 'qualifying';
