-- 007 — Scope the Case 1 daily digest to Case 1's own workflows.
--
-- WHY: run_logs is shared by every case study running on this Supabase project.
-- case1_daily_digest (from 002) filtered `leads` correctly but read run_logs with
-- no workflow filter at all, so runs_total / runs_partial / runs_failed / errors
-- reported EVERY project's activity. Verified live 2026-08-28: with zero Case 1
-- leads in the window the digest still reported runs_total=28, runs_failed=11 and
-- listed 10 errors, all of them from the dental clinic build. A client would read
-- another client's failures in their morning Slack digest.
--
-- Two name shapes have to match, which is why this is not a single IN list:
--   * in-workflow logging writes the BARE name        -> '01 - Lead Intake'
--   * `99 - Error Handler` writes the failing workflow's n8n display name via
--     wf.name, which carries the instance prefix      -> '[CS1 Real Estate] 01 - Lead Intake'
-- The bare names are enumerated (they collide across cases otherwise — Case 3 also
-- has a bare '04 - No-Show Sweep' style), while the prefixed crash rows are matched
-- by prefix so a future Case 1 workflow is picked up without another migration.
-- '[' is not a LIKE metacharacter in Postgres, so no escaping is needed.
--
-- Everything else about the function is unchanged: same signature, same JSON shape,
-- STABLE, empty search_path with fully-qualified table names.

create or replace function public.case1_daily_digest(
  p_start timestamptz,
  p_end   timestamptz
)
returns json
language sql
stable
set search_path to ''
as $function$
  with case1_runs as (
    select *
    from public.run_logs
    where created_at >= p_start
      and created_at <  p_end
      and (
        workflow_name in (
          '00 - Health Check',
          '01 - Lead Intake',
          '02 - WhatsApp Reply Handler',
          '02b - Close Stale Conversations',
          '03 - Daily Digest'
        )
        or workflow_name like '[CS1 Real Estate]%'
      )
  )
  select json_build_object(
    'window_start', p_start,
    'window_end',   p_end,
    'leads_received', (
      select count(*) from public.leads
      where created_at >= p_start and created_at < p_end
    ),
    'by_intent', (
      select coalesce(json_object_agg(intent_classification, c), '{}'::json)
      from (
        select intent_classification, count(*) c
        from public.leads
        where created_at >= p_start and created_at < p_end
          and intent_classification is not null
        group by intent_classification
      ) t
    ),
    'qualifying', (
      select count(*) from public.leads
      where created_at >= p_start and created_at < p_end and status = 'qualifying'
    ),
    'handed_off', (
      select count(*) from public.leads
      where created_at >= p_start and created_at < p_end and status = 'handed_off'
    ),
    'dead', (
      select count(*) from public.leads
      where created_at >= p_start and created_at < p_end and status = 'dead'
    ),
    'by_tier', (
      select coalesce(json_object_agg(qualification_tier, c), '{}'::json)
      from (
        select qualification_tier, count(*) c
        from public.leads
        where created_at >= p_start and created_at < p_end
          and qualification_tier is not null
        group by qualification_tier
      ) t
    ),
    'runs_total',   (select count(*) from case1_runs),
    'runs_partial', (select count(*) from case1_runs where status = 'partial'),
    'runs_failed',  (select count(*) from case1_runs where status = 'failed'),
    'errors', (
      select coalesce(json_agg(e), '[]'::json)
      from (
        select workflow_name as workflow, step_name as step,
               error_message as error, created_at as at
        from case1_runs
        where status = 'failed'
        order by created_at desc
        limit 10
      ) e
    )
  );
$function$;
