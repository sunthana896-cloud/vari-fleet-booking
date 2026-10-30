-- ເພີ່ມຄໍລຳເບີ WhatsApp (run ໄດ້ຫຼາຍຄັ້ງ ບໍ່ເປັນຜົນເສຍ)
alter table public.vehicles add column if not exists owner_name  text not null default '';
alter table public.vehicles add column if not exists owner_phone text not null default '';
alter table public.rooms    add column if not exists notify_phone text not null default '';
alter table public.room_bookings add column if not exists tel text not null default '';
