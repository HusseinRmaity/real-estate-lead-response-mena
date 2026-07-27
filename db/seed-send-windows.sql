-- ============================================================================
-- Case Study 1 — send_windows seed data
-- Primary MENA markets. Run AFTER schema.sql. Idempotent (upsert on conflict).
--
-- weekend_days: JS/ISO day numbers  0=Sun 1=Mon 2=Tue 3=Wed 4=Thu 5=Fri 6=Sat
--   Gulf + Egypt  -> Fri+Sat = {5,6}
--   Levant + Maghreb -> Sat+Sun = {6,0}
-- quiet hours: 22:00–08:00 local (spec §7 default)
-- respect_prayer_times: true for Muslim-majority markets; Lebanon left false
--   (religiously mixed — do not assume). See docs/decisions.md.
-- ============================================================================

insert into public.send_windows
  (country_code, timezone, weekend_days, quiet_hours_start, quiet_hours_end, respect_prayer_times)
values
  ('AE', 'Asia/Dubai',       '{5,6}', '22:00', '08:00', true),   -- UAE
  ('SA', 'Asia/Riyadh',      '{5,6}', '22:00', '08:00', true),   -- Saudi Arabia
  ('QA', 'Asia/Qatar',       '{5,6}', '22:00', '08:00', true),   -- Qatar
  ('KW', 'Asia/Kuwait',      '{5,6}', '22:00', '08:00', true),   -- Kuwait
  ('BH', 'Asia/Bahrain',     '{5,6}', '22:00', '08:00', true),   -- Bahrain
  ('OM', 'Asia/Muscat',      '{5,6}', '22:00', '08:00', true),   -- Oman
  ('EG', 'Africa/Cairo',     '{5,6}', '22:00', '08:00', true),   -- Egypt
  ('JO', 'Asia/Amman',       '{6,0}', '22:00', '08:00', true),   -- Jordan
  ('LB', 'Asia/Beirut',      '{6,0}', '22:00', '08:00', false),  -- Lebanon (mixed)
  ('MA', 'Africa/Casablanca','{6,0}', '22:00', '08:00', true)    -- Morocco
on conflict (country_code) do update set
  timezone             = excluded.timezone,
  weekend_days         = excluded.weekend_days,
  quiet_hours_start    = excluded.quiet_hours_start,
  quiet_hours_end      = excluded.quiet_hours_end,
  respect_prayer_times = excluded.respect_prayer_times;
