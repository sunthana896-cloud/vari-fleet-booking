-- =====================================================================
-- Vari Fleet & Meeting — ໂຄງສ້າງຖານຂໍ້ມູນ Supabase
-- ວາງທັງໝົດນີ້ໃນ SQL Editor ແລ້ວກົດ Run ເທື່ອດຽວຈົບ
-- ແລ່ນຊ້ຳໄດ້ ບໍ່ພັງ (ໃຊ້ if not exists / or replace)
-- =====================================================================

-- ---------- 1. ຕາຕະລາງຜູ້ໃຊ້ (ຜູກກັບ Supabase Auth) ----------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text unique not null,
  name       text not null default '',
  role       text not null default 'user' check (role in ('admin','user')),
  created_at timestamptz not null default now()
);

-- ---------- 2. ລົດ ແລະ ຫ້ອງປະຊຸມ ----------
create table if not exists public.vehicles (
  id         uuid primary key default gen_random_uuid(),
  plate      text not null,
  name       text not null default '',
  seats      text not null default '',
  note       text not null default '',
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.rooms (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  capacity   text not null default '',
  note       text not null default '',
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------- 3. ການຈອງລົດ ----------
-- ເກັບເວລາເປັນ text ຮູບແບບ 'YYYY-MM-DDTHH:MM' ຄືກັບທີ່ແອັບໃຊ້ຢູ່
-- ເພື່ອບໍ່ຕ້ອງແກ້ໂຕກວດເວລາຊ້ອນກັນທີ່ໃຊ້ງານໄດ້ດີຢູ່ແລ້ວ
create table if not exists public.bookings (
  id         uuid primary key default gen_random_uuid(),
  uid        uuid not null references auth.users(id) on delete cascade,
  booker     text not null default '',
  vehicle_id uuid references public.vehicles(id) on delete set null,
  start_ts   text not null,
  end_ts     text not null,
  dep        text not null default '',
  tel        text not null default '',
  dest       text not null default '',
  pax        text not null default '',
  purpose    text not null default '',
  cancelled  boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- 4. ການຈອງຫ້ອງປະຊຸມ ----------
create table if not exists public.room_bookings (
  id         uuid primary key default gen_random_uuid(),
  uid        uuid not null references auth.users(id) on delete cascade,
  booker     text not null default '',
  room_id    uuid references public.rooms(id) on delete set null,
  start_ts   text not null,
  end_ts     text not null,
  title      text not null default '',
  dep        text not null default '',
  pax        text not null default '',
  note       text not null default '',
  cancelled  boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- 5. ການອະນຸມັດ (1 ການຈອງ = 1 ການຕັດສິນ) ----------
create table if not exists public.decisions (
  booking_id uuid primary key references public.bookings(id) on delete cascade,
  status     text not null check (status in ('approved','rejected')),
  decided_by uuid references auth.users(id) on delete set null,
  decided_at timestamptz not null default now()
);

-- =====================================================================
-- ສ້າງ profile ອັດຕະໂນມັດເມື່ອມີຄົນສະໝັກ
-- ອີເມວໃນລາຍການລຸ່ມນີ້ຈະໄດ້ສິດຜູ້ດູແລທັນທີ
-- =====================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', ''),
    case when lower(new.email) in ('sunthana896@gmail.com')
         then 'admin' else 'user' end
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ໂຕຊ່ວຍກວດວ່າຄົນທີ່ກຳລັງໃຊ້ຢູ່ເປັນຜູ້ດູແລບໍ່
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- =====================================================================
-- ສິດການເຂົ້າເຖິງ (Row Level Security)
-- ເປີດທຸກຕາຕະລາງ — ຄົນທີ່ບໍ່ໄດ້ລັອກອິນ ເຂົ້າບໍ່ໄດ້ເລີຍ
-- =====================================================================
alter table public.profiles      enable row level security;
alter table public.vehicles      enable row level security;
alter table public.rooms         enable row level security;
alter table public.bookings      enable row level security;
alter table public.room_bookings enable row level security;
alter table public.decisions     enable row level security;

-- profiles: ຜູ້ລັອກອິນເຫັນທຸກຄົນ (ຕ້ອງໃຊ້ສະແດງຊື່ຜູ້ຈອງ)
--           ແກ້ສິດໄດ້ສະເພາະຜູ້ດູແລ
drop policy if exists p_profiles_read   on public.profiles;
drop policy if exists p_profiles_update on public.profiles;
drop policy if exists p_profiles_delete on public.profiles;
create policy p_profiles_read   on public.profiles for select to authenticated using (true);
create policy p_profiles_update on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy p_profiles_delete on public.profiles for delete to authenticated
  using (public.is_admin() and id <> auth.uid());

-- ລົດ / ຫ້ອງ: ທຸກຄົນທີ່ລັອກອິນເບິ່ງໄດ້ · ເພີ່ມ-ແກ້-ລຶບ ສະເພາະຜູ້ດູແລ
drop policy if exists p_vehicles_read on public.vehicles;
drop policy if exists p_vehicles_write on public.vehicles;
create policy p_vehicles_read  on public.vehicles for select to authenticated using (true);
create policy p_vehicles_write on public.vehicles for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists p_rooms_read on public.rooms;
drop policy if exists p_rooms_write on public.rooms;
create policy p_rooms_read  on public.rooms for select to authenticated using (true);
create policy p_rooms_write on public.rooms for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ການຈອງ: ທຸກຄົນເຫັນໝົດ (ຕ້ອງເຫັນຈຶ່ງຮູ້ວ່າຊ້ອນກັນບໍ່)
--          ສ້າງໄດ້ສະເພາະໃນນາມຕົນເອງ · ຍົກເລີກໄດ້ເຈົ້າຂອງ ຫຼື ຜູ້ດູແລ
drop policy if exists p_bookings_read   on public.bookings;
drop policy if exists p_bookings_insert on public.bookings;
drop policy if exists p_bookings_update on public.bookings;
drop policy if exists p_bookings_delete on public.bookings;
create policy p_bookings_read   on public.bookings for select to authenticated using (true);
create policy p_bookings_insert on public.bookings for insert to authenticated
  with check (uid = auth.uid());
create policy p_bookings_update on public.bookings for update to authenticated
  using (uid = auth.uid() or public.is_admin())
  with check (uid = auth.uid() or public.is_admin());
create policy p_bookings_delete on public.bookings for delete to authenticated
  using (public.is_admin());

drop policy if exists p_rbookings_read   on public.room_bookings;
drop policy if exists p_rbookings_insert on public.room_bookings;
drop policy if exists p_rbookings_update on public.room_bookings;
drop policy if exists p_rbookings_delete on public.room_bookings;
create policy p_rbookings_read   on public.room_bookings for select to authenticated using (true);
create policy p_rbookings_insert on public.room_bookings for insert to authenticated
  with check (uid = auth.uid());
create policy p_rbookings_update on public.room_bookings for update to authenticated
  using (uid = auth.uid() or public.is_admin())
  with check (uid = auth.uid() or public.is_admin());
create policy p_rbookings_delete on public.room_bookings for delete to authenticated
  using (public.is_admin());

-- ການອະນຸມັດ: ທຸກຄົນເຫັນ · ຕັດສິນໄດ້ສະເພາະຜູ້ດູແລ
drop policy if exists p_decisions_read  on public.decisions;
drop policy if exists p_decisions_write on public.decisions;
create policy p_decisions_read  on public.decisions for select to authenticated using (true);
create policy p_decisions_write on public.decisions for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- =====================================================================
-- ເປີດ Realtime — ໃຫ້ທຸກເຄື່ອງເຫັນການຈອງອັບເດດທັນທີ
-- =====================================================================
alter publication supabase_realtime add table public.vehicles;
alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.bookings;
alter publication supabase_realtime add table public.room_bookings;
alter publication supabase_realtime add table public.decisions;
alter publication supabase_realtime add table public.profiles;

-- ---------- ດັດຊະນີ ໃຫ້ຄົ້ນຫາໄວ ----------
create index if not exists idx_bookings_vehicle on public.bookings(vehicle_id);
create index if not exists idx_bookings_start   on public.bookings(start_ts);
create index if not exists idx_rbookings_room   on public.room_bookings(room_id);
create index if not exists idx_rbookings_start  on public.room_bookings(start_ts);
