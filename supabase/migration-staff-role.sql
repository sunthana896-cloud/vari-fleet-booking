-- ສິດໃໝ່ "staff" = ໃສ່ຂໍ້ມູນເທົ່ານັ້ນ (ຈອງໄດ້ ແຕ່ແກ້ໄຂ/ຍົກເລີກບໍ່ໄດ້) ສຳລັບບັນຊີກາງຂອງພະນັກງານ
-- run ໄດ້ຫຼາຍຄັ້ງ ບໍ່ເປັນຜົນເສຍ
do $$ declare c text; begin
  for c in select conname from pg_constraint
           where conrelid = 'public.profiles'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ilike '%role%' loop
    execute format('alter table public.profiles drop constraint %I', c);
  end loop;
end $$;
alter table public.profiles add constraint profiles_role_check check (role in ('admin','user','staff'));

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'staff');
$$;

drop policy if exists p_bookings_update on public.bookings;
create policy p_bookings_update on public.bookings for update to authenticated
  using ((uid = auth.uid() and not public.is_staff()) or public.is_admin())
  with check ((uid = auth.uid() and not public.is_staff()) or public.is_admin());

drop policy if exists p_rbookings_update on public.room_bookings;
create policy p_rbookings_update on public.room_bookings for update to authenticated
  using ((uid = auth.uid() and not public.is_staff()) or public.is_admin())
  with check ((uid = auth.uid() and not public.is_staff()) or public.is_admin());
