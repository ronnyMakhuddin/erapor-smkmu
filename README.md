# e-Rapor SMK Mambaul Ulum

Aplikasi rapor digital (Kurikulum Merdeka) untuk SMK Mambaul Ulum. Frontend statis (HTML + JS) yang berjalan di **Vercel**, dengan database & login di **Supabase**.

## Fitur

| Peran | Cara login | Menu |
|---|---|---|
| **Admin** | Email & password (Supabase Auth) | Beranda & progres nilai UTS / akhir semester, Siswa (+ impor dari Excel), Guru, Kelas, Mata Pelajaran, Konsentrasi Keahlian, Pembagian Mengajar, Input Nilai, Kehadiran & Catatan, Cetak Rapor (per siswa / satu kelas), Pengaturan (identitas sekolah, tahun ajaran) |
| **Guru mapel** | Username + password (tabel `guru`) | Beranda, Input Nilai & CP hanya untuk mapel yang diampu, Ganti Password |
| **Wali kelas** (guru yang ditunjuk di menu Kelas) | sama dengan guru | Semua menu guru + Input Nilai & CP **semua mapel di kelas perwaliannya**, Kehadiran & Catatan, Cetak Rapor kelasnya |

Siswa tidak memiliki akun; rapor dicetak/di-PDF-kan oleh admin atau wali kelas.

**Input nilai cukup sekali** per mapel (menu Input Nilai), mengikuti form nilai Excel sekolah: CP1–CP3 (masing-masing S1–S3), N. STS, N. SAS. Rata-rata CP dan **Nilai Rapor = rata-rata semua nilai (S1–S3 CP1–CP3, STS, SAS)** dihitung otomatis. Form Excel guru (sheet CP 1, CP 2, CP 3, NILAI UJIAN) bisa langsung diimpor lewat tombol **Impor Form Excel**; siswa dicocokkan berdasarkan nama. Deskripsi CP bisa diketik atau dipilih lewat tombol **Pilih dari Daftar CP** (CP Keputusan Kepala BSKAP No. 046/H/KR/2025 Fase E & F untuk mapel umum SMK — PAI, Pendidikan Pancasila, Bahasa Indonesia, Matematika, Bahasa Inggris, Informatika, Seni, PJOK, Bahasa Arab, Sejarah, Projek IPAS, KKA, KIK, PKL — serta kejuruan Desain Komunikasi Visual; yang tampil hanya CP untuk mapel yang sudah diinput di menu Mata Pelajaran; sub-mapel otomatis mencari CP di mapel induknya), lalu dipakai untuk **Capaian Otomatis**.

Di menu **Cetak Rapor** ada pilihan **Yang Dicetak**: Rapor (nilai), **Sampul**, **Identitas Sekolah**, **Identitas Peserta Didik** (17 isian + kotak foto 3x4 + tanda tangan kepala sekolah), atau **Lengkap** (semuanya berurutan). Data identitas sekolah (yayasan, kelurahan, kecamatan, kabupaten, provinsi, website) diisi di Pengaturan; data identitas siswa (orang tua, wali, sekolah asal, diterima di kelas, dll.) diisi di menu Siswa.

Saat **Cetak Rapor**, pilih *Tengah Semester (UTS)* atau *Akhir Semester*; keduanya memakai data nilai yang sama. Kehadiran & catatan diisi terpisah untuk tengah dan akhir semester.

- **Rapor UTS** (Laporan Hasil Belajar Tengah Semester): per mapel tampil rata-rata CP1, CP2, CP3, nilai STS, dan nilai akhir = rata-rata semua nilai CP dan STS. Mapel kejuruan bisa dipecah per elemen (3.1, 3.2, dst.) lewat isian "Sub dari Mapel" di menu Mata Pelajaran. Ada juga ketidakhadiran serta tanda tangan orang tua, wali kelas, dan kepala sekolah.
- **Rapor Semester Ganjil/Genap** (Laporan Hasil Belajar): identitas di setiap halaman, nilai akhir + capaian pembelajaran per mapel, kokurikuler, ekstrakurikuler & prestasi (dengan keterangan), ketidakhadiran, catatan wali kelas, tanggapan orang tua (ganjil), **keputusan naik/tinggal kelas atau lulus (genap)**, tanda tangan orang tua, wali kelas & kepala sekolah.

Tampilan: glassmorphism putih-hijau, sidebar di laptop, menu bawah melayang di HP, bisa dipasang sebagai aplikasi (PWA).

## Struktur file

```
index.html              ← seluruh aplikasi (UI + logika)
supabase/schema.sql     ← tabel, fungsi RPC, RLS (jalankan di Supabase)
manifest.webmanifest    ← PWA
sw.js                   ← service worker PWA
logo.png, icon-*.png     ← logo sekolah & ikon aplikasi
vercel.json             ← konfigurasi Vercel
```

## Langkah pemasangan

### 1. Siapkan Supabase
1. Buat project di <https://supabase.com> (gratis).
2. Buka **SQL Editor → New query**, salin seluruh isi `supabase/schema.sql`, klik **Run**. (Aman dijalankan ulang, dan otomatis memperbarui database dari versi sebelumnya.)
3. Buka **Authentication → Users → Add user → Create new user**, isi email & password admin, centang *Auto Confirm User*.
4. **Penting (keamanan):** buka **Authentication → Sign In / Providers → Email**, matikan **Allow new users to sign up**. Semua akun Supabase Auth dianggap admin, jadi pendaftaran publik harus dimatikan.
5. Buka **Project Settings → API**, salin **Project URL** dan **anon public key**.

### 2. Hubungkan aplikasi ke Supabase
Buka `index.html`, cari bagian konfigurasi di awal `<script>`:

```js
const IS_PREVIEW = false;                 // ubah dari true ke false
const SUPABASE_URL = "https://xxxx.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOi...";
```

Saat `IS_PREVIEW = true` aplikasi memakai data contoh di browser (ada tombol login cepat Admin/Guru/Siswa) agar bisa dicoba tanpa database. Begitu diubah ke `false`, banner preview, tombol login cepat, dan data contoh hilang total; semua login & data langsung ke Supabase.

> Anon key memang boleh terlihat publik. Keamanan data dijaga oleh RLS & fungsi di `schema.sql`.

### 3. Deploy ke Vercel
1. Push folder ini ke repository GitHub.
2. Masuk <https://vercel.com> → **Add New → Project** → pilih repository tersebut.
3. Framework Preset: **Other**. Build Command & Output Directory dikosongkan. Klik **Deploy**.
4. Setiap ada push baru ke GitHub, Vercel otomatis memperbarui situs.

### 4. Urutan pengisian data pertama kali (login sebagai Admin)
1. **Pengaturan** → unggah logo sekolah (opsional, logo bawaan sudah terpasang), isi identitas sekolah & kepala sekolah, tambah Tahun Ajaran lalu klik **Jadikan aktif**.
2. **Konsentrasi Keahlian** → mis. TJKT, AKL, TKR.
3. **Guru** → isi username (password awal = username bila dikosongkan).
4. **Kelas** → pilih tingkat, konsentrasi, dan wali kelas.
5. **Mata Pelajaran** → kelompok & urutan tampil di rapor.
6. **Siswa** → tambah manual atau **Impor** (tempel dari Excel: NISN, NIS, Nama, L/P, Nama Kelas).
7. **Pembagian Mengajar** → guru, kelas, mapel.
8. Pilih jenis rapor (UTS atau Akhir Semester), lalu guru mengisi nilai; wali kelas mengisi kehadiran & catatan; cetak rapor dari menu **Cetak Rapor** (bisa *Simpan sebagai PDF* dari dialog cetak).

Pergantian semester: tambah tahun ajaran/semester baru lalu jadikan aktif. Rapor semester lama tetap bisa dibuka lewat pilihan tahun ajaran.

## Keamanan
- Password guru disimpan sebagai hash bcrypt (otomatis lewat trigger).
- Guru tidak punya akses langsung ke tabel; semua lewat fungsi RPC yang memeriksa token sesi (berlaku 12 jam): guru mapel hanya bisa mengisi nilai mapel yang diampu; wali kelas bisa mengisi nilai semua mapel, catatan, dan mencetak rapor untuk kelasnya saja.
- Role `anon` hanya bisa membaca data referensi (sekolah, tahun ajaran, jurusan, kelas, mapel).
