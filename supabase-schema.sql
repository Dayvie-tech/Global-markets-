-- Global Marketing Agency starter schema for Supabase.
-- Run in Supabase SQL Editor, then review/test before using real customer data.
create extension if not exists pgcrypto;
create type public.gma_account_status as enum ('pending','active','suspended','rejected');
create type public.gma_review_status as enum ('pending','approved','rejected');
create type public.gma_withdrawal_status as enum ('pending','approved','paid','rejected');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default 'Advertiser', phone text not null default '', email text not null,
 role text not null default 'advertiser' check(role in ('advertiser','admin')),
 status public.gma_account_status not null default 'pending', referral_code text unique not null default upper(substr(encode(gen_random_bytes(8),'hex'),1,10)),
 referred_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 amount numeric(12,2) not null check(amount=200), method text not null default 'KCB Paybill', paybill text not null default '522522',
 account_number text not null default '1343698359', payment_reference text not null, status public.gma_review_status not null default 'pending',
 verified_by uuid references public.profiles(id), verified_at timestamptz, created_at timestamptz not null default now()
);
create table public.campaigns (
 id uuid primary key default gen_random_uuid(), title text not null, description text not null default '',
 rate_per_view numeric(12,2) not null default 50 check(rate_per_view>=0), starts_at timestamptz not null,
 expires_at timestamptz not null, media_path text, active boolean not null default true, created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(), check(expires_at>starts_at)
);
create table public.campaign_assignments (
 id uuid primary key default gen_random_uuid(), campaign_id uuid not null references public.campaigns(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, downloaded_at timestamptz,
 created_at timestamptz not null default now(), unique(campaign_id,user_id)
);
create table public.submissions (
 id uuid primary key default gen_random_uuid(), campaign_id uuid not null references public.campaigns(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, screenshot_path text not null,
 claimed_views integer not null default 0 check(claimed_views>=0), approved_views integer not null default 0 check(approved_views>=0),
 rate_per_view numeric(12,2) not null default 50 check(rate_per_view>=0), status public.gma_review_status not null default 'pending',
 reviewer_note text, reviewed_by uuid references public.profiles(id), reviewed_at timestamptz, created_at timestamptz not null default now()
);
create table public.referrals (
 id uuid primary key default gen_random_uuid(), referrer_id uuid not null references public.profiles(id) on delete cascade,
 referred_user_id uuid not null unique references public.profiles(id) on delete cascade, bonus numeric(12,2) not null default 25 check(bonus=25),
 eligible boolean not null default false, paid boolean not null default false, created_at timestamptz not null default now(), check(referrer_id<>referred_user_id)
);
create table public.withdrawals (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 amount numeric(12,2) not null check(amount>0), method text not null, destination text not null,
 status public.gma_withdrawal_status not null default 'pending', processed_by uuid references public.profiles(id),
 processed_at timestamptz, created_at timestamptz not null default now()
);

-- Create profile on Auth signup; role is always advertiser by default.
create or replace function public.gma_new_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,phone,email)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name','Advertiser'),coalesce(new.raw_user_meta_data->>'phone',''),new.email)
 on conflict(id) do nothing;
 if coalesce(new.raw_user_meta_data->>'referral_code','') <> '' then
   insert into public.referrals(referrer_id,referred_user_id,bonus)
   select p.id,new.id,25 from public.profiles p
   where upper(p.referral_code)=upper(new.raw_user_meta_data->>'referral_code') and p.id<>new.id
   on conflict(referred_user_id) do nothing;
 end if;
 return new;
end; $$;
create trigger gma_auth_user_created after insert on auth.users for each row execute procedure public.gma_new_profile();

-- Helper: current user is admin. Role should only be changed manually by trusted project owner in SQL.
create or replace function public.gma_is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin'); $$;

alter table public.profiles enable row level security;
alter table public.payments enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.referrals enable row level security;
alter table public.withdrawals enable row level security;

create policy "profile read self or admin" on public.profiles for select to authenticated using(id=auth.uid() or public.gma_is_admin());
create policy "admin update profiles" on public.profiles for update to authenticated using(public.gma_is_admin()) with check(public.gma_is_admin());
-- Advertisers cannot directly update profile columns, especially role or account status. Profile data is initialized by the signup trigger.
create policy "payments read own or admin" on public.payments for select to authenticated using(user_id=auth.uid() or public.gma_is_admin());
create policy "payments submit own" on public.payments for insert to authenticated with check(user_id=auth.uid() and status='pending' and amount=200);
create policy "payments admin update" on public.payments for update to authenticated using(public.gma_is_admin()) with check(public.gma_is_admin());
create policy "campaigns authenticated read" on public.campaigns for select to authenticated using(active=true or public.gma_is_admin());
create policy "campaigns admin insert" on public.campaigns for insert to authenticated with check(public.gma_is_admin() and created_by=auth.uid());
create policy "campaigns admin update" on public.campaigns for update to authenticated using(public.gma_is_admin()) with check(public.gma_is_admin());
create policy "assignments own or admin read" on public.campaign_assignments for select to authenticated using(user_id=auth.uid() or public.gma_is_admin());
create policy "assignments own insert" on public.campaign_assignments for insert to authenticated with check(user_id=auth.uid());
create policy "assignments own update" on public.campaign_assignments for update to authenticated using(user_id=auth.uid() or public.gma_is_admin()) with check(user_id=auth.uid() or public.gma_is_admin());
create policy "submissions own or admin read" on public.submissions for select to authenticated using(user_id=auth.uid() or public.gma_is_admin());
create policy "submissions own insert" on public.submissions for insert to authenticated with check(user_id=auth.uid() and status='pending' and approved_views=0);
create policy "submissions admin update" on public.submissions for update to authenticated using(public.gma_is_admin()) with check(public.gma_is_admin());
create policy "referrals read related or admin" on public.referrals for select to authenticated using(referrer_id=auth.uid() or referred_user_id=auth.uid() or public.gma_is_admin());
create policy "referral self create not allowed" on public.referrals for insert to authenticated with check(public.gma_is_admin());
create policy "referrals admin update" on public.referrals for update to authenticated using(public.gma_is_admin()) with check(public.gma_is_admin());
create policy "withdrawals own or admin read" on public.withdrawals for select to authenticated using(user_id=auth.uid() or public.gma_is_admin());
create policy "withdrawals own request" on public.withdrawals for insert to authenticated with check(user_id=auth.uid() and status='pending');
create policy "withdrawals admin update" on public.withdrawals for update to authenticated using(public.gma_is_admin()) with check(public.gma_is_admin());

-- Storage buckets: create these two buckets in Supabase Storage and configure policies below.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('proof-screenshots','proof-screenshots',false,5242880,array['image/jpeg','image/png','image/webp']),
 ('campaign-media','campaign-media',false,10485760,array['image/jpeg','image/png','image/webp','video/mp4'])
on conflict(id) do nothing;
create policy "advertiser upload own proof" on storage.objects for insert to authenticated with check(bucket_id='proof-screenshots' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "advertiser read own proof or admin" on storage.objects for select to authenticated using(bucket_id='proof-screenshots' and ((storage.foldername(name))[1]=auth.uid()::text or public.gma_is_admin()));
create policy "admin manage campaign media" on storage.objects for all to authenticated using(bucket_id='campaign-media' and public.gma_is_admin()) with check(bucket_id='campaign-media' and public.gma_is_admin());
create policy "authenticated read campaign media" on storage.objects for select to authenticated using(bucket_id='campaign-media' and auth.uid() is not null);

-- After creating your first account, promote that account to admin from SQL Editor:
-- update public.profiles set role='admin', status='active' where email='YOUR_ADMIN_EMAIL';
