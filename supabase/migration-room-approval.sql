-- ໃຫ້ການຈອງຫ້ອງປະຊຸມຕ້ອງອະນຸມັດ ແລະ ໃຊ້ຕາຕະລາງ decisions ຮ່ວມກັບການຈອງລົດ
alter table public.decisions drop constraint if exists decisions_booking_id_fkey;
