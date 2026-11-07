# Panduan Deploy e-Rapor SMK Mambaul Ulum

Total waktu ± 20–30 menit. Yang dibutuhkan: akun Google/email untuk daftar Supabase, GitHub, dan Vercel (semuanya gratis).

Sebelum mulai, unduh dan ekstrak `rapor-smk-mambaul-ulum.zip`.

---

## Langkah 1 — Buat database di Supabase

1. Buka <https://supabase.com>, lalu klik **Start your project** dan login (bisa pakai akun GitHub atau email).
2. Klik **New project**, lalu isi:
   - **Name**: `erapor-smk`
   - **Database Password**: buat password yang kuat dan simpan
   - **Region**: **Southeast Asia (Singapore)**
3. Klik **Create new project** dan tunggu ± 2 menit sampai selesai.
4. Di menu kiri, buka **SQL Editor** lalu klik **New query**.
5. Buka file `supabase/schema.sql` dengan Notepad. Salin **seluruh isinya**, tempel ke SQL Editor, lalu klik **Run**. Hasilnya harus *Success*.

## Langkah 2 — Buat akun Admin pertama

1. Di menu kiri, buka **Authentication → Users**, klik **Add user**, lalu pilih **Create new user**.
2. Isi email dan password admin, misalnya `admin@smkmambaululum.sch.id`.
3. Centang **Auto Confirm User**, lalu klik **Create user**.
4. **Wajib demi keamanan:** buka **Authentication → Sign In / Providers → Email**, matikan **Allow new users to sign up**, lalu klik **Save**.
   Semua akun di sini dianggap admin, jadi orang lain tidak boleh bisa mendaftar sendiri.

Akun guru **tidak** dibuat di sini. Akun guru dibuat nanti oleh admin dari menu **Guru** di aplikasi.

## Langkah 3 — Ambil kunci Supabase dan hubungkan ke aplikasi

1. Buka **Project Settings → API** (atau **Data API**), lalu salin dua nilai berikut:
   - **Project URL**, contohnya `https://abcdxyz.supabase.co`
   - **anon public** key, yaitu teks panjang yang diawali `eyJ...`
2. Buka `index.html` dengan Notepad atau VS Code. Gunakan **Ctrl+F**, cari `IS_PREVIEW`, lalu ubah tiga baris ini:

   ```js
   const IS_PREVIEW = false;
   const SUPABASE_URL = "https://abcdxyz.supabase.co";
   const SUPABASE_ANON_KEY = "eyJ....";
   ```
3. Simpan file tersebut.

> Anon key aman untuk dipasang di website karena data tetap dilindungi aturan keamanan di database.
> Jangan pernah memakai **service_role** key.

## Langkah 4 — Unggah ke GitHub (tanpa perlu install apa pun)

1. Buka <https://github.com>, login atau daftar, lalu klik **+ → New repository**.
2. Isi **Repository name**: `erapor-smk`. Pilihannya boleh **Public** atau **Private**. Klik **Create repository**.
3. Di halaman repo yang masih kosong, klik **uploading an existing file**.
4. Seret **semua isi folder** hasil ekstrak ke halaman itu: `index.html`, `sw.js`, `manifest.webmanifest`, `vercel.json`, `logo.png`, `icon-192.png`, `icon-512.png`, `README.md`, dan folder `supabase`.
   Pastikan yang diseret adalah isinya, bukan folder induknya.
5. Klik **Commit changes**.

## Langkah 5 — Deploy di Vercel

1. Buka <https://vercel.com>, lalu klik **Sign Up** dan pilih **Continue with GitHub**.
2. Klik **Add New… → Project**, cari repo `erapor-smk`, lalu klik **Import**.
3. Pada **Framework Preset**, pilih **Other**. Biarkan **Build Command** dan **Output Directory** kosong.
4. Klik **Deploy** dan tunggu ± 1 menit. Anda akan mendapat alamat seperti `https://erapor-smk.vercel.app`.

Setiap kali ada perubahan, cukup unggah ulang file yang berubah ke GitHub. Vercel akan memperbarui situs secara otomatis.

## Langkah 6 — Isi data awal (login sebagai Admin di tab **Admin**)

1. **Pengaturan**: isi identitas sekolah dan kepala sekolah. Tambahkan Tahun Ajaran, lalu klik **Jadikan aktif**.
2. **Konsentrasi Keahlian**: misalnya DKV, TJKT, AKL.
3. **Guru**: isi nama dan username. Kalau password dikosongkan, password awalnya sama dengan username.
4. **Kelas**: isi tingkat, konsentrasi, dan **wali kelas**.
5. **Mata Pelajaran**: isi kelompok dan urutan. Sub-elemen kejuruan dibuat lewat isian "Sub dari Mapel".
6. **Siswa**: tambahkan satu per satu, atau gunakan **Impor** (tempel dari Excel dengan kolom NISN, NIS, Nama, L/P, Kelas).
7. **Pembagian Mengajar**: hubungkan guru, kelas, dan mapel.
8. Guru login di tab **Guru** dengan username dan password, mengisi nilai, lalu mengganti password lewat **Akun Saya**.

## Bila ada masalah

| Gejala | Solusi |
|---|---|
| Masih muncul banner "Mode Preview" | `IS_PREVIEW` belum diubah ke `false`, atau file belum diunggah ulang ke GitHub |
| Admin tidak bisa login | Pastikan centang *Auto Confirm User* sudah dipilih, dan URL serta key sudah benar |
| Guru tidak bisa login | Akun guru harus dibuat dari menu **Guru** di aplikasi, bukan di Supabase |
| Error saat Run SQL | Salin ulang **seluruh** isi `schema.sql`, lalu Run lagi. File ini aman dijalankan berulang kali |
| Tampilan lama setelah update | Tekan **Ctrl+Shift+R** di browser, atau tutup lalu buka lagi aplikasinya |
