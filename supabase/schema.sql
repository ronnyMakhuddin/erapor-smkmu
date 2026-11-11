-- =====================================================================
--  APLIKASI RAPOR SMK MAMBAUL ULUM — Skema Database Supabase
--  Jalankan seluruh file ini sekali di Supabase > SQL Editor > New query
-- =====================================================================
--  Arsitektur akses (Hybrid Login):
--   * Admin      : Supabase Auth (email & password) -> role "authenticated"
--   * Guru       : login lewat tabel guru (username + password) memakai
--                  fungsi RPC SECURITY DEFINER yang mengembalikan token sesi.
--                  Role "anon" TIDAK bisa membaca/mengubah tabel sensitif
--                  secara langsung, sehingga password & nilai aman.
--   * Jenis rapor: 'UTS' (tengah semester) dan 'AKHIR' (akhir semester).
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.sekolah (
  id              int primary key default 1 check (id = 1),
  nama            text not null default 'SMK Mambaul Ulum',
  npsn            text,
  alamat          text,
  kota            text,
  telepon         text,
  email           text,
  kepala_sekolah  text,
  nip_kepsek      text,
  logo            text
);
insert into public.sekolah (id) values (1) on conflict (id) do nothing;

create table if not exists public.tahun_ajaran (
  id             bigint generated always as identity primary key,
  nama           text not null,                       -- contoh: 2026/2027
  semester       text not null check (semester in ('Ganjil','Genap')),
  tanggal_rapor  date,                                 -- tanggal rapor akhir semester
  tanggal_uts    date,                                 -- tanggal rapor tengah semester
  aktif          boolean not null default false,
  created_at     timestamptz not null default now()
);

create table if not exists public.jurusan (
  id    bigint generated always as identity primary key,
  kode  text not null unique,
  nama  text not null
);

create table if not exists public.guru (
  id             bigint generated always as identity primary key,
  nip            text,
  nama           text not null,
  jk             text check (jk in ('L','P')),
  telepon        text,
  username       text not null unique,
  password_hash  text,
  aktif          boolean not null default true
);

create table if not exists public.kelas (
  id            bigint generated always as identity primary key,
  nama          text not null unique,
  tingkat       text not null check (tingkat in ('X','XI','XII')),
  jurusan_id    bigint references public.jurusan(id) on delete set null,
  wali_guru_id  bigint references public.guru(id) on delete set null
);

create table if not exists public.siswa (
  id             bigint generated always as identity primary key,
  nis            text,
  nisn           text not null unique,
  nama           text not null,
  jk             text check (jk in ('L','P')),
  tempat_lahir   text,
  tanggal_lahir  date,
  agama          text,
  nama_ortu      text,
  alamat         text,
  kelas_id       bigint references public.kelas(id) on delete set null,
  aktif          boolean not null default true
);

create table if not exists public.mapel (
  id        bigint generated always as identity primary key,
  kode      text,
  nama      text not null,
  kelompok  text not null default 'Umum' check (kelompok in ('Umum','Kejuruan','Pilihan','Muatan Lokal')),
  urut      int not null default 0,
  induk_id  bigint references public.mapel(id) on delete set null   -- sub-mapel/elemen (mis. 3.1 di bawah DKV)
);

create table if not exists public.mengajar (
  id        bigint generated always as identity primary key,
  guru_id   bigint not null references public.guru(id) on delete cascade,
  kelas_id  bigint not null references public.kelas(id) on delete cascade,
  mapel_id  bigint not null references public.mapel(id) on delete cascade,
  unique (kelas_id, mapel_id)
);

create table if not exists public.nilai (
  id               bigint generated always as identity primary key,
  siswa_id         bigint not null references public.siswa(id) on delete cascade,
  mapel_id         bigint not null references public.mapel(id) on delete cascade,
  tahun_ajaran_id  bigint not null references public.tahun_ajaran(id) on delete cascade,
  jenis            text not null default 'AKHIR' check (jenis in ('UTS','AKHIR')),
  formatif         jsonb,                                         -- {"cp1":[s1,s2,s3],"cp2":[...],"cp3":[...]}
  sts              numeric(5,2) check (sts between 0 and 100),   -- sumatif tengah semester
  sas              numeric(5,2) check (sas between 0 and 100),   -- sumatif akhir semester
  nilai_akhir      numeric(5,2) check (nilai_akhir between 0 and 100),   -- nilai rapor
  capaian          text,
  updated_at       timestamptz not null default now()
);

create table if not exists public.catatan_rapor (
  id               bigint generated always as identity primary key,
  siswa_id         bigint not null references public.siswa(id) on delete cascade,
  tahun_ajaran_id  bigint not null references public.tahun_ajaran(id) on delete cascade,
  sakit            int not null default 0,
  izin             int not null default 0,
  alpa             int not null default 0,
  kokurikuler      text,
  ekstrakurikuler  text,
  prestasi         text,
  catatan_wali     text,
  jenis            text not null default 'AKHIR' check (jenis in ('UTS','AKHIR')),
  keputusan        text
);

-- Deskripsi capaian pembelajaran (CP) per kelas, mapel & tahun ajaran (dipakai untuk capaian otomatis)
create table if not exists public.cp_mapel (
  id               bigint generated always as identity primary key,
  kelas_id         bigint not null references public.kelas(id) on delete cascade,
  mapel_id         bigint not null references public.mapel(id) on delete cascade,
  tahun_ajaran_id  bigint not null references public.tahun_ajaran(id) on delete cascade,
  cp1              text,
  cp2              text,
  cp3              text,
  unique (kelas_id, mapel_id, tahun_ajaran_id)
);

create table if not exists public.sesi_login (
  token       uuid primary key default gen_random_uuid(),
  peran       text not null check (peran = 'guru'),
  ref_id      bigint not null,
  dibuat      timestamptz not null default now(),
  kadaluarsa  timestamptz not null default now() + interval '12 hours'
);

-- Migrasi bila skema versi sebelumnya sudah pernah dijalankan
alter table public.sekolah add column if not exists logo text;   -- logo sekolah (data URL gambar)
-- Data untuk sampul, identitas sekolah & identitas peserta didik
alter table public.sekolah add column if not exists yayasan text;
alter table public.sekolah add column if not exists kelurahan text;
alter table public.sekolah add column if not exists kecamatan text;
alter table public.sekolah add column if not exists kabupaten text;
alter table public.sekolah add column if not exists provinsi text;
alter table public.sekolah add column if not exists website text;
alter table public.siswa add column if not exists status_keluarga text;
alter table public.siswa add column if not exists anak_ke int;
alter table public.siswa add column if not exists telepon text;
alter table public.siswa add column if not exists sekolah_asal text;
alter table public.siswa add column if not exists diterima_kelas text;
alter table public.siswa add column if not exists diterima_tanggal date;
alter table public.siswa add column if not exists nama_ayah text;
alter table public.siswa add column if not exists nama_ibu text;
alter table public.siswa add column if not exists alamat_ortu text;
alter table public.siswa add column if not exists telepon_ortu text;
alter table public.siswa add column if not exists pekerjaan_ayah text;
alter table public.siswa add column if not exists pekerjaan_ibu text;
alter table public.siswa add column if not exists nama_wali text;
alter table public.siswa add column if not exists alamat_wali text;
alter table public.siswa add column if not exists telepon_wali text;
alter table public.siswa add column if not exists pekerjaan_wali text;
alter table public.tahun_ajaran add column if not exists tanggal_uts date;
alter table public.mapel add column if not exists induk_id bigint references public.mapel(id) on delete set null;
alter table public.nilai add column if not exists formatif jsonb;
alter table public.nilai add column if not exists sts numeric(5,2) check (sts between 0 and 100);
alter table public.nilai add column if not exists sas numeric(5,2) check (sas between 0 and 100);
alter table public.catatan_rapor add column if not exists kokurikuler text;
alter table public.nilai add column if not exists jenis text not null default 'AKHIR' check (jenis in ('UTS','AKHIR'));
alter table public.catatan_rapor add column if not exists jenis text not null default 'AKHIR' check (jenis in ('UTS','AKHIR'));
alter table public.nilai drop constraint if exists nilai_siswa_id_mapel_id_tahun_ajaran_id_key;
alter table public.catatan_rapor drop constraint if exists catatan_rapor_siswa_id_tahun_ajaran_id_key;
create unique index if not exists nilai_unik on public.nilai (siswa_id, mapel_id, tahun_ajaran_id, jenis);
create unique index if not exists catatan_rapor_unik on public.catatan_rapor (siswa_id, tahun_ajaran_id, jenis);
delete from public.sesi_login where peran <> 'guru';
alter table public.sesi_login drop constraint if exists sesi_login_peran_check;
alter table public.sesi_login add constraint sesi_login_peran_check check (peran = 'guru');
-- Input nilai kini satu baris per siswa/mapel (jenis 'AKHIR'); gabungkan nilai UTS versi lama
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'nilai' and column_name = 'cp1') then
    insert into public.nilai (siswa_id, mapel_id, tahun_ajaran_id, jenis, formatif, sts)
    select siswa_id, mapel_id, tahun_ajaran_id, 'AKHIR',
           jsonb_build_object('cp1', jsonb_build_array(cp1), 'cp2', jsonb_build_array(cp2), 'cp3', jsonb_build_array(cp3)), sts
    from public.nilai where jenis = 'UTS'
    on conflict (siswa_id, mapel_id, tahun_ajaran_id, jenis)
    do update set formatif = coalesce(public.nilai.formatif, excluded.formatif), sts = coalesce(public.nilai.sts, excluded.sts);
    delete from public.nilai where jenis = 'UTS';
    alter table public.nilai drop column cp1, drop column cp2, drop column cp3;
  end if;
end $$;
drop trigger if exists trg_hash_siswa on public.siswa;
alter table public.siswa drop column if exists password_hash;

-- ---------------------------------------------------------------------
-- 2. HASH PASSWORD OTOMATIS (bcrypt)
--    Admin cukup mengisi password biasa; trigger mengubahnya jadi hash.
--    Jika kosong saat tambah guru: password default = username.
-- ---------------------------------------------------------------------
create or replace function public.hash_password()
returns trigger language plpgsql
set search_path = public, extensions as $$
begin
  if new.password_hash is null or new.password_hash = '' then
    if tg_op = 'INSERT' then
      new.password_hash := crypt(new.username, gen_salt('bf'));
    else
      new.password_hash := old.password_hash;
    end if;
  elsif new.password_hash not like '$2%' then
    new.password_hash := crypt(new.password_hash, gen_salt('bf'));
  end if;
  return new;
end $$;

drop trigger if exists trg_hash_guru on public.guru;
create trigger trg_hash_guru before insert or update on public.guru
  for each row execute function public.hash_password();

-- ---------------------------------------------------------------------
-- 3. FUNGSI BANTU (privat)
-- ---------------------------------------------------------------------
create or replace function public._akses(p_token uuid, out peran text, out ref_id bigint)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    peran := 'admin';
    return;
  end if;
  select s.peran, s.ref_id into peran, ref_id
    from sesi_login s where s.token = p_token and s.kadaluarsa > now();
  if peran is null then
    raise exception 'Sesi berakhir, silakan login kembali';
  end if;
end $$;

create or replace function public._ta_aktif()
returns bigint language plpgsql security definer set search_path = public as $$
declare v bigint;
begin
  select id into v from tahun_ajaran where aktif order by id desc limit 1;
  if v is null then raise exception 'Belum ada tahun ajaran aktif. Atur di menu Pengaturan.'; end if;
  return v;
end $$;

create or replace function public._cek_jenis(p_jenis text)
returns void language plpgsql as $$
begin
  if p_jenis is null or p_jenis not in ('UTS','AKHIR') then
    raise exception 'Jenis rapor harus UTS atau AKHIR';
  end if;
end $$;

create or replace function public._cek_mengajar(p_peran text, p_ref bigint, p_kelas bigint, p_mapel bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_peran = 'admin' then return; end if;
  -- guru mapel: hanya mapel yang diampu; wali kelas: semua mapel di kelasnya
  if p_peran = 'guru' and (
       exists (select 1 from mengajar where guru_id = p_ref and kelas_id = p_kelas and mapel_id = p_mapel)
    or exists (select 1 from kelas where id = p_kelas and wali_guru_id = p_ref)) then
    return;
  end if;
  raise exception 'Akses ditolak: Anda tidak mengajar mapel ini dan bukan wali kelas tersebut';
end $$;

create or replace function public._cek_wali(p_peran text, p_ref bigint, p_kelas bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_peran = 'admin' then return; end if;
  if p_peran = 'guru' and exists (select 1 from kelas where id = p_kelas and wali_guru_id = p_ref) then
    return;
  end if;
  raise exception 'Akses ditolak: Anda bukan wali kelas ini';
end $$;

-- ---------------------------------------------------------------------
-- 4. FUNGSI RPC (dipanggil dari aplikasi)
-- ---------------------------------------------------------------------
-- hapus versi lama (tanpa parameter jenis) bila ada
drop function if exists public.nilai_kelas(uuid, bigint, bigint);
drop function if exists public.simpan_nilai(uuid, bigint, bigint, jsonb);
drop function if exists public.catatan_kelas(uuid, bigint);
drop function if exists public.simpan_catatan(uuid, bigint, jsonb);
drop function if exists public.rapor_siswa(uuid, bigint, bigint);
drop function if exists public.nilai_kelas(uuid, bigint, bigint, text);
drop function if exists public.simpan_nilai(uuid, bigint, bigint, text, jsonb);
create or replace function public.login_pengguna(p_username text, p_password text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare g guru; t uuid;
begin
  delete from sesi_login where kadaluarsa < now();

  select * into g from guru where lower(username) = lower(trim(p_username)) and aktif;
  if found and g.password_hash = crypt(p_password, g.password_hash) then
    insert into sesi_login (peran, ref_id) values ('guru', g.id) returning token into t;
    return json_build_object('token', t, 'peran', 'guru', 'id', g.id, 'nama', g.nama);
  end if;

  raise exception 'Username atau password salah';
end $$;

create or replace function public.logout_pengguna(p_token uuid)
returns boolean language sql security definer set search_path = public as $$
  delete from sesi_login where token = p_token;
  select true;
$$;

create or replace function public.ganti_password(p_token uuid, p_lama text, p_baru text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare a record; h text;
begin
  select * into a from _akses(p_token);
  if length(coalesce(p_baru, '')) < 6 then raise exception 'Password baru minimal 6 karakter'; end if;
  if a.peran = 'guru' then
    select password_hash into h from guru where id = a.ref_id;
    if h <> crypt(p_lama, h) then raise exception 'Password lama salah'; end if;
    update guru set password_hash = p_baru where id = a.ref_id;
  else
    raise exception 'Admin mengganti password lewat Supabase Auth';
  end if;
  return true;
end $$;

create or replace function public.guru_beranda(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare a record;
begin
  select * into a from _akses(p_token);
  if a.peran <> 'guru' then raise exception 'Akses ditolak'; end if;
  return json_build_object(
    'guru', (select json_build_object('id', id, 'nama', nama, 'nip', nip, 'username', username) from guru where id = a.ref_id),
    'tahun_ajaran', (select row_to_json(t) from (select id, nama, semester, tanggal_rapor, tanggal_uts from tahun_ajaran where aktif order by id desc limit 1) t),
    'mengajar', coalesce((
      select json_agg(json_build_object(
        'kelas_id', k.id, 'kelas', k.nama, 'mapel_id', m.id, 'mapel', m.nama,
        'induk_id', m.induk_id, 'punya_sub', exists (select 1 from mapel c where c.induk_id = m.id),
        'milik', mj.guru_id = a.ref_id, 'pengampu', g.nama,
        'jumlah_siswa', (select count(*) from siswa s where s.kelas_id = k.id and s.aktif))
        order by k.nama, m.urut, m.nama)
      from mengajar mj join kelas k on k.id = mj.kelas_id join mapel m on m.id = mj.mapel_id join guru g on g.id = mj.guru_id
      -- mapel yang diampu + seluruh mapel di kelas perwalian
      where mj.guru_id = a.ref_id or k.wali_guru_id = a.ref_id), '[]'::json),
    'wali', coalesce((
      select json_agg(json_build_object('kelas_id', k.id, 'kelas', k.nama) order by k.nama)
      from kelas k where k.wali_guru_id = a.ref_id), '[]'::json)
  );
end $$;

create or replace function public.nilai_kelas(p_token uuid, p_kelas_id bigint, p_mapel_id bigint)
returns json language plpgsql security definer set search_path = public as $$
declare a record; v_ta bigint;
begin
  select * into a from _akses(p_token);
  perform _cek_mengajar(a.peran, a.ref_id, p_kelas_id, p_mapel_id);
  v_ta := _ta_aktif();
  return json_build_object(
    'cp', (select json_build_object('cp1', c.cp1, 'cp2', c.cp2, 'cp3', c.cp3) from cp_mapel c
           where c.kelas_id = p_kelas_id and c.mapel_id = p_mapel_id and c.tahun_ajaran_id = v_ta),
    'siswa', coalesce((
      select json_agg(json_build_object('siswa_id', s.id, 'nisn', s.nisn, 'nama', s.nama,
                                        'formatif', n.formatif, 'sts', n.sts, 'sas', n.sas,
                                        'nilai_akhir', n.nilai_akhir, 'capaian', n.capaian) order by s.nama)
      from siswa s
      left join nilai n on n.siswa_id = s.id and n.mapel_id = p_mapel_id and n.tahun_ajaran_id = v_ta and n.jenis = 'AKHIR'
      where s.kelas_id = p_kelas_id and s.aktif), '[]'::json));
end $$;

create or replace function public.simpan_nilai(p_token uuid, p_kelas_id bigint, p_mapel_id bigint, p_cp jsonb, p_data jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare a record; v_ta bigint; r record; n int := 0;
begin
  select * into a from _akses(p_token);
  perform _cek_mengajar(a.peran, a.ref_id, p_kelas_id, p_mapel_id);
  v_ta := _ta_aktif();
  if p_cp is not null then
    insert into cp_mapel (kelas_id, mapel_id, tahun_ajaran_id, cp1, cp2, cp3)
    values (p_kelas_id, p_mapel_id, v_ta, p_cp->>'cp1', p_cp->>'cp2', p_cp->>'cp3')
    on conflict (kelas_id, mapel_id, tahun_ajaran_id) do update set cp1 = excluded.cp1, cp2 = excluded.cp2, cp3 = excluded.cp3;
  end if;
  for r in select * from jsonb_to_recordset(p_data) as x(siswa_id bigint, formatif jsonb, sts numeric, sas numeric, nilai_akhir numeric, capaian text) loop
    continue when not exists (select 1 from siswa where id = r.siswa_id and kelas_id = p_kelas_id);
    insert into nilai (siswa_id, mapel_id, tahun_ajaran_id, jenis, formatif, sts, sas, nilai_akhir, capaian, updated_at)
    values (r.siswa_id, p_mapel_id, v_ta, 'AKHIR', r.formatif, r.sts, r.sas, r.nilai_akhir, r.capaian, now())
    on conflict (siswa_id, mapel_id, tahun_ajaran_id, jenis)
    do update set formatif = excluded.formatif, sts = excluded.sts, sas = excluded.sas,
                  nilai_akhir = excluded.nilai_akhir, capaian = excluded.capaian, updated_at = now();
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.catatan_kelas(p_token uuid, p_kelas_id bigint, p_jenis text)
returns json language plpgsql security definer set search_path = public as $$
declare a record; v_ta bigint;
begin
  select * into a from _akses(p_token);
  perform _cek_jenis(p_jenis);
  perform _cek_wali(a.peran, a.ref_id, p_kelas_id);
  v_ta := _ta_aktif();
  return coalesce((
    select json_agg(json_build_object(
      'siswa_id', s.id, 'nisn', s.nisn, 'nama', s.nama,
      'sakit', coalesce(c.sakit, 0), 'izin', coalesce(c.izin, 0), 'alpa', coalesce(c.alpa, 0),
      'kokurikuler', c.kokurikuler, 'ekstrakurikuler', c.ekstrakurikuler, 'prestasi', c.prestasi,
      'catatan_wali', c.catatan_wali, 'keputusan', c.keputusan) order by s.nama)
    from siswa s
    left join catatan_rapor c on c.siswa_id = s.id and c.tahun_ajaran_id = v_ta and c.jenis = p_jenis
    where s.kelas_id = p_kelas_id and s.aktif), '[]'::json);
end $$;

create or replace function public.simpan_catatan(p_token uuid, p_kelas_id bigint, p_jenis text, p_data jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare a record; v_ta bigint; r record; n int := 0;
begin
  select * into a from _akses(p_token);
  perform _cek_jenis(p_jenis);
  perform _cek_wali(a.peran, a.ref_id, p_kelas_id);
  v_ta := _ta_aktif();
  for r in select * from jsonb_to_recordset(p_data) as x(
      siswa_id bigint, sakit int, izin int, alpa int, kokurikuler text, ekstrakurikuler text,
      prestasi text, catatan_wali text, keputusan text) loop
    continue when not exists (select 1 from siswa where id = r.siswa_id and kelas_id = p_kelas_id);
    insert into catatan_rapor (siswa_id, tahun_ajaran_id, jenis, sakit, izin, alpa, kokurikuler, ekstrakurikuler, prestasi, catatan_wali, keputusan)
    values (r.siswa_id, v_ta, p_jenis, coalesce(r.sakit, 0), coalesce(r.izin, 0), coalesce(r.alpa, 0),
            r.kokurikuler, r.ekstrakurikuler, r.prestasi, r.catatan_wali, r.keputusan)
    on conflict (siswa_id, tahun_ajaran_id, jenis) do update set
      sakit = excluded.sakit, izin = excluded.izin, alpa = excluded.alpa, kokurikuler = excluded.kokurikuler,
      ekstrakurikuler = excluded.ekstrakurikuler, prestasi = excluded.prestasi,
      catatan_wali = excluded.catatan_wali, keputusan = excluded.keputusan;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.rapor_siswa(p_token uuid, p_siswa_id bigint, p_ta_id bigint, p_jenis text)
returns json language plpgsql security definer set search_path = public as $$
declare a record; v_siswa siswa; v_ta tahun_ajaran; v_kelas kelas;
begin
  select * into a from _akses(p_token);
  perform _cek_jenis(p_jenis);

  select * into v_siswa from siswa where id = p_siswa_id;
  if not found then raise exception 'Siswa tidak ditemukan'; end if;
  select * into v_kelas from kelas where id = v_siswa.kelas_id;

  if a.peran = 'guru' and coalesce(v_kelas.wali_guru_id, -1) <> a.ref_id then
    raise exception 'Akses ditolak: Anda bukan wali kelas siswa ini';
  end if;

  if p_ta_id is null then
    select * into v_ta from tahun_ajaran where aktif order by id desc limit 1;
  else
    select * into v_ta from tahun_ajaran where id = p_ta_id;
  end if;
  if v_ta.id is null then raise exception 'Tahun ajaran tidak ditemukan'; end if;

  return json_build_object(
    'jenis', p_jenis,
    'sekolah', (select row_to_json(x) from sekolah x where id = 1),
    'tahun_ajaran', json_build_object('id', v_ta.id, 'nama', v_ta.nama, 'semester', v_ta.semester, 'tanggal_rapor', v_ta.tanggal_rapor, 'tanggal_uts', v_ta.tanggal_uts),
    'siswa', row_to_json(v_siswa),   -- seluruh data siswa (untuk halaman identitas peserta didik)
    'kelas', case when v_kelas.id is null then null else json_build_object('nama', v_kelas.nama, 'tingkat', v_kelas.tingkat) end,
    'jurusan', (select json_build_object('kode', j.kode, 'nama', j.nama) from jurusan j where j.id = v_kelas.jurusan_id),
    'wali', (select json_build_object('nama', g.nama, 'nip', g.nip) from guru g where g.id = v_kelas.wali_guru_id),
    -- urutan & pengelompokan (termasuk sub-mapel) disusun di aplikasi
    'nilai', coalesce((
      select json_agg(json_build_object('id', x.id, 'induk_id', x.induk_id, 'mapel', x.mapel, 'kelompok', x.kelompok, 'urut', x.urut,
                                        'formatif', x.formatif, 'sts', x.sts, 'sas', x.sas,
                                        'nilai_akhir', x.nilai_akhir, 'capaian', x.capaian))
      from (
        select m.id, m.induk_id, m.nama as mapel, m.kelompok, m.urut, n.formatif, n.sts, n.sas, n.nilai_akhir, n.capaian
        from mapel m
        -- nilai diinput sekali; rapor tengah & akhir semester memakai data yang sama
        left join nilai n on n.mapel_id = m.id and n.siswa_id = v_siswa.id and n.tahun_ajaran_id = v_ta.id and n.jenis = 'AKHIR'
        where m.id in (select mapel_id from mengajar where kelas_id = v_siswa.kelas_id)
           or n.id is not null
           or m.id in (select c.induk_id from mapel c join mengajar mj on mj.mapel_id = c.id where mj.kelas_id = v_siswa.kelas_id)
      ) x), '[]'::json),
    'catatan', (select json_build_object('sakit', c.sakit, 'izin', c.izin, 'alpa', c.alpa, 'kokurikuler', c.kokurikuler,
                                         'ekstrakurikuler', c.ekstrakurikuler, 'prestasi', c.prestasi,
                                         'catatan_wali', c.catatan_wali, 'keputusan', c.keputusan)
                from catatan_rapor c where c.siswa_id = v_siswa.id and c.tahun_ajaran_id = v_ta.id and c.jenis = p_jenis)
  );
end $$;

-- ---------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['sekolah','tahun_ajaran','jurusan','guru','kelas','siswa','mapel','mengajar','nilai','catatan_rapor','cp_mapel','sesi_login'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
  -- Admin (authenticated) boleh CRUD semua tabel data
  foreach t in array array['sekolah','tahun_ajaran','jurusan','guru','kelas','siswa','mapel','mengajar','nilai','catatan_rapor','cp_mapel'] loop
    execute format('drop policy if exists "admin_all" on public.%I', t);
    execute format('create policy "admin_all" on public.%I for all to authenticated using (true) with check (true)', t);
  end loop;
  -- Guru (anon) hanya boleh MEMBACA data referensi yang tidak sensitif
  foreach t in array array['sekolah','tahun_ajaran','jurusan','kelas','mapel'] loop
    execute format('drop policy if exists "anon_read" on public.%I', t);
    execute format('create policy "anon_read" on public.%I for select to anon using (true)', t);
  end loop;
  -- sesi_login sengaja tanpa policy: hanya bisa diakses lewat fungsi RPC.
end $$;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant select on public.sekolah, public.tahun_ajaran, public.jurusan, public.kelas, public.mapel to anon;
revoke all on public.sesi_login from anon, authenticated;

revoke execute on function public._akses(uuid) from public, anon, authenticated;
revoke execute on function public._ta_aktif() from public, anon, authenticated;
revoke execute on function public._cek_jenis(text) from public, anon, authenticated;
revoke execute on function public._cek_mengajar(text, bigint, bigint, bigint) from public, anon, authenticated;
revoke execute on function public._cek_wali(text, bigint, bigint) from public, anon, authenticated;

grant execute on function public.login_pengguna(text, text) to anon, authenticated;
grant execute on function public.logout_pengguna(uuid) to anon, authenticated;
grant execute on function public.ganti_password(uuid, text, text) to anon, authenticated;
grant execute on function public.guru_beranda(uuid) to anon, authenticated;
grant execute on function public.nilai_kelas(uuid, bigint, bigint) to anon, authenticated;
grant execute on function public.simpan_nilai(uuid, bigint, bigint, jsonb, jsonb) to anon, authenticated;
grant execute on function public.catatan_kelas(uuid, bigint, text) to anon, authenticated;
grant execute on function public.simpan_catatan(uuid, bigint, text, jsonb) to anon, authenticated;
grant execute on function public.rapor_siswa(uuid, bigint, bigint, text) to anon, authenticated;
