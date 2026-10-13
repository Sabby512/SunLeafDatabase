-- ============================================================================
--  Clean Energy Campaign  -  PostgreSQL / Supabase schema
--  Converted from the MySQL/MariaDB version (clean_energy.sql + upgrade_pledge_account.sql)
--
--  HOW TO IMPORT (Supabase):
--    1. Open your project -> SQL Editor -> New query
--    2. Paste this whole file -> click "Run"
--  Safe to run again: existing tables and data are left untouched.
--  (No CREATE DATABASE: Supabase already gives you a database called `postgres`.)
-- ============================================================================

-- Case-insensitive text, so emails behave like MySQL's utf8mb4_unicode_ci
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;

-- ---------------------------------------------------------------- accounts --
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          VARCHAR(100)  NOT NULL,
  email         extensions.citext NOT NULL UNIQUE,
  password_hash VARCHAR(255)  NOT NULL,              -- bcrypt hash, never the real password
  role          VARCHAR(10)   NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  last_login    TIMESTAMPTZ   NULL,
  login_count   INTEGER       NOT NULL DEFAULT 0 CHECK (login_count >= 0)
);

-- Login sessions live in the database so they can't be read over HTTP.
CREATE TABLE IF NOT EXISTS sessions (
  id         VARCHAR(128) PRIMARY KEY,
  data       TEXT         NOT NULL,
  life       INTEGER      NOT NULL DEFAULT 28800,     -- seconds a session survives without use
  expires_at TIMESTAMPTZ  NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions (expires_at);

-- 6-digit "forgot password" codes (stored hashed, expire after 10 minutes)
CREATE TABLE IF NOT EXISTS password_resets (
  user_id    INTEGER      PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  code_hash  VARCHAR(255) NOT NULL,
  expires_at TIMESTAMPTZ  NOT NULL,
  tries      SMALLINT     NOT NULL DEFAULT 0 CHECK (tries >= 0)
);

-- ------------------------------------------------ user <-> admin inbox / chat --
CREATE TABLE IF NOT EXISTS messages (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    INTEGER      NOT NULL REFERENCES users (id) ON DELETE CASCADE,  -- conversation owner
  sender     VARCHAR(10)  NOT NULL CHECK (sender IN ('user','admin')),
  body       VARCHAR(1000) NOT NULL,
  is_read    BOOLEAN      NOT NULL DEFAULT FALSE,     -- user message read by an admin?
  seen       BOOLEAN      NOT NULL DEFAULT FALSE,     -- admin reply seen by the user?
  created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_messages_user ON messages (user_id, created_at);

-- -------------------------------------------------------- website form data --
CREATE TABLE IF NOT EXISTS petition_signatures (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  email      extensions.citext NOT NULL UNIQUE,       -- one signature per email
  anonymous  BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pledges (                  -- pledges only: no payment details are ever stored
  id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  method        VARCHAR(30)   NOT NULL,
  wallet        VARCHAR(40)   NOT NULL DEFAULT '',
  amount        NUMERIC(12,2) NOT NULL,
  name          VARCHAR(100)  NOT NULL DEFAULT '',
  anonymous     BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  account_email VARCHAR(190)  NULL                    -- logged-in account that made the pledge
);
-- (in case the table already existed without the column)
ALTER TABLE pledges ADD COLUMN IF NOT EXISTS account_email VARCHAR(190) NULL;

CREATE TABLE IF NOT EXISTS fundraiser_ideas (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100)  NOT NULL,
  email      VARCHAR(190)  NOT NULL,
  kind       VARCHAR(40)   NOT NULL DEFAULT '',
  idea       VARCHAR(2000) NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS volunteers (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            VARCHAR(100)  NOT NULL,
  email           VARCHAR(190)  NOT NULL,
  role            VARCHAR(60)   NOT NULL DEFAULT '',
  organization    VARCHAR(120)  NOT NULL DEFAULT '',
  activities      VARCHAR(600)  NOT NULL DEFAULT '',   -- comma separated
  time_commitment VARCHAR(60)   NOT NULL DEFAULT '',
  message         VARCHAR(2000) NOT NULL DEFAULT '',
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS role_interest (             -- "Work for Us" job interest
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100)  NOT NULL,
  email      VARCHAR(190)  NOT NULL,
  role       VARCHAR(80)   NOT NULL,
  message    VARCHAR(2000) NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS contact_messages (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100)  NOT NULL,
  email      VARCHAR(190)  NOT NULL,
  topic      VARCHAR(60)   NOT NULL DEFAULT '',
  message    VARCHAR(3000) NOT NULL,
  created_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_applications (
  id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization   VARCHAR(150)  NOT NULL,
  partner_type   VARCHAR(60)   NOT NULL,
  contact_person VARCHAR(100)  NOT NULL,
  position       VARCHAR(100)  NOT NULL DEFAULT '',
  email          VARCHAR(190)  NOT NULL,
  phone          VARCHAR(40)   NOT NULL DEFAULT '',
  city           VARCHAR(100)  NOT NULL,
  ways           VARCHAR(400)  NOT NULL DEFAULT '',    -- comma separated
  message        VARCHAR(3000) NOT NULL,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS supporters (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  email      extensions.citext NOT NULL UNIQUE,
  role       VARCHAR(60)  NOT NULL DEFAULT '',
  level      VARCHAR(20)  NOT NULL DEFAULT 'Supporter',
  created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------- abuse protection --
-- counts recent attempts (logins, forms, AI questions) so one visitor can't flood the site
CREATE TABLE IF NOT EXISTS rate_limits (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bucket     VARCHAR(30)  NOT NULL,
  ident      VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rate ON rate_limits (bucket, ident, created_at);

-- ------------------------------------------------------------------ security --
-- Supabase exposes every table in the `public` schema through its public REST API.
-- Turning on Row Level Security with NO policies blocks that API completely
-- (so nobody can read password hashes or sessions with your public anon key).
-- Your server code on Vercel should connect with the database connection string
-- (or the service_role key), which bypasses RLS and keeps working normally.
ALTER TABLE users                ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions             ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_resets      ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages             ENABLE ROW LEVEL SECURITY;
ALTER TABLE petition_signatures  ENABLE ROW LEVEL SECURITY;
ALTER TABLE pledges              ENABLE ROW LEVEL SECURITY;
ALTER TABLE fundraiser_ideas     ENABLE ROW LEVEL SECURITY;
ALTER TABLE volunteers           ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_interest        ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_messages     ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE supporters           ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limits          ENABLE ROW LEVEL SECURITY;
