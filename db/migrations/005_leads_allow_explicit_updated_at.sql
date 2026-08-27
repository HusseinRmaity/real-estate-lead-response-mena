-- 005_leads_allow_explicit_updated_at.sql
-- Applied: 2026-08-21
--
-- Case Study 1 — let a caller set `leads.updated_at` explicitly, and fix a regression from 004.
--
-- THE REGRESSION
-- Before 004, the shared `touch_updated_at()` bumped updated_at on EVERY update statement, even
-- one whose values were identical to the existing row. 004 changed that to "bump only on a
-- substantive change", which silently broke a real case: a lead who replies with something
-- unextractable ("hmm", "ok", a voice note) produces a lead patch of {status:'qualifying',
-- language:'en'} that is byte-identical to the current row. No bump => the 48h silence clock
-- keeps running => a lead who IS replying gets nudged and auto-closed for not replying.
--
-- THE FIX
-- Honour an explicitly supplied updated_at. `02`'s Parse And Cap now always sends one, so every
-- inbound turn resets the clock regardless of whether any field actually changed, while
-- bookkeeping-only writes (nudged_at) still leave it alone.
--
-- Precedence, highest first:
--   1. caller passed an updated_at different from the stored one  -> use it verbatim
--   2. some non-bookkeeping column changed                        -> now()
--   3. otherwise (bookkeeping-only, or a true no-op)              -> leave it alone
--
-- Verified after applying (2026-08-21), all four cases on a throwaway row:
--   nudged_at only            -> clock held
--   no-op patch               -> clock held
--   explicit updated_at       -> honoured verbatim
--   substantive change        -> set to now()

create or replace function public.leads_touch_updated_at()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if new.updated_at is distinct from old.updated_at then
    -- Caller set it deliberately (e.g. 02 marking lead activity). Respect it.
    return new;
  end if;

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
  'leads-only variant of touch_updated_at(). Precedence: an explicitly supplied updated_at wins; else a substantive column change sets now(); else the value is left alone so bookkeeping writes (nudged_at) do not reset 02b''s 48h silence clock.';
