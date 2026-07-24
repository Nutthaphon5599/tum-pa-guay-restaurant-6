-- ============================================================
-- Tum Pa Guay Restaurant V5 Professional
-- Complete Supabase setup
-- Run this entire file in Supabase SQL Editor
-- ============================================================

create extension if not exists pgcrypto;

-- ----------------------------
-- Helper function: updated_at
-- ----------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------
-- Categories
-- ----------------------------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name_lo text not null,
  name_th text,
  name_en text,
  sort_order integer not null default 999,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_categories_updated_at on public.categories;
create trigger trg_categories_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

-- ----------------------------
-- Menu items
-- ----------------------------
create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on update cascade on delete restrict,
  name_lo text not null,
  name_th text,
  name_en text,
  description_lo text,
  description_th text,
  description_en text,
  price numeric(12,2) not null default 1000 check (price >= 0),
  variants jsonb not null default '[]'::jsonb,
  image_url text,
  image_path text,
  available boolean not null default true,
  featured boolean not null default false,
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_menu_items_category on public.menu_items(category_id);
create index if not exists idx_menu_items_available on public.menu_items(available);
create index if not exists idx_menu_items_sort on public.menu_items(sort_order);

drop trigger if exists trg_menu_items_updated_at on public.menu_items;
create trigger trg_menu_items_updated_at
before update on public.menu_items
for each row execute function public.set_updated_at();

-- ----------------------------
-- Reservations
-- ----------------------------
create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  phone text not null,
  booking_date date not null,
  booking_time time not null,
  guest_count integer not null check (guest_count > 0),
  note text,
  status text not null default 'new'
    check (status in ('new','confirmed','cancelled','completed','no_show')),
  source text not null default 'website'
    check (source in ('website','whatsapp','phone','walk_in','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_reservations_date on public.reservations(booking_date);
create index if not exists idx_reservations_status on public.reservations(status);

drop trigger if exists trg_reservations_updated_at on public.reservations;
create trigger trg_reservations_updated_at
before update on public.reservations
for each row execute function public.set_updated_at();

-- ----------------------------
-- Admin profiles
-- ----------------------------
create table if not exists public.admin_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'admin'
    check (role in ('owner','admin','staff')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_admin_profiles_updated_at on public.admin_profiles;
create trigger trg_admin_profiles_updated_at
before update on public.admin_profiles
for each row execute function public.set_updated_at();

-- Automatically create a profile when a new Auth user is created.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.admin_profiles(user_id, display_name, role, active)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', new.email), 'admin', true)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- ----------------------------
-- Restaurant settings
-- ----------------------------
create table if not exists public.restaurant_settings (
  id integer primary key default 1 check (id = 1),
  restaurant_name_lo text not null default 'ຮ້ານຕຳປ່າກ້ວຍ',
  restaurant_name_th text not null default 'ร้านตำป่าก้วย',
  restaurant_name_en text not null default 'Tum Pa Guay Restaurant',
  phone_display text not null default '020 2300 3002',
  phone_intl text not null default '8562023003002',
  whatsapp_intl text not null default '8562023003002',
  facebook_name text default 'LVmae Ladvongsa',
  address_lo text,
  address_th text,
  address_en text,
  maps_url text,
  opening_time time not null default '09:00',
  closing_time time not null default '18:30',
  hut_count integer not null default 90,
  hero_image_url text,
  logo_url text,
  updated_at timestamptz not null default now()
);

insert into public.restaurant_settings(
  id, address_lo, address_th, address_en
) values (
  1,
  'ບ້ານສະພັງເມິກ ຮ່ອມ 4, ເມືອງໄຊທານີ, ນະຄອນຫຼວງວຽງຈັນ',
  'บ้านสะพังเมิก ซอย 4 เมืองไซธานี นครหลวงเวียงจันทน์',
  'Saphang Meuk Village, Alley 4, Xaythany District, Vientiane Capital'
)
on conflict (id) do nothing;

drop trigger if exists trg_restaurant_settings_updated_at on public.restaurant_settings;
create trigger trg_restaurant_settings_updated_at
before update on public.restaurant_settings
for each row execute function public.set_updated_at();

-- ----------------------------
-- Audit log
-- ----------------------------
create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ----------------------------
-- Utility: active admin check
-- ----------------------------
create or replace function public.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_profiles ap
    where ap.user_id = auth.uid()
      and ap.active = true
      and ap.role in ('owner','admin','staff')
  );
$$;

-- ----------------------------
-- Row Level Security
-- ----------------------------
alter table public.categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.reservations enable row level security;
alter table public.admin_profiles enable row level security;
alter table public.restaurant_settings enable row level security;
alter table public.admin_audit_log enable row level security;

-- Categories policies
drop policy if exists "Public read active categories" on public.categories;
create policy "Public read active categories"
on public.categories for select
to anon, authenticated
using (active = true or public.is_active_admin());

drop policy if exists "Admins manage categories" on public.categories;
create policy "Admins manage categories"
on public.categories for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- Menu policies
drop policy if exists "Public read available menu" on public.menu_items;
create policy "Public read available menu"
on public.menu_items for select
to anon, authenticated
using (available = true or public.is_active_admin());

drop policy if exists "Admins manage menu" on public.menu_items;
create policy "Admins manage menu"
on public.menu_items for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- Reservation policies
drop policy if exists "Public create reservations" on public.reservations;
create policy "Public create reservations"
on public.reservations for insert
to anon, authenticated
with check (
  guest_count > 0
  and booking_date >= current_date
);

drop policy if exists "Admins read reservations" on public.reservations;
create policy "Admins read reservations"
on public.reservations for select
to authenticated
using (public.is_active_admin());

drop policy if exists "Admins update reservations" on public.reservations;
create policy "Admins update reservations"
on public.reservations for update
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

drop policy if exists "Admins delete reservations" on public.reservations;
create policy "Admins delete reservations"
on public.reservations for delete
to authenticated
using (public.is_active_admin());

-- Admin profile policies
drop policy if exists "Admins read own profile" on public.admin_profiles;
create policy "Admins read own profile"
on public.admin_profiles for select
to authenticated
using (user_id = auth.uid() or public.is_active_admin());

drop policy if exists "Owners manage admin profiles" on public.admin_profiles;
create policy "Owners manage admin profiles"
on public.admin_profiles for all
to authenticated
using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.user_id = auth.uid()
      and ap.active = true
      and ap.role = 'owner'
  )
)
with check (
  exists (
    select 1 from public.admin_profiles ap
    where ap.user_id = auth.uid()
      and ap.active = true
      and ap.role = 'owner'
  )
);

-- Settings policies
drop policy if exists "Public read restaurant settings" on public.restaurant_settings;
create policy "Public read restaurant settings"
on public.restaurant_settings for select
to anon, authenticated
using (true);

drop policy if exists "Admins update restaurant settings" on public.restaurant_settings;
create policy "Admins update restaurant settings"
on public.restaurant_settings for update
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- Audit policies
drop policy if exists "Admins read audit log" on public.admin_audit_log;
create policy "Admins read audit log"
on public.admin_audit_log for select
to authenticated
using (public.is_active_admin());

drop policy if exists "Admins create audit log" on public.admin_audit_log;
create policy "Admins create audit log"
on public.admin_audit_log for insert
to authenticated
with check (public.is_active_admin());

-- ----------------------------
-- Storage bucket and policies
-- ----------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'menu-images',
  'menu-images',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public view menu images" on storage.objects;
create policy "Public view menu images"
on storage.objects for select
to public
using (bucket_id = 'menu-images');

drop policy if exists "Admins upload menu images" on storage.objects;
create policy "Admins upload menu images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'menu-images'
  and public.is_active_admin()
);

drop policy if exists "Admins update menu images" on storage.objects;
create policy "Admins update menu images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'menu-images'
  and public.is_active_admin()
)
with check (
  bucket_id = 'menu-images'
  and public.is_active_admin()
);

drop policy if exists "Admins delete menu images" on storage.objects;
create policy "Admins delete menu images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'menu-images'
  and public.is_active_admin()
);

-- ----------------------------
-- Seed categories
-- ----------------------------
insert into public.categories(id, slug, name_lo, name_th, name_en, sort_order, active)
values ('12725894-65f8-5da2-b2ca-5702e3fb26b7', 'tam', 'ຕຳ', 'ตำ', 'Papaya Salad', 1, true)
on conflict (slug) do update set
  name_lo = excluded.name_lo,
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  sort_order = excluded.sort_order,
  active = excluded.active;

insert into public.categories(id, slug, name_lo, name_th, name_en, sort_order, active)
values ('4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed', 'yam', 'ຍຳ', 'ยำ', 'Spicy Salad', 2, true)
on conflict (slug) do update set
  name_lo = excluded.name_lo,
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  sort_order = excluded.sort_order,
  active = excluded.active;

insert into public.categories(id, slug, name_lo, name_th, name_en, sort_order, active)
values ('83a1a005-9235-5b29-979e-7fa9573a37cc', 'tom', 'ຕົ້ມ', 'ต้ม', 'Soup', 3, true)
on conflict (slug) do update set
  name_lo = excluded.name_lo,
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  sort_order = excluded.sort_order,
  active = excluded.active;

insert into public.categories(id, slug, name_lo, name_th, name_en, sort_order, active)
values ('403d9ddb-aa18-5029-9eb8-68515af3a538', 'fried', 'ທອດ', 'ทอด', 'Fried', 4, true)
on conflict (slug) do update set
  name_lo = excluded.name_lo,
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  sort_order = excluded.sort_order,
  active = excluded.active;

insert into public.categories(id, slug, name_lo, name_th, name_en, sort_order, active)
values ('95b59016-c2b0-592a-a102-3889de907e71', 'a-la-carte', 'ຕາມສັ່ງ', 'ตามสั่ง', 'A La Carte', 5, true)
on conflict (slug) do update set
  name_lo = excluded.name_lo,
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  sort_order = excluded.sort_order,
  active = excluded.active;

insert into public.categories(id, slug, name_lo, name_th, name_en, sort_order, active)
values ('0a51ea34-0448-5b88-8953-40373aedcb8c', 'grilled', 'ປີ້ງ', 'ปิ้ง', 'Grilled', 6, true)
on conflict (slug) do update set
  name_lo = excluded.name_lo,
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  sort_order = excluded.sort_order,
  active = excluded.active;

insert into public.categories(id, slug, name_lo, name_th, name_en, sort_order, active)
values ('f101cd3a-0e79-546f-911b-d51f4027760f', 'stir-fried', 'ຜັດ', 'ผัด', 'Stir-fried', 7, true)
on conflict (slug) do update set
  name_lo = excluded.name_lo,
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  sort_order = excluded.sort_order,
  active = excluded.active;

insert into public.categories(id, slug, name_lo, name_th, name_en, sort_order, active)
values ('fae38c4e-e0b4-51b2-9de3-313f2a603046', 'drinks', 'ເຄື່ອງດື່ມ', 'เครื่องดื่ม', 'Drinks', 8, true)
on conflict (slug) do update set
  name_lo = excluded.name_lo,
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  sort_order = excluded.sort_order,
  active = excluded.active;

-- ----------------------------
-- Seed 125 menu items
-- ----------------------------
insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '1bacc71b-4a21-5f70-a88e-cddb6a7f4020',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳປູມ້າ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  1
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'e9ddfa8a-a54a-581f-aab3-88a23a290b41',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳກຸ້ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  2
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '3f50c36c-6b85-5ae9-9240-fd1b409bc757',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳຫອຍແຄງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  3
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '4b99b2f9-ec53-5c2a-bf51-4a2bd48fd463',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳປາມຶກ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  4
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'd467038d-c7de-506d-a8a1-091761771741',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳປູ+ກຸ້ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  5
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '07124cb7-3fe4-56ff-9f9c-add513405950',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳປູ+ຫອຍແຄງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  6
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '58375322-fe68-5e79-bbb8-dfa5fe1743fe',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳທະເລ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  7
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '94a0ce99-9524-51c6-95b5-85e0323ee688',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳແຊວມ້ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  8
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '264c8cf8-e289-5433-9e58-9d27e9188b8f',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳກຸ້ງ+ແຊວມ້ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  9
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '26753a64-409b-58f8-936c-6ba3c1c10adc',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳຕ່ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  10
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '025840db-12d8-5b2d-bab8-c8b71d4b03c2',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳຕີນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  11
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '5477dff0-cf9c-567c-be72-e166f1eee4d2',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳຍໍ່ບັ້ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  12
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'f452759b-e8e7-5590-9201-24e6b1c631ac',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳປ່າ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  13
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'cc206229-69a2-5204-934a-d5e89338b033',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳເສັ້ນແກ້ວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  14
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '6161df3f-b8be-5b9d-8cd2-a336de7fefbb',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳເຂົ້າປຽກ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  15
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '6d98d3b2-775d-587c-b872-029a75730dad',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳໝີ່ຂາວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  16
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '457c369f-1f6b-5435-a81a-a2bb70b29e6b',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳໝີ່ໄວໆ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  17
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '6bd84106-e1ec-540d-af92-428f3019c5b8',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳເສັ້ນລ້ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  18
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '5e246f66-51a7-5846-ad32-252f00b852e8',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳໝາກຮຸ່ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  19
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'e4e80db2-f3cc-5b3a-b5fa-8c0b87a3b1a1',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳແຕງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  20
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'a2e57f31-f610-5460-805d-6224117a5b95',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳເຂົ້າປຸ້ນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  21
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'a0a37360-ff18-5b01-96a9-34fc5e12cd6f',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳສາລີໄຂ່ເຄັມ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  22
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'd2974855-acef-5559-8e59-94a549c1b775',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳຖາດ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  23
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '73a3c19d-c3cc-5d2b-b3c5-b8d9ec9dc424',
  '12725894-65f8-5da2-b2ca-5702e3fb26b7',
  'ຕຳຖົ່ວໝູກ໋ອບ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  24
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '01234cc1-e912-5d95-b984-da875824bcfc',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ສະລັດລາວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  25
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '3c666f4a-9ec1-5467-9628-3460be6e8f81',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳຍໍ່ບັ້ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  26
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'e5788ebc-8e1e-57fb-82a2-3b3f3c462d53',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳໄຂ່ຍ່ຽວມ້າ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  27
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'e6d8112a-4a9b-51ba-b555-0a8dd5bb6254',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳຫອຍແຄງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  28
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '05d3b23b-987c-5a23-a077-84847e34b097',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳກຸ້ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  29
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '03a6bfbc-9911-5075-b758-8b4694756dba',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳທະເລ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  30
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'f522cd05-6f32-5649-830e-aeaba027634e',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳປູອັດ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  31
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'bc3eea6e-7c57-5c0e-beea-8eb26841c7e2',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳເລັບມື້ນາງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  32
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'cc7caa32-0dce-5b7f-8cac-ce36ac7567cb',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳໃສ້ອ່ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  33
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '0798020c-062c-54e6-afc3-ea3c08886da8',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳປູມ້າ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  34
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '62a7b8be-b7d3-511c-a604-29f5e356b75c',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳແຊວມ້ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  35
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '6a6036c7-6f45-5adc-a7f2-d94ae2cb5cde',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳໄວໆ+ສົ້ມໝູ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  36
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '0a487f08-5b85-5493-b463-170b22619df0',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳໂຕ່ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  37
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '8a36e120-e3fe-5a27-bb22-da01a71bb98c',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳງົວເຜົາ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  38
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '04cfa7c6-5d3b-5e27-bb7d-3d8e9ffede34',
  '4ddb0c8b-4a8b-5f70-a964-4b6386ab01ed',
  'ຍຳເສັ້ນລ້ອນ+ໝູສັບ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  39
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '317fcab4-fcfb-55c8-bfd3-49e804f2be01',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ຕົ້ມເລືອດ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  40
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'a6b7f288-6828-5768-98e7-99b8ab08c771',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ຕົ້ມແຊບ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  41
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'd012c1bd-dfd4-52c6-b73c-d5ba174548a2',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ແກງໜໍ່',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  42
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '68122497-03e9-5ce4-a2d1-ae9a3defe456',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ແກງເຫັດ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  43
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'c8a9ff5a-4e09-598d-a89e-4560ac31e147',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ແກງຈືດ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  44
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'ea25d99f-8e30-5eef-9a63-47a0a958e036',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ຕົ້ມແຊບດູກຂ້າງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  45
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '8addcdc1-5dda-53cd-98b0-bbf20bad9bca',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ຕົ້ມຍຳຫົວແຊວມ້ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  46
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'fd6b16e0-ffd8-5180-ae00-ab05718047a8',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ຕົ້ມຍຳທະເລ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  47
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'c43ab601-8ad6-5d64-bf01-cfe4e6232d5f',
  '83a1a005-9235-5b29-979e-7fa9573a37cc',
  'ຕົ້ມຍຳປາເຄິງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  48
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '828a8422-98fb-5b7b-8e31-7faa794f3217',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດລູກຊີ້ນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  49
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'd197d501-8c59-575f-81df-4fbe2bfd1669',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດຫົວກຸ້ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  50
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '75e4fa4d-92c7-5617-8b07-f95e45b7ca09',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດເຫືອກ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  51
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '60c8048b-d683-554d-9cd1-b741d5b5c6af',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດຄາງເປັດ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  52
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '751a680f-aea7-50b3-9d96-276ddb21063c',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດນ໋ອງໄກ່',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  53
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '550d9841-65ed-5ebc-a83b-045e21f55502',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ກຸ້ງຊຸບແປ້ງທອດ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  54
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '85e8f604-94fe-5008-9e2d-5464511aed84',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດດູກຂ້າງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  55
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '1432c676-3528-526d-a41c-c010e29b53b1',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດຮ໋ອນດ໋ອກ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  56
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '0d568f58-54e7-5192-aa8c-cce0a1029613',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດມັນຝຣັ່ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  57
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '7a8356ce-c1c6-52ec-a075-535981a50dd5',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດປາມຶກ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  58
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '671c998d-e19d-56a6-af7d-c50b48377032',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ເຫັດຊຸບແປ້ງທອດ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  59
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'e5b4022a-d48a-5fce-895c-52c38dbd13d3',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດໄສ້ອ່ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  60
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'b54a45ba-0994-53c8-9a62-b31dc5f3a53b',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດເອັນເຫຼືອງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  61
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'b774790a-9e99-5f4d-b4b3-c6f71e8c6b13',
  '403d9ddb-aa18-5029-9eb8-68515af3a538',
  'ທອດໄສ້ກອກອີ່ສານ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  62
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '34d5f68a-637f-5ec2-8ce0-4b5012cf3766',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ກຸ້ງແຊ່ນໍ້າປາ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  63
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '4e67f44b-d5e9-595a-9563-0f54446907c6',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ສົ້ມໝູ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  64
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '181cf71d-8a06-53df-8526-6844b8aaf588',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ປາໜຶ້ງໝາກນາວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  65
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '08fc57af-20ec-5208-a268-025e2ae42e26',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ປາລາດພິກ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  66
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '52d8b617-2c91-5632-8670-938e266fba63',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ປານິນທອດສະໝູນໄພ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  67
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '611738a7-5f16-53f1-8b3b-819d4fe8d5a0',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ປາຊາບະລົມຄວັນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  68
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'ccae57d6-5afa-5682-93e5-258fc8660a02',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ປາປ້ຽວຫວານ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  69
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'cca664a5-9610-58ca-91b3-35cd7ac8be88',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ກ້ອຍປານິນ+ຕົ້ມ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  70
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '3c4afb60-99a9-5722-9ee4-cb3d6c930e65',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ກ້ອຍປາເຄິ່ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  71
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '2af05ee1-dfe2-5fb9-b608-160bc9da52b2',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຕົ້ມສົ້ມປາເຄິງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  72
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '9f0c689b-eb25-5da9-bd3d-3f5559a6b9e1',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ກ້ອຍແຊວມ້ອນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  73
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'd5e83398-e2d2-58d1-92b2-4184c42a45e2',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ປູອັດບາຊາບິ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  74
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'f8caa7e6-3451-5b9c-b250-bec286b1394f',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ແຊວມ້ອນບາຊາບິ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  75
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '49b7e4c8-a486-5581-be68-05a6633ea564',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ລວກຊີ້ນງົວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  76
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '931fa72c-a245-55de-92af-ca3f3aac77b3',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ລວກທະເລ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  77
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'cfb37440-bd86-5a0c-9089-146d2495c93b',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ລາບງົວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  78
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '7766dabb-dd3e-5840-b311-d9c75c4f3c24',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ພັນໝ້ຽງປາ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  79
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '36c37fc7-2a54-5a97-b35f-96615ebe9acf',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ເອາະຊີ້ນໝູ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  80
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '22640a30-07cd-5941-9e70-5bcad4ae6dda',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ເອາະຊີ້ນງົວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  81
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '848d8aba-12df-5785-8a30-842a72078882',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຜັກບົ້ງໄຟແດງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  82
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '39f7f9eb-6e17-5f61-9e8f-328c574732c2',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຜັກກາດນາໝູກອບ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  83
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'a145cd92-f152-5a1e-a6db-512fad1688a4',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ກະເພົາໝູກອບ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  84
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '27c5d7d8-abbb-5670-9a43-1dbff3bc2530',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຂົ້ວເຫັດລວມ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  85
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '880ff532-73ca-5b8d-b702-94fb91f65e66',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຂົ້ວຜັກລວມ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  86
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '681f515c-c03c-5d3b-9a09-2f24034eca7f',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຜັດຫອຍແຄງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  87
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '7fb47e0e-9224-5db7-8584-2b819ec1c7ec',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ສະເຕັກງົວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  88
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '32467624-c5c3-5c5a-9c78-b83c63a30d8f',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ສະເຕັກໝູ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  89
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'bdd10102-ba34-5cea-b117-b2e3c6ec5e97',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຂົ້ວເຫັດເຂັມໃສ່ກຸ້ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  90
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '8fb56703-a0dd-5a62-9189-785693d25e96',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ປາມຶກຜັດໄຂ່ເຂັມ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  91
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'f5da8b8f-815f-5efa-b392-9205ca9e5b40',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຜັດເສື້ອຮ້ອງໄຫ້',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  92
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '5ffa8aa6-8f4e-5e75-aedd-b9f3b0914f15',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ກະເຜົາໝູ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  93
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '15c3d982-ac5d-5eb7-916c-ef062c6951de',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ກະເຜົາທະເລ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  94
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '920fbce6-490a-5988-859e-40a1a94c09e2',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ແລັມໂບ້ໝູ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  95
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'ee08e3ea-26b4-5897-8d5a-97443fe36588',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ແລັມໂບ້ງົວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  96
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '24006efe-7115-52a4-a279-b3580fcb667d',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ແລັມໂບ້ອ່ຽນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  97
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '1fc8f16e-a8e0-5b7b-8349-b8d8d7bdffcf',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຜັດຂີ້ເມົາໝູ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  98
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '7e675d4a-56cc-5d9d-b2d1-1026d7fd6b81',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຜັດຂີ້ເມົາງົວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  99
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '97e0bcdc-4b2b-5af1-9364-d96b1c348077',
  '95b59016-c2b0-592a-a102-3889de907e71',
  'ຜັດຂີ້ເມົາທະເລ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  100
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'ab94181d-b5ce-5a79-87ea-f912a711da6c',
  '0a51ea34-0448-5b88-8953-40373aedcb8c',
  'ປີ້ງຄໍໝູຍ້າງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  101
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '102fcb95-8996-51c3-8f9e-c442b36215c2',
  '0a51ea34-0448-5b88-8953-40373aedcb8c',
  'ປີ້ງປາ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  102
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '36756779-c7e3-580b-bd7b-5bf2239123ce',
  '0a51ea34-0448-5b88-8953-40373aedcb8c',
  'ປິ້ງຊີ້ນງົວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  103
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '5b080fcf-8d6d-5490-ac1d-24a10614267e',
  '0a51ea34-0448-5b88-8953-40373aedcb8c',
  'ປີ້ງກຸ້ງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  104
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '8f24a1d4-eca0-507d-9751-dc6f07389df7',
  '0a51ea34-0448-5b88-8953-40373aedcb8c',
  'ປີ້ງປາມຶກ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  105
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '01520c8b-ef19-5ea0-a2ff-a275dba95921',
  '0a51ea34-0448-5b88-8953-40373aedcb8c',
  'ປີ້ງເສື້ອຮ້ອງໄຫ້',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  106
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '96ce0885-8a13-5585-aa9e-5e037ffb83dc',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າຈ້າວ',
  1000.0,
  '["ຈານ", "ໝໍ້"]'::jsonb,
  null,
  null,
  true,
  false,
  107
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '0e445cac-d789-5de2-8119-10e26debff7e',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າຜັດໝູ',
  1000.0,
  '["ຈານນ້ອຍ", "ໃຫຍ່"]'::jsonb,
  null,
  null,
  true,
  false,
  108
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '2ac3459a-5ea2-5f2f-9f44-91788973c9d6',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າຜັດງົວ',
  1000.0,
  '["ຈານນ້ອຍ", "ໃຫຍ່"]'::jsonb,
  null,
  null,
  true,
  false,
  109
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'a6ac42f7-6aab-51dc-bcf5-8e284f45ef6d',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າຜັດທະເລ',
  1000.0,
  '["ຈານນ້ອຍ", "ໃຫຍ່"]'::jsonb,
  null,
  null,
  true,
  false,
  110
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'f8c3f6d2-7557-59be-acc1-4f3ac5283392',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າຜັດໝູກອບ',
  1000.0,
  '["ຈານນ້ອຍ", "ໃຫຍ່"]'::jsonb,
  null,
  null,
  true,
  false,
  111
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '13eb2a62-43a5-5449-a499-536998b409ed',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າຜັດຕົ້ມຍຳ',
  1000.0,
  '["ຈານນ້ອຍ", "ໃຫຍ່"]'::jsonb,
  null,
  null,
  true,
  false,
  112
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'b4c11f17-5bdb-5899-a738-a31b4f64623a',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າຜັດໃສ້ກອກ',
  1000.0,
  '["ຈານນ້ອຍ", "ໃຫຍ່"]'::jsonb,
  null,
  null,
  true,
  false,
  113
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'ce3e5574-5c93-5bdc-92d3-79031d124cac',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າໝູທອດກະທຽມ',
  1000.0,
  '["ຈານນ້ອຍ", "ໃຫຍ່"]'::jsonb,
  null,
  null,
  true,
  false,
  114
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '5cc9c9bd-a842-50c2-ab1a-f6279c524dbf',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ເຂົ້າຄຸກກະປິ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  115
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '6008f4e5-7063-53c1-ac69-0946778f358a',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ຜັດໄທໝູ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  116
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'd1af9e9b-97c9-5433-ba1f-f9bd2e4e5997',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ຜັດໄທງົວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  117
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'cdaff587-3b48-5643-abdf-b70a89cad8ec',
  'f101cd3a-0e79-546f-911b-d51f4027760f',
  'ຜັດໄທທະເລ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  118
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'ee178a05-5cab-51be-9aca-8eb593e4e2da',
  'fae38c4e-e0b4-51b2-9de3-313f2a603046',
  'ນໍ້າດື່ມກາງ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  119
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'e6b75b95-62d4-5cb9-bd50-cf1ce85ca65c',
  'fae38c4e-e0b4-51b2-9de3-313f2a603046',
  'ແປັບຊີຕຸກໃຫຍ່',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  120
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'a43cdef6-831b-54fc-84b4-6887ea939a91',
  'fae38c4e-e0b4-51b2-9de3-313f2a603046',
  'ແປັບຊີແກ້ວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  121
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '01b92e51-59f9-5df9-891e-bca8b4d7ee6f',
  'fae38c4e-e0b4-51b2-9de3-313f2a603046',
  'ເບຍລາວ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  122
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '94818991-797a-5842-9a75-e6333c6da440',
  'fae38c4e-e0b4-51b2-9de3-313f2a603046',
  'ເບຍໄຮນິເກັນ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  123
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  'b40bf66a-ed48-5887-98a4-5f2839c30ff5',
  'fae38c4e-e0b4-51b2-9de3-313f2a603046',
  'ຊຳເມີບີ',
  1000.0,
  '[]'::jsonb,
  null,
  null,
  true,
  false,
  124
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;

insert into public.menu_items(
  id, category_id, name_lo, price, variants, image_url, image_path,
  available, featured, sort_order
) values (
  '2c5e9196-1b83-59c8-ab8a-e519243d99e1',
  'fae38c4e-e0b4-51b2-9de3-313f2a603046',
  'ນໍ້າກ້ອນ',
  1000.0,
  '["ໂຖນ້ອຍ", "ໃຫຍ່"]'::jsonb,
  null,
  null,
  true,
  false,
  125
)
on conflict (id) do update set
  category_id = excluded.category_id,
  name_lo = excluded.name_lo,
  price = excluded.price,
  variants = excluded.variants,
  available = excluded.available,
  featured = excluded.featured,
  sort_order = excluded.sort_order;


-- ----------------------------
-- Final verification queries
-- ----------------------------
select 'categories' as table_name, count(*) as total from public.categories
union all
select 'menu_items', count(*) from public.menu_items
union all
select 'reservations', count(*) from public.reservations;

-- IMPORTANT:
-- 1. After creating your first Auth user, run this once to make that user the owner:
--    update public.admin_profiles
--    set role = 'owner', active = true
--    where user_id = (select id from auth.users where email = 'YOUR_ADMIN_EMAIL');
--
-- 2. Never place the service_role key in GitHub or browser JavaScript.
