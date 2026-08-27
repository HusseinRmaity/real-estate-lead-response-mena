-- 004_leads_touch_updated_at_ignores_nudged_at.sql
-- Applied: 2026-08-21
--
-- Case Study 1 — make `leads.updated_at` mean "last substantive change".
--
-- WHY THIS EXISTS
-- `02b - Close Stale Conversations` measures 48h of silence with `leads.updated_at`, and the
-- shared `touch_updated_at()` trigger bumps that column on EVERY update. So the new
-- "mark this lead as nudged" write would have pushed updated_at forward by 24h and quietly
-- moved the auto-close from 48h to 72h — the documented rule would have been wrong with no
-- error anywhere.
--
-- The shared function is used by appointments, carts, clinics, leads and waitlist (all three
-- case studies), so it is NOT touched. Only the `leads` trigger is swapped for a variant that
-- ignores bookkeeping-only writes.
--
-- Verified after applying (2026-08-21):
--   update leads set nudged_at = now()      -> updated_at UNCHANGED  (09:03:02.112313)
--   update leads set status = 'qualifying'  -> updated_at MOVED      (10:07:55.488266)

create or replace function public.leads_touch_updated_at()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  -- Compare the rows with the bookkeeping columns removed. If nothing else changed, this is a
  -- bookkeeping-only write and the silence clock must keep running.
  if (to_jsonb(new) - 'updated_at' - 'nudged_at')
     is distinct from
     (to_jsonb(old) - 'updated_at' - 'nudged_at')
  then
    new.updated_at = now();
  else
    new.updated_at = old.updated_at;
  end if;
  return new;
end;
$function$;

comment on function public.leads_touch_updated_at() is
  'leads-only variant of touch_updated_at(). Keeps updated_at as "last substantive change" so 02b''s 48h silence sweep is not reset by bookkeeping writes such as nudged_at. Do not point other tables at this.';

drop trigger if exists trg_leads_touch_updated_at on public.leads;

create trigger trg_leads_touch_updated_at
  before update on public.leads
  for each row
  execute function public.leads_touch_updated_at();
