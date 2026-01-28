-- sql/test/002_notify_manual.sql
-- Manual NOTIFY to test the listener without touching tables.
-- NOTE: uses channel 'events' (update if your PG_CHANNEL differs).

SELECT pg_notify(
  'events',
  jsonb_build_object(
    'type', 'test.manual',
    'id', gen_random_uuid()::text,
    'data', jsonb_build_object('hello', 'world', 'ts', now()::text)
  )::text
);


