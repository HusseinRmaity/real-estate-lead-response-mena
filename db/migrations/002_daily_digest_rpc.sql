-- ============================================================================
-- Case Study 1 — Milestone 6.4 — Daily digest aggregation RPC
-- Called by workflow "03 - Daily Digest" via PostgREST: POST /rest/v1/rpc/case1_daily_digest
-- Aggregation lives in SQL (not n8n) so the workflow makes ONE call and moves no
-- raw rows across the wire. STABLE + empty search_path (Supabase linter 0011).
-- Idempotent: safe to re-run (create or replace).
-- ============================================================================

create or replace function public.case1_daily_digest(p_start timestamptz, p_end timestamptz)
returns json
language sql
stable
set search_path = ''
as $$
  select json_build_object(
    'window_start', p_start,
    'window_end',   p_end,

    -- intake volume for the window (by created_at)
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

    -- lifecycle outcomes for leads created in the window
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

    -- qualification tiers (hot/warm/cold) for scored leads in the window
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

    -- run health for the window
    'runs_total', (
      select count(*) from public.run_logs
      where created_at >= p_start and created_at < p_end
    ),
    'runs_partial', (
      select count(*) from public.run_logs
      where created_at >= p_start and created_at < p_end and status = 'partial'
    ),
    'runs_failed', (
      select count(*) from public.run_logs
      where created_at >= p_start and created_at < p_end and status = 'failed'
    ),
    'errors', (
      select coalesce(json_agg(e), '[]'::json)
      from (
        select workflow_name as workflow, step_name as step,
               error_message as error, created_at as at
        from public.run_logs
        where created_at >= p_start and created_at < p_end and status = 'failed'
        order by created_at desc
        limit 10
      ) e
    )
  );
$$;
