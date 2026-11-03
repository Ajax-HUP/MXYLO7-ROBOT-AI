-- TREVO SCALPER FX licence service (Supabase)
-- Run in Supabase SQL Editor before deploying the updated Worker.
create extension if not exists pgcrypto;

create table if not exists public.trevo_licenses (
  id uuid primary key default gen_random_uuid(),
  key_hash text not null unique,
  status text not null default 'active' check (status in ('active','suspended','revoked')),
  expires_at timestamptz,
  max_accounts integer not null default 1 check (max_accounts between 1 and 10),
  created_at timestamptz not null default now(),
  notes text
);

create table if not exists public.trevo_license_activations (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.trevo_licenses(id) on delete cascade,
  mt5_login text not null,
  broker_server text not null,
  activated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (license_id, mt5_login, broker_server)
);

alter table public.trevo_licenses enable row level security;
alter table public.trevo_license_activations enable row level security;
-- No anon/authenticated policies. Only Worker service-role access.
