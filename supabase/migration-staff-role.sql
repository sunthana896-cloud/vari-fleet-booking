-- ສິດໃໝ່ "staff" = ໃສ່ຂໍ້ມູນເທົ່ານັ້ນ (ຈອງ ແລະ ແກ້ເວລາໄດ້ ແຕ່ຍົກເລີກບໍ່ໄດ້) ສຳລັບບັນຊີກາງຂອງພະນັກງານ
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
  using (uid = auth.uid() or public.is_admin())
  with check (uid = auth.uid() or public.is_admin());

drop policy if exists p_rbookings_update on public.room_bookings;
create policy p_rbookings_update on public.room_bookings for update to authenticated
  using (uid = auth.uid() or public.is_admin())
  with check (uid = auth.uid() or public.is_admin());

-- ກົດເພີ່ມ (ບັງຄັບໃນຖານຂໍ້ມູນ):
--  • ບັນຊີ "ໃສ່ຂໍ້ມູນເທົ່ານັ້ນ" ແກ້ໄດ້ສະເພາະເວລາເລີ່ມ-ສິ້ນສຸດ (ຍົກເລີກ/ແກ້ອື່ນບໍ່ໄດ້)
--  • ການຈອງທີ່ອະນຸມັດ/ບໍ່ອະນຸມັດແລ້ວ ແກ້ເວລາໄດ້ສະເພາະຜູ້ດູແລ
create or replace function public.guard_booking_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if public.is_staff()
       and (to_jsonb(new) - 'start_ts' - 'end_ts') is distinct from (to_jsonb(old) - 'start_ts' - 'end_ts') then
      raise exception 'staff accounts can only change the booking time';
    end if;
    if (new.start_ts is distinct from old.start_ts or new.end_ts is distinct from old.end_ts)
       and exists (select 1 from public.decisions where booking_id = old.id) then
      raise exception 'only an admin can change the time of a decided booking';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists guard_bookings_update on public.bookings;
create trigger guard_bookings_update before update on public.bookings
  for each row execute function public.guard_booking_update();
drop trigger if exists guard_rbookings_update on public.room_bookings;
create trigger guard_rbookings_update before update on public.room_bookings
  for each row execute function public.guard_booking_update();
