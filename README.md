# ARTFOS GOLD — Repository Siap Vercel

Portal informasi trading dengan identitas hitam–emas. Website tidak mengeksekusi order trading. Angka pasar, kalender berita, performa, dan signal tidak boleh dibuat-buat.

## Deploy Vercel (static, tanpa build/install)
1. Buat repository GitHub baru, misalnya `ARTFOS-GOLD-WEBSITE`.
2. Upload **isi folder ini** ke root repository (bukan folder ZIP di dalam repo).
3. Di Vercel, import repository tersebut.
4. Framework Preset: **Other**. Build Command: **kosong / override kosong**. Output Directory: **`.`**. Install Command: **kosong**.
5. Deploy. Halaman publik akan tampil; fitur akun tetap meminta konfigurasi backend.

Vercel mendukung website statis tanpa langkah build; lihat dokumentasi resmi: https://vercel.com/docs/builds/configure-a-build

## Mengaktifkan akun member dengan Supabase
1. Buat proyek Supabase.
2. Jalankan `sql/schema.sql` melalui SQL Editor.
3. Masukkan URL proyek dan public anon/publishable key ke `config.js`.
4. Buat akun pengguna melalui pendaftaran website. Untuk admin pertama, ikuti petunjuk di bagian ADMIN pada schema SQL.
5. Uji pendaftaran, konfirmasi email, login, RLS, dan approval sebelum dipakai pengguna.

**Penting:** file `config.js` hanya boleh berisi public anon/publishable key. Jangan pernah menaruh `service_role`, password admin, API key privat, atau rahasia provider di browser. Supabase Auth menyimpan password dengan aman; password tidak diekspor atau disimpan di tabel profil.

## Cakupan saat ini
- Halaman publik responsif, tema hitam/emas, layanan Gratis/Premium/VIP, performa USD, berita, FAQ dan peringatan risiko.
- Form login/registrasi terhubung ke Supabase setelah konfigurasi.
- Pendaftaran menyimpan metadata akun dan status awal `pending`/membership `gratis` bila session langsung tersedia.
- Dashboard menampilkan status akun; signal dan performa tetap kosong sampai data/provider terhubung.
- SQL menyediakan tabel profil member, broker, paket membership, signal, hasil signal, berita, pengaturan, serta RLS dasar.

## Yang masih wajib disiapkan sebelum disebut produksi penuh
- Provider market data dan economic calendar yang sah, API server-side/worker untuk signal engine, TradingView webhook bila digunakan, dan proses penilaian/validasi signal.
- Mekanisme approval admin dan panel CRUD admin lengkap, pengaturan broker/referral, dua kontak WhatsApp, QRIS, export Excel dan audit log.
- Pengujian keamanan, kebijakan RLS, verifikasi broker, backup, monitoring, dan pengujian alur pembayaran.
- Konfigurasi email auth Supabase serta domain produksi.

Website ini tidak menjanjikan profit. Signal adalah informasi, bukan nasihat keuangan. Trading forex dan emas berisiko tinggi.
