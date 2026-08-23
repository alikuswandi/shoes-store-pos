# Shoes Store POS & Inventory v2 — Online Realtime

Aplikasi web toko sepatu untuk **Kasir, Admin, dan Owner**, menggunakan **Supabase PostgreSQL + Realtime**. Owner dapat memonitor toko dari luar kota melalui HP/laptop selama terhubung internet.

## Fitur versi lengkap

### Kasir / POS
- Login role-based
- POS cepat, pencarian nama/SKU/barcode
- Scan barcode USB/Bluetooth (bertindak seperti keyboard)
- Keranjang, qty, diskon, tunai/QRIS/transfer/debit/kredit/e-wallet
- Hitung kembalian otomatis
- Batas maksimal diskon kasir
- Cetak struk thermal/browser
- Shift kasir: kas awal, kas seharusnya, kas aktual, selisih
- Riwayat transaksi milik kasir

### Admin
- Master produk, SKU, brand, kategori
- Variasi ukuran, warna, barcode
- Stok minimum & stok menipis
- Supplier
- Pembelian barang
- Average cost otomatis saat pembelian
- Stock opname
- Kartu stok / stock movement
- Retur penjualan
- Pengeluaran
- Laporan penjualan dan stok
- Export CSV

### Owner
- Semua akses Admin
- Dashboard realtime
- Omzet, HPP, laba kotor, pengeluaran, laba bersih
- Nilai persediaan
- Grafik penjualan 14 hari
- Laporan laba rugi 30 hari
- Audit log
- Pengaturan toko
- Batas diskon kasir
- Monitoring shift dan transaksi seluruh kasir

### Database & keamanan
- PostgreSQL Supabase
- Supabase Authentication
- Row Level Security (RLS)
- Hak akses Kasir / Admin / Owner
- Trigger database untuk mengurangi stok saat penjualan
- Trigger menambah stok saat pembelian
- Trigger stock opname
- Trigger retur penjualan
- Pencegahan stok minus dengan row lock
- Supabase Realtime
- Audit log

### PWA
- `manifest.webmanifest`
- service worker
- installable ke HP/desktop
- app shell dapat dibuka dari cache; transaksi/database tetap membutuhkan koneksi internet agar konsisten

---

## 1. Buat project Supabase

Buka Supabase, buat project baru, lalu tunggu database aktif.

## 2. Jalankan schema database

Buka **SQL Editor** di Supabase, copy seluruh isi `schema.sql`, lalu klik **Run**.

> Sebaiknya jalankan pada project Supabase baru agar tidak bentrok dengan policy/tabel versi lama.

## 3. Buat akun pengguna

Masuk ke **Authentication → Users → Add user**.

Contoh:
- `owner@toko.com`
- `admin@toko.com`
- `kasir@toko.com`

Gunakan password kuat Anda sendiri.

## 4. Hubungkan akun ke role

Salin UUID masing-masing user dari Authentication, kemudian jalankan:

```sql
insert into public.profiles(id,full_name,role) values
('UUID_OWNER','Owner Toko','owner'),
('UUID_ADMIN','Admin Toko','admin'),
('UUID_KASIR','Kasir 1','kasir');
```

Role yang didukung hanya:
- `owner`
- `admin`
- `kasir`

## 5. Isi config.js

Supabase → **Project Settings → API**.

Salin Project URL dan anon/public key ke:

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://xxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJ..."
};
```

**Jangan** pernah memasukkan `service_role` key ke frontend.

## 6. Tes di komputer

Jalankan web server dari folder aplikasi:

```bash
python -m http.server 8080
```

Kemudian buka:

`http://localhost:8080`

Jangan membuka `index.html` dengan `file://` karena service worker/PWA dan beberapa fitur browser membutuhkan HTTP/HTTPS.

## 7. Deploy ke Vercel

Cara termudah:
1. Upload folder ini ke GitHub.
2. Login Vercel.
3. Pilih **Add New → Project**.
4. Import repository GitHub.
5. Karena aplikasi static, tidak perlu build command khusus.
6. Deploy.

Setelah selesai akan mendapat alamat seperti:

`https://shoes-store-pos.vercel.app`

Alamat yang sama dapat dibuka dari komputer toko, HP admin, dan HP owner di luar kota.

## 8. Alur realtime

Kasir checkout → transaksi masuk Supabase → `sale_items` dibuat → trigger PostgreSQL mengunci row stok → stok dikurangi → `stock_movements` dibuat → event Realtime dikirim → dashboard owner/admin refresh otomatis.

Pembelian → `purchase_items` → stok bertambah → harga modal average cost diperbarui → dashboard berubah realtime.

Stock opname/retur juga mengubah stok melalui trigger database, sehingga sumber kebenaran stok tetap database dan bukan browser kasir.

## 9. Barcode

Barcode scanner USB/Bluetooth yang mengirim input seperti keyboard dapat langsung dipakai di kolom pencarian POS. Label barcode dapat dibuat dari menu **Produk & Stok → Label**.

## 10. Printer thermal

Tombol **Cetak Struk** memakai dialog print browser. Pilih printer thermal 58 mm/80 mm yang terpasang pada komputer kasir. Atur margin printer sekecil mungkin pada dialog print.

## 11. Catatan produksi penting

Versi ini adalah source code operasional yang dapat dijalankan dan dikembangkan. Sebelum penggunaan komersial penuh, lakukan uji transaksi, retur, stock opname, dan shift menggunakan data dummy terlebih dahulu. Untuk backup produksi, aktifkan backup database Supabase sesuai paket yang digunakan dan lakukan export berkala.

## Struktur file

- `index.html` — UI utama
- `styles.css` — tampilan responsif
- `app.js` — seluruh modul frontend
- `schema.sql` — database, trigger, RLS, sample data
- `config.js` — koneksi Supabase
- `manifest.webmanifest` — PWA manifest
- `service-worker.js` — cache app shell
- `icon.svg` — ikon aplikasi
- `README.md` — panduan instalasi
