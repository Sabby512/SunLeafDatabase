-- Optional upgrade: remember which logged-in account made each donation pledge.
-- Run this while connected to the clean_energy database.
-- Safe to run repeatedly.
ALTER TABLE pledges ADD COLUMN IF NOT EXISTS account_email VARCHAR(190);
