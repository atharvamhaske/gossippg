-- sql/test/001_seed.sql
-- Insert some rows to trigger NOTIFY events (via triggers from 001_init.sql).

BEGIN;

INSERT INTO users (email) VALUES
  ('alice@example.com'),
  ('bob@example.com')
ON CONFLICT (email) DO NOTHING;

-- Create a couple of posts for Alice
WITH u AS (
  SELECT id FROM users WHERE email = 'alice@example.com' LIMIT 1
)
INSERT INTO posts (user_id, title, body)
SELECT u.id, 'Hello World', 'First post body'
FROM u;

WITH u AS (
  SELECT id FROM users WHERE email = 'alice@example.com' LIMIT 1
)
INSERT INTO posts (user_id, title, body)
SELECT u.id, 'Another Post', 'Second post body'
FROM u;

-- Comment on the newest post
WITH p AS (
  SELECT id FROM posts ORDER BY created_at DESC LIMIT 1
)
INSERT INTO comments (post_id, body)
SELECT p.id, 'Nice post!'
FROM p;

COMMIT;


