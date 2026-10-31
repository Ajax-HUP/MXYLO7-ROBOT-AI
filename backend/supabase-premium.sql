-- Run in the Supabase SQL editor.
-- Only trusted administrators should be allowed to manage this table.
create table if not exists public.premium_memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.premium_memberships enable row level security;

-- No browser/user policies are intentionally created.
-- The server-side Worker checks membership using the service-role key.
-- Never place the service-role key in the website or GitHub repository.
