-- sql/migrations/001_init.sql
-- Minimal "random tables" schema + NOTIFY triggers to exercise the Go listener.
-- NOTE: This file uses a hard-coded channel name: 'events'
-- If you change your app's PG_CHANNEL, update the pg_notify() calls accordingly.

BEGIN;

-- Needed for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- A few arbitrary tables
CREATE TABLE IF NOT EXISTS users (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       text UNIQUE NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS posts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       text NOT NULL,
  body        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS comments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  body        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Notification helper: emit a JSON payload in the shape your Go code expects.
CREATE OR REPLACE FUNCTION notify_event(ev_type text, ev_id text, ev_data jsonb DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_notify(
    'events',
    jsonb_build_object(
      'type', ev_type,
      'id', ev_id,
      'data', ev_data
    )::text
  );
END;
$$;

-- Triggers for inserts
CREATE OR REPLACE FUNCTION users_notify_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM notify_event('user.created', NEW.id::text, to_jsonb(NEW));
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION posts_notify_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM notify_event('post.created', NEW.id::text, to_jsonb(NEW));
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION comments_notify_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM notify_event('comment.created', NEW.id::text, to_jsonb(NEW));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_notify_insert ON users;
CREATE TRIGGER trg_users_notify_insert
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION users_notify_insert();

DROP TRIGGER IF EXISTS trg_posts_notify_insert ON posts;
CREATE TRIGGER trg_posts_notify_insert
AFTER INSERT ON posts
FOR EACH ROW
EXECUTE FUNCTION posts_notify_insert();

DROP TRIGGER IF EXISTS trg_comments_notify_insert ON comments;
CREATE TRIGGER trg_comments_notify_insert
AFTER INSERT ON comments
FOR EACH ROW
EXECUTE FUNCTION comments_notify_insert();

COMMIT;


