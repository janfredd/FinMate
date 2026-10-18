-- FinMate Supabase (PostgreSQL) schema. Run in Supabase SQL editor.
-- Enables uuid generation
create extension if not exists "pgcrypto";

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  password_hash text not null,
  name text,
  created_at timestamptz default now()
);

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  name text not null,
  is_default boolean default false
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  type text not null check (type in ('income','expense')),
  amount numeric(14,2) not null check (amount > 0),
  category_id uuid references categories(id) on delete set null,
  date date not null,
  merchant text,
  note text,
  source text default 'Manual',
  created_at timestamptz default now()
);
create index if not exists idx_txn_user_date on transactions(user_id, date desc);

create table if not exists budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  category_id uuid not null references categories(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  period text default 'monthly' check (period in ('monthly','weekly')),
  start_date date not null,
  end_date date not null
);

create table if not exists oauth_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references users(id) on delete cascade,
  access_token text not null,
  refresh_token text not null,
  expiry timestamptz
);

create table if not exists insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  type text not null,
  message text not null,
  created_at timestamptz default now(),
  is_read boolean default false
);
create index if not exists idx_insights_user on insights(user_id, created_at desc);

-- Default categories (global)
insert into categories (name, is_default) values
 ('Food', true), ('Transportation', true), ('Shopping', true),
 ('Entertainment', true), ('Bills', true), ('Health', true),
 ('Education', true), ('Others', true)
on conflict do nothing;

-- Row Level Security: isolate by user_id (enable + policies when using Supabase Auth JWTs)
-- alter table transactions enable row level security;
-- create policy "own txns" on transactions for all using (auth.uid() = user_id);
-- (repeat for budgets, oauth_tokens, insights; categories: is_default OR user_id = auth.uid())
